const {upgrades, ethers} = require("hardhat");
const fs = require("fs");
const path = require("path");

module.exports = async ({getNamedAccounts, deployments}) => {
    const {save} = deployments;

    //加载cache文件
    const cache = JSON.parse(fs.readFileSync(path.join(__dirname, "./.cache/nftAuction.json"), "utf8"));
    const proxyAddress = cache.proxyAddress;

    const nftAuction = await ethers.getContractFactory("NftAuction2");
    const nftAuctionProxy = await upgrades.upgradeProxy(proxyAddress, nftAuction, {
        initializer: "initialize",
    });

    await nftAuctionProxy.waitForDeployment();
    console.log("升级成功，新代理合约地址：", await nftAuctionProxy.getAddress());

    save("NftAuction2", {
        address: await nftAuctionProxy.getAddress(),
        abi: nftAuction.interface.format("json"),
    });
};

module.exports.tags = ["upgradeNftAuction"];
