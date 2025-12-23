const {ethers, deployments} = require("hardhat");

describe("Start", async () => {
    let nftAuction, nft;
    let account1, account2;
    const duration = 5;
    const nftId = 1;
    before(async () => {
        [account1, account2] = await ethers.getSigners();

        await deployments.fixture("deployNftAuction");
        nftAuction = await ethers.getContractAt("NftAuction", (await deployments.get("NftAuction")).address);
        nft = await ethers.getContractAt("MyToken", (await deployments.get("Nft")).address);

        // 部署模拟价格预言机用于测试
        const MockPriceFeed = await ethers.getContractFactory("MockPriceFeed");
        const ethPriceFeed = await MockPriceFeed.deploy(ethers.parseEther("3000"));
        await ethPriceFeed.waitForDeployment();

        // 设置 ETH 价格预言机
        await nftAuction.setTokenPriceFeed(ethers.ZeroAddress, await ethPriceFeed.getAddress());

        // 设置NFT的批准
        await nft.connect(account1).approve(await nftAuction.getAddress(), nftId);
    });

    it("竞拍", async () => {
        const startPrice = ethers.parseEther("0.0001");
        const nftAddress = await nft.getAddress();

        await nftAuction.createAution(duration, startPrice, nftAddress, nftId);
        const auctionId = ethers.toBigInt(await nftAuction.autionId()) - ethers.toBigInt(1);
        console.log("合约创建", await nftAuction.auctions(auctionId));

        await nftAuction.connect(account1).bid(auctionId, ethers.ZeroAddress, 0, {value: ethers.parseEther("0.134")});
        console.log("Account1竞拍成功", await nftAuction.auctions(auctionId));

        await nftAuction.connect(account2).bid(auctionId, ethers.ZeroAddress, 0, {value: ethers.parseEther("0.268")});
        console.log("Account2竞拍成功", await nftAuction.auctions(auctionId));

        await new Promise((resolve) => setTimeout(resolve, duration * 1000));
        await nftAuction.connect(account1).endAuction(auctionId);
        console.log("拍卖结束", await nftAuction.auctions(auctionId));

        const nftOwner = await nft.ownerOf(nftId);
        console.log("NFT拥有者", nftOwner);
    });

    it("测试合约升级", async () => {
        await deployments.fixture("upgradeNftAuction");
        const nftAuction2 = await ethers.getContractAt("NftAuction2", (await deployments.get("NftAuction2")).address);

        let hello = await nftAuction2.hello();
        console.log("hello: ", hello);
    });
});
