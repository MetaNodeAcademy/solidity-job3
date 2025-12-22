const {ethers, deployments} = require("hardhat");

describe("Start", async () => {
    let nftAuction;
    let account1, account2;
    before(async () => {
        [account1, account2] = await ethers.getSigners();

        await deployments.fixture("deployNftAuction");
        nftAuction = await ethers.getContractAt("NftAuction", (await deployments.get("NftAuction")).address);
    });

    it("Test1", async () => {
        const duration = 100 * 1000;
        const startPrice = ethers.parseEther("0.0001");
        const tokenAddress = ethers.ZeroAddress;
        const tokenId = 1;
        await nftAuction.createAution(duration, startPrice, tokenAddress, tokenId);

        await nftAuction.bid(0, {value: ethers.parseEther("0.0002")});
        let auction = await nftAuction.auctions(0);
        console.log(auction);

        await deployments.fixture("upgradeNftAuction");
        const nftAuction2 = await ethers.getContractAt("NftAuction2", (await deployments.get("NftAuction2")).address);
        let hello = await nftAuction2.hello();
        console.log(hello);

        auction = await nftAuction2.auctions(0);
        console.log(auction);
    });
});
