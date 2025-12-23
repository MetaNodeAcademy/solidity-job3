const {ethers, deployments, network} = require("hardhat");

// 需要先部署合约到测试网
//npx hardhat deploy --network sepolia --tags deployNftAuction

// 代理合约地址： 0x0eCe45C29106076eB9c9aF3942c6842f510117Db
// 实现合约地址： 0xA66A6d44b0e43d207734F58315Ed09BD899FC0a6
// NFT合约地址 0x5a696a9D146aeEe91F2562a3ad3332f79CDE27F1

describe("Start", async () => {
    let nftAuction, nft;
    let account1, account2;
    const nftId = 1;
    before(async () => {
        [account1, account2] = await ethers.getSigners();

        // 需要先部署合约，然后在这里使用地址
        const deployed = await deployments.getOrNull("NftAuction");
        if (!deployed) {
            throw new Error("请先部署合约到测试网: npx hardhat deploy --network sepolia --tags deployNftAuction");
        }
        nftAuction = await ethers.getContractAt("NftAuction", deployed.address);

        nft = await ethers.getContractAt("MyToken", (await deployments.get("Nft")).address);

        // 设置NFT的批准
        await nft.connect(account1).approve(await nftAuction.getAddress(), nftId);
    });

    it("Test1", async () => {
        const price = await nftAuction.getPrice(ethers.ZeroAddress);
        console.log("ETH price: ", price);

        const usdcAddress = ethers.getAddress("0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238");
        const usdcPrice = await nftAuction.getPrice(usdcAddress);
        console.log("USDC price: ", usdcPrice);

        const duration = 1000;
        const startPrice = ethers.parseEther("0.0001");
        const nftAddress = await nft.getAddress();

        // await nftAuction.connect(account1).createAution(duration, startPrice, nftAddress, nftId);
        const auctionId = ethers.toBigInt(await nftAuction.autionId()) - ethers.toBigInt(1);
        console.log("创建拍卖", await nftAuction.auctions(auctionId));

        // 竞价
        // await nftAuction.connect(account1).bid(auctionId, ethers.ZeroAddress, 0, {value: ethers.parseEther("0.0012")});
        // console.log("Account1竞价成功", await nftAuction.auctions(auctionId));

        // await nftAuction.connect(account2).bid(auctionId, ethers.ZeroAddress, 0, {value: ethers.parseEther("0.0024")});
        // console.log("Account2竞价成功", await nftAuction.auctions(auctionId));
    });
});
