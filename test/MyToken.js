const hre = require("hardhat");
const { expect } = require("chai");

describe("MyToken", () => {
  const { ethers } = hre;

  let myToken;
  let account1, account2;
  before(async () => {
    [account1, account2] = await ethers.getSigners();
    const factory = await ethers.getContractFactory("MyToken");
    myToken = await factory.connect(account2).deploy(1000);
    myToken.waitForDeployment();
    console.log(await myToken.getAddress());
  });

  it("Test1", async () => {
    const name = await myToken.name();
    const symbol = await myToken.symbol();
    const totalSupply = await myToken.totalSupply();
    console.log(name, symbol, totalSupply);
    expect(name).to.equal("MyToken");
    expect(symbol).to.equal("MTK");
    expect(totalSupply).to.equal(1000);
  });

  it("Test2", async () => {
    const balance = await myToken.balanceOf(account2.address);
    console.log(balance);
    expect(balance).to.equal(1000);
  });
});
