require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("hardhat-deploy");
require("@openzeppelin/hardhat-upgrades");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: "0.8.28",
    // 给账户起别名
    namedAccounts: {
        deployer: 0,
        user1: 1,
        user2: 2,
    },
    networks: {
        sepolia: {
            url: process.env.SEPOLIA_RPC_URL,
            accounts: [process.env.PRIVATE_KEY1, process.env.PRIVATE_KEY2],
            chainId: 11155111,
        },
        localhost: {
            url: "http://127.0.0.1:8545",
        },
    },
};
