## 项目简介

本项目基于 **Hardhat + OpenZeppelin Upgradeable**，实现了一个支持 **ETH / ERC20 出价、链上价格预言机定价** 的 NFT 拍卖合约，并演示了 **代理合约的部署与升级流程**。
同时包含一个简单的 ERC721 NFT 合约和一个用于本地测试的 Chainlink 价格预言机 Mock 合约。

---

## 项目结构

- **contracts/**
  - **`NftAuction.sol`**：核心 NFT 拍卖合约（可升级，使用代理）。
  - **`NftAuction2.sol`**：拍卖合约升级版本示例（继承 `NftAuction`，新增 `hello()`）。
  - **`MyToken.sol`**：简单 ERC721 NFT 合约，用于铸造测试 NFT。
  - **`MockPriceFeed.sol`**：实现 `AggregatorV3Interface` 的价格预言机 Mock，用于本地测试 `getPrice`。
- **deploy/**
  - **`01_deploy_nft_auction.js`**：部署脚本，部署 `NftAuction` 代理合约和 `MyToken` 合约，并保存部署信息。
  - **`02_upgrade_nft_auction.js`**：升级脚本，将代理从 `NftAuction` 升级到 `NftAuction2`。
- **deployments/**
  - **`localhost/`、`sepolia/`**：`hardhat-deploy` 自动生成的部署记录（地址 + ABI），供脚本和测试复用。
- **test/**
  - **`local.js`**：本地网络完整流程测试（部署、创建拍卖、竞拍、结束拍卖、升级测试）。
  - **`testnet.js`**：针对测试网（如 Sepolia）的读取和简单交互测试。
- **artifacts/**、**cache/**、**node_modules/**：Hardhat 编译输出、缓存以及依赖目录。
- **`hardhat.config.js`**：Hardhat 配置（网络、插件、编译版本等）。
- **`README.md`**：项目说明（当前文档）。

---

## 合约功能说明

### `NftAuction`（核心拍卖合约）

继承自 `Initializable` 和 `ReentrancyGuardUpgradeable`，通过代理模式部署。

- **状态结构 `Auction`**
  - **`ended`**：拍卖是否结束。
  - **`startPrice`**：起拍价（以 ETH 计价，用于和价格预言机结果组合）。
  - **`highestBidder`**：当前最高出价者地址。
  - **`highestBidUsdt`**：当前最高出价折算成美元（USDT 计价，使用预言机）。
  - **`highestBidAmount`**：当前最高出价的实际数量（ETH 数量或 ERC20 数量）。
  - **`startTime` / `endTime`**：拍卖开始 / 结束时间。
  - **`nftAddress` / `nftId`**：拍卖 NFT 的合约地址与 Token ID。
  - **`tokenAddress`**：本场拍卖使用的支付 Token 地址（`address(0)` 表示使用 ETH）。

- **关键状态变量**
  - **`Auction[] public auctions`**：所有拍卖的数组。
  - **`address public owner`**：合约管理员（拥有创建拍卖和结束拍卖权限）。
  - **`uint public autionId`**：当前拍卖 ID 计数器。
  - **`mapping(address => AggregatorV3Interface) public tokenPriceFeeds`**：Token 地址到价格预言机的映射。

- **初始化函数**
  - **`initialize()`**
    - 初始化重入保护、设置 `owner = msg.sender`。
    - 预配置：
      - USDC 预言机（USDC/USD）。
      - ETH 预言机（ETH/USD）。

- **管理函数**
  - **`setTokenPriceFeed(address _token, address _priceFeed)`**
    - 设置某个 Token 的价格预言机合约地址（只能 `onlyOwner` 调用）。

- **创建拍卖**
  - **`createAution(uint _duration, uint _startPrice, address _nftAddress, uint _nftId)`**
    - 要求：
      - 调用者必须是 `owner`。
      - NFT 对应的 `tokenId` 已经 `approve` 给拍卖合约。
    - 行为：
      - 创建一个新的 `Auction` 结构体，设置起拍价、时间、NFT 地址等。
      - `tokenAddress` 初始为 `address(0)`，表示尚未确定本场拍卖的支付 Token。
      - `auctions.push(auction)` 并自增 `autionId`。

- **竞拍函数**
  - **`bid(uint _autionId, address _token, uint _amount)`**，`payable`：
    - 适配两类出价：
      - **使用 ETH 出价**：`_token == address(0)`，金额来自 `msg.value`。
      - **使用 ERC20 出价**：`_token != address(0)`，金额为 `_amount`，需要提前 `approve`。
    - 主要逻辑：
      1. 检查拍卖是否未结束且在有效时间内。
      2. **锁定拍卖所用 Token 类型**：
         - 若 `auction.tokenAddress == address(0)`，则记录为本场拍卖的 `_token`。
         - 否则要求 `_token` 必须等于 `auction.tokenAddress`（保证同一场拍卖用同一种币）。
      3. 通过价格预言机计算当前出价折算成 USD：
         - `ethPrice = getPrice(address(0))`。
         - `priceUsdt = getPrice(_token) * _amount` 或 `ethPrice * msg.value`。
      4. 校验：
         - 出价必须高于起拍价（按 USD 折算）。
         - 出价必须高于当前最高出价（按 USD 抻算）。
      5. 如果存在旧的最高出价者：
         - 若使用 ERC20：合约从自己账户 `transfer` 旧的 `highestBidAmount` 给旧 `highestBidder`。
         - 若使用 ETH：通过 `call{value: ...}` 退回旧出价。
      6. 对新出价者收款：
         - ERC20：`transferFrom(msg.sender, address(this), highestBidAmount)`，需要事先 `approve`。
         - ETH：通过 `msg.value` 自动进入合约。
      7. 更新拍卖状态中的 `highestBidder`、`highestBidUsdt`、`highestBidAmount`。

- **结束拍卖**
  - **`endAuction(uint _autionId)`**
    - 只能 `owner` 调用。
    - 要求拍卖已到结束时间且未结束。
    - 如果有最高出价者：
      1. 通过 `IERC721.ownerOf` 获取当前 NFT 持有人（卖家）。
      2. 调用 `safeTransferFrom(seller, highestBidder, nftId)` 转移 NFT。
      3. 将资金从合约转给卖家：
         - 若 `auction.tokenAddress != address(0)`：使用 ERC20 的 `transfer`。
         - 否则：使用 ETH 的 `call{value: ...}`。
    - 将 `auction.ended` 标记为 `true`。

- **价格查询**
  - **`getPrice(address _token) public view returns (uint256)`**
    - 调用已配置的 Chainlink（或 mock）预言机的 `latestRoundData`，返回当前价格。

### `NftAuction2`（升级版本示例）

- 继承自 `NftAuction`，新增一个简单函数：
  - **`hello() public pure returns (string memory)`**：返回 `"hello world"`。
- 仅用于演示如何通过代理升级合约，不改变原有状态变量布局。

### `MyToken`（测试用 NFT 合约）

- 继承自 `ERC721`：
  - 名称：`MyToken`，Symbol：`MTK`。
- 状态：
  - **`uint private idIndex`**：自增 Token ID。
- 功能：
  - 构造函数中自动调用 `mint_token()` 给部署者铸造一个 NFT。
  - **`mint_token()`**：给 `msg.sender` 铸造当前 `idIndex`，然后自增。

### `MockPriceFeed`（价格预言机 Mock）

- 实现 `AggregatorV3Interface` 必要接口。
- 通过 `setPrice(int256 newPrice)` 手动设置价格。
- `latestRoundData` / `getRoundData` 返回当前设置的价格和时间，用于本地测试 `getPrice` 与竞拍逻辑。

---

## 环境准备

- Node.js（建议 ≥ 18）
- npm 或 yarn
- Hardhat 及依赖已安装（本项目已包含 `package.json`）

安装依赖：

```bash
npm install
# 或
yarn
```

---

## 本地部署与测试

### 启动本地网络（可选）

```bash
npx hardhat node
```

不启动也可以直接跑测试，Hardhat 会自动使用内置网络。

### 执行部署脚本

```bash
npx hardhat deploy --tags deployNftAuction
```

部署脚本 `01_deploy_nft_auction.js` 会：

- 部署 `NftAuction` 代理合约，并执行 `initialize()`。
- 将代理和实现地址写入 `deploy/.cache/nftAuction.json`。
- 部署 `MyToken` NFT 合约。
- 为第一个账户多次调用 `mint_token()`，铸造多个 NFT。
- 将地址和 ABI 保存到 `deployments/` 目录。

### 本地测试拍卖流程

```bash
npx hardhat test test/local.js
```

`test/local.js` 会：

- 通过 `deployNftAuction` 标签部署合约。
- 部署 `MockPriceFeed` 并通过 `setTokenPriceFeed` 将 ETH 价格预言机指向 Mock 合约。
- `approve` 指定 NFT 给拍卖合约。
- 创建拍卖、两次竞拍、结束拍卖，并打印 NFT 最终所有者。
- 运行升级脚本，升级到 `NftAuction2`，并调用 `hello()` 验证升级成功。

---

## 测试网（Sepolia）部署与交互

### 网络配置

在 `hardhat.config.js` 中配置 `sepolia` 网络，包含：

- **`url`**：RPC 地址。
- **`accounts`**：部署使用的钱包私钥。

### 部署到 Sepolia

```bash
npx hardhat deploy --network sepolia --tags deployNftAuction
```

脚本会输出：

- 代理合约地址（拍卖合约入口地址）。
- 实现合约地址（逻辑合约地址）。
- NFT 合约地址。

### 在测试网上读取数据 / 简单交互

```bash
npx hardhat test test/testnet.js --network sepolia
```

`testnet.js` 会：

- 通过 `deployments.getOrNull("NftAuction")` 读取已部署的拍卖合约地址。
- 调用 `getPrice` 读取 ETH / USDC 的价格。
- 打印已存在拍卖信息（如有）。

如需在测试网上真正创建拍卖、出价，可以在 `testnet.js` 中解开相应的 `createAution` / `bid` 注释，或通过前端/脚本自行调用。

---

## 合约升级流程

1. 先通过 `deployNftAuction` 部署初始版本（`NftAuction`），生成 `deploy/.cache/nftAuction.json`。
2. 运行升级脚本：

```bash
npx hardhat deploy --tags upgradeNftAuction
# 或
npx hardhat deploy --network sepolia --tags upgradeNftAuction
```

`02_upgrade_nft_auction.js` 会：

- 从 `.cache/nftAuction.json` 中读取代理地址。
- 使用 `upgrades.upgradeProxy` 将代理升级为 `NftAuction2` 实现。
- 将新的 ABI 和地址保存到 `deployments/` 目录。

升级完成后，原有状态数据保留，同时可以通过代理地址调用新增的 `hello()` 等函数。

---

## 注意事项

- 使用 ERC20 竞拍时，出价账户必须先对拍卖合约执行 `approve`，否则 `bid` 中的 `transferFrom` 会执行失败并回滚交易。
- 使用 ETH 竞拍时，通过 `msg.value` 直接转入，无需 `approve`。
- 所有涉及转账的函数均加了 `nonReentrant` 修饰，以降低重入攻击风险，但在生产环境中仍建议结合多重审核与安全工具。
