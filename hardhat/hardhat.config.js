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
                url: "https://rpc.ftm.tools",
                blockNumber: 35807000,
            },
        },
        rinkeby: {
            url: process.env.RINKEBY,
            accounts: [process.env.TESTING_PRIVATE]

        },
        mainnet: {
            url: process.env.MAINNET ,
            accounts: [process.env.PRIVATE_KEY],
            blockGasLimit: 12487794,
        },
        matic: {
            url: process.env.MATIC,
            accounts: [process.env.PRIVATE_KEY],
            gasPrice: 1711e9,
            chainId: 137,
            blockGasLimit: 12487794
        },
        fantom: {
            url: process.env.FANTOM,
            accounts: [process.env.PRIVATE_KEY],
            gasPrice: 170e9,
            chainId: 250,
            blockGasLimit: 12487794
        },
        avax: {
            url: "https://api.avax.network/ext/bc/C/rpc",
            accounts: [process.env.PRIVATE_KEY],
            gasPrice: 70e9,
            chainId: 43114,
            blockGasLimit: 8000000
        }

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
