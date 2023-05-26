const hre = require("hardhat");
const ethers = hre.ethers;
const fs = require('fs');

const seperator = "\t-----------------------------------------"
const RevestUniABI = [
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "_provider",
          "type": "address"
        },
        {
          "internalType": "address",
          "name": "_router",
          "type": "address"
        }
      ],
      "stateMutability": "nonpayable",
      "type": "constructor"
    },
    {
      "anonymous": false,
      "inputs": [
        {
          "indexed": true,
          "internalType": "address",
          "name": "previousOwner",
          "type": "address"
        },
        {
          "indexed": true,
          "internalType": "address",
          "name": "newOwner",
          "type": "address"
        }
      ],
      "name": "OwnershipTransferred",
      "type": "event"
    },
    {
      "inputs": [],
      "name": "METADATA",
      "outputs": [
        {
          "internalType": "string",
          "name": "",
          "type": "string"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "PRECISION",
      "outputs": [
        {
          "internalType": "uint256",
          "name": "",
          "type": "uint256"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "addressRegistry",
      "outputs": [
        {
          "internalType": "address",
          "name": "",
          "type": "address"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "getAddressRegistry",
      "outputs": [
        {
          "internalType": "address",
          "name": "",
          "type": "address"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "fnftId",
          "type": "uint256"
        }
      ],
      "name": "getAsset",
      "outputs": [
        {
          "internalType": "address",
          "name": "",
          "type": "address"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "",
          "type": "uint256"
        }
      ],
      "name": "getCustomMetadata",
      "outputs": [
        {
          "internalType": "string",
          "name": "",
          "type": "string"
        }
      ],
      "stateMutability": "pure",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "fnftId",
          "type": "uint256"
        }
      ],
      "name": "getOutputDisplayValues",
      "outputs": [
        {
          "internalType": "bytes",
          "name": "",
          "type": "bytes"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "fnftId",
          "type": "uint256"
        }
      ],
      "name": "getValue",
      "outputs": [
        {
          "internalType": "uint256",
          "name": "",
          "type": "uint256"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "",
          "type": "uint256"
        },
        {
          "internalType": "uint256[]",
          "name": "",
          "type": "uint256[]"
        },
        {
          "internalType": "bool",
          "name": "",
          "type": "bool"
        }
      ],
      "name": "handleFNFTRemaps",
      "outputs": [],
      "stateMutability": "pure",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "endTime",
          "type": "uint256"
        },
        {
          "internalType": "uint256",
          "name": "amountPerFNFT",
          "type": "uint256"
        },
        {
          "internalType": "uint256",
          "name": "quantityFNFTs",
          "type": "uint256"
        },
        {
          "internalType": "address[]",
          "name": "pathToSwaps",
          "type": "address[]"
        }
      ],
      "name": "mintTimeLockToUniswap",
      "outputs": [
        {
          "internalType": "uint256",
          "name": "fnftId",
          "type": "uint256"
        }
      ],
      "stateMutability": "payable",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "owner",
      "outputs": [
        {
          "internalType": "address",
          "name": "",
          "type": "address"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "",
          "type": "uint256"
        },
        {
          "internalType": "uint256",
          "name": "",
          "type": "uint256"
        }
      ],
      "name": "pendingTrades",
      "outputs": [
        {
          "internalType": "address",
          "name": "",
          "type": "address"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "fnftId",
          "type": "uint256"
        },
        {
          "internalType": "address",
          "name": "asset",
          "type": "address"
        },
        {
          "internalType": "address payable",
          "name": "owner",
          "type": "address"
        },
        {
          "internalType": "uint256",
          "name": "quantity",
          "type": "uint256"
        }
      ],
      "name": "receiveRevestOutput",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "fnftId",
          "type": "uint256"
        },
        {
          "internalType": "address payable",
          "name": "owner",
          "type": "address"
        },
        {
          "internalType": "uint256",
          "name": "quantity",
          "type": "uint256"
        },
        {
          "components": [
            {
              "internalType": "address",
              "name": "asset",
              "type": "address"
            },
            {
              "internalType": "address",
              "name": "pipeToContract",
              "type": "address"
            },
            {
              "internalType": "uint256",
              "name": "depositAmount",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "depositMul",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "split",
              "type": "uint256"
            },
            {
              "internalType": "uint256",
              "name": "depositStopTime",
              "type": "uint256"
            },
            {
              "internalType": "bool",
              "name": "maturityExtension",
              "type": "bool"
            },
            {
              "internalType": "bool",
              "name": "isMulti",
              "type": "bool"
            },
            {
              "internalType": "bool",
              "name": "nontransferrable",
              "type": "bool"
            }
          ],
          "internalType": "struct IRevest.FNFTConfig",
          "name": "config",
          "type": "tuple"
        },
        {
          "internalType": "bytes",
          "name": "args",
          "type": "bytes"
        }
      ],
      "name": "receiveSecondaryCallback",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [],
      "name": "renounceOwnership",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "addressRegistry_",
          "type": "address"
        }
      ],
      "name": "setAddressRegistry",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "bytes4",
          "name": "interfaceId",
          "type": "bytes4"
        }
      ],
      "name": "supportsInterface",
      "outputs": [
        {
          "internalType": "bool",
          "name": "",
          "type": "bool"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "address",
          "name": "newOwner",
          "type": "address"
        }
      ],
      "name": "transferOwnership",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "fnftId",
          "type": "uint256"
        },
        {
          "internalType": "bytes",
          "name": "args",
          "type": "bytes"
        }
      ],
      "name": "triggerOutputReceiverUpdate",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    }
  ];
async function main() {

    const PROVIDERS = {
        1:'0xD721A90dd7e010c8C5E022cc0100c55aC78E0FC4',
        4:"0x21744C9A65608645E1b39a4596C39848078C2865",
        137:"0xC03bB46b3BFD42e6a2bf20aD6Fa660e4Bd3736F8",
        250:"0xe0741aE6a8A6D87A68B7b36973d8740704Fd62B9",
        43114:"0x64e12fEA089e52A06A7A76028C809159ba4c1b1a"
    };

    const WETH ={
        1:"0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
        4:"0xc778417e063141139fce010982780140aa0cd5ab",
        137:"0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270",
        250:"0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83",
        43114:"0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7"
    };

    const UNISWAP = {
        1: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
        4: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
        137: "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff", //QuickSwap
        250: "0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52", //SpiritSwap
        43114: "0xE54Ca86531e17Ef3616d22Ca28b0D458b6C89106"//Pangolin
    }

    const DEPLOYMENTS = {
        137: "0xbA61d5EC263f54394Db19F4c0bB3E505C28175BD",
        250: "0x06ee1030AF860441bAeA4a2811843Ad312f9F766"
    }

    const signers = await ethers.getSigners();
    const owner = signers[0];
    const network = await ethers.provider.getNetwork();
    const chainId = network.chainId;

    let PROVIDER_ADDRESS = PROVIDERS[chainId];
    let UNISWAP_ADDRESS = UNISWAP[chainId];
    let deployed = new ethers.Contract(DEPLOYMENTS[chainId], RevestUniABI, owner);

    let expiration = Math.floor(Date.now()/1000) + 3600 * 48;
    let quantity = 1;
    let fee = ethers.utils.parseEther('3');//FTM fee
    let amountPer = ethers.utils.parseEther('1'); //WFTM
    let asset1 = WETH[chainId];
    let asset2 = "0x5cc61a78f164885776aa610fb0fe1257df78e59b"; // SPIRIT

    let txn = await deployed.mintTimeLockToUniswap(expiration,amountPer,quantity, [asset1, asset2], {value:fee});
    let res = await txn.wait();
    console.log(res);
    

}



main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.log("Deployment Error.\n\n----------------------------------------------\n");
        console.error(error);
        process.exit(1);
    })
