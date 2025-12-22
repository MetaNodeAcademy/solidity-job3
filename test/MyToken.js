const hre = require("hardhat");
const {expect} = require("chai");

describe("MyToken", () => {
    const {ethers} = hre;

    let myToken;
    let account1, account2;
    before(async () => {
        [account1, account2] = await ethers.getSigners();
        const factory = await ethers.getContractFactory("MyToken");
        myToken = await factory.connect(account2).deploy();
        myToken.waitForDeployment();
        console.log(await myToken.getAddress());
    });

    it("铸造", async () => {
        for (let i = 1; i < 10; i++) {
            await myToken.mint_token();
        }

        const mintAmount = await myToken.balanceOf(account2.address);
        console.log("mintAmount: ", mintAmount);
    });
});
