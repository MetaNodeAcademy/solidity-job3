const {upgrades, ethers} = require("hardhat");
const fs = require("fs");
const path = require("path");

module.exports = async ({getNamedAccounts, deployments}) => {
    const {save} = deployments;
    const [account1, account2] = await ethers.getSigners();

    const nftAuction = await ethers.getContractFactory("NftAuction");
    const nftAuctionProxy = await upgrades.deployProxy(nftAuction, [], {
        initializer: "initialize",
    });
    await nftAuctionProxy.waitForDeployment();

    const proxyAddress = await nftAuctionProxy.getAddress();
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
    console.log("代理合约地址：", proxyAddress);
    console.log("实现合约地址：", implementationAddress);

    const data = {
        proxyAddress,
        implementationAddress,
        abi: nftAuction.interface.format("json"),
    };
    fs.writeFileSync(path.join(__dirname, "./.cache/nftAuction.json"), JSON.stringify(data));

    save("NftAuction", {
        address: proxyAddress,
        abi: nftAuction.interface.format("json"),
    });

    const nftFactory = await ethers.getContractFactory("MyToken");
    const nft = await nftFactory.deploy();
    await nft.waitForDeployment();
    console.log("NFT合约地址", await nft.getAddress());

    // 铸造
    for (let i = 1; i < 5; i++) {
        await nft.connect(account1).mint_token();
    }
    save("Nft", {
        address: await nft.getAddress(),
        abi: nftFactory.interface.format("json"),
    });
};
module.exports.tags = ["deployNftAuction"];
