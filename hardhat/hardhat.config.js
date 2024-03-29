require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("hardhat-deploy");
require("@nomiclabs/hardhat-etherscan");

require("dotenv").config();

module.exports = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            forking: {
                url: "https://mainnet.infura.io/v3/08cfb263de5249ba9bb25868d93d0d45",
                blockNumber: 17389890,
                blockGasLimit: 100100000,
                gas: 21000000
            },
        },
    },
    solidity: {
        version: "0.8.4",
        settings: {
            optimizer: {
                enabled: true,
                runs: 10000,
            },
        },
    },
    paths: {
        sources: "./contracts",
        tests: "./test",
        scripts: "./scripts",
        cache: "./cache",
        artifacts: "./artifacts",
    },
    mocha: {
        timeout: 240000,
    },
    namedAccounts: {
        deployer: {
            default: 0, // here this will by default take the first account as deployer
            1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
        },
    },
    etherscan: {
        // Your API key for Etherscan
        // Obtain one at https://etherscan.io/
        apiKey: process.env.ETHERSCAN_API,
    },
};
