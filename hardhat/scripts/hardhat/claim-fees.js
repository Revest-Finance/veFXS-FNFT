const hre = require("hardhat");
const ethers = hre.ethers;
const fs = require('fs');

const seperator = "\t-----------------------------------------"
const MULTICALL = "0x7f6A10218264a22B4309F3896745687E712962a0";

async function main() {

    let RevestLD;
    let RevestContract;
    let SmartWalletChecker;

    const REVEST = '0x0e29561C367e961A020A6d91486db28B5a48319f';
    const revestABI = ['function modifyWhitelist(address contra, bool listed) external'];
    const LQDR_ABI = ['event DepositERC20OutputReceiver(address indexed mintTo, address indexed token, uint amountTokens, uint indexed fnftId, bytes extraData)', 
                      'event WithdrawERC20OutputReceiver(address indexed caller, address indexed token, uint amountTokens, uint indexed fnftId, bytes extraData)',
                        'function getAddressForFNFT(uint fnftId) public view returns (address smartWallAdd)'];

    const DISTRIBUTOR_ABI = ['function claim(address _addr) external nonpayable returns (uint256)'];

    //DepositERC20OutputReceiver(msg.sender, TOKEN, amountToLock, fnftId, abi.encode(smartWallAdd));

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

    

    const signers = await ethers.getSigners();
    
    const owner = signers[0];
    const network = await ethers.provider.getNetwork();
    const chainId = network.chainId;

    let PROVIDER_ADDRESS = PROVIDERS[chainId];
    let UNISWAP_ADDRESS = UNISWAP[chainId];

    const VOTING_ESCROW = "0x3Ae658656d1C526144db371FaEf2Fff7170654eE";
    const DISTRIBUTOR = "0x095010A79B28c99B2906A8dc217FC33AEfb7Db93";
    const LQDR_TOKEN = "0x10b620b2dbAC4Faa7D7FFD71Da486f5D44cd86f9";
    const WFTM_TOKEN = "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83";
    const N_COINS = 7;

    const LQDR_REVEST = "0xb80f5a586bc247d993e6dbacd8add211ec6b0ca5";

    const CURRENT_WALLET_ADMIN = "0x383ea12347e56932e08638767b8a2b3c18700493";
    
    console.log(seperator);
    console.log("\tDeploying Liquid Driver <> Revest Integration");


    const lqdrRevest = new ethers.Contract(LQDR_REVEST, LQDR_ABI, ethers.provider);
    let DepositEvent = lqdrRevest.filters.DepositERC20OutputReceiver();
    let WithdrawEvent = lqdrRevest.filters.WithdrawERC20OutputReceiver();
    WithdrawEvent.fromBlock = DepositEvent.fromBlock = 32894036;
    WithdrawEvent.toBlock = DepositEvent.toBlock =  "latest";
    var deposits = await ethers.provider.getLogs(DepositEvent)
    var withdraws = await ethers.provider.getLogs(WithdrawEvent)
    let events = withdraws.map((log) => lqdrRevest.interface.parseLog(log));

    let withdrawn = new Set();
    for( let i in events ) {
        let txn = events[i];
        withdrawn.add(txn.args.fnftId);
    }

    events = deposits.map((log) => lqdrRevest.interface.parseLog(log));
    let tokensToClaim = [];
    for(let i in events) {
        let txn = events[i];
        if(!withdrawn.has(txn.args.fnftId)) {
            tokensToClaim.push(Number(txn.args.fnftId.toString()));
        }
    }

    // Use Multicall to retreive addresses
    let addresses = await multicall(
        chainId,
        ethers.provider,
        LQDR_ABI,
        tokensToClaim.map((id) => [LQDR_REVEST, 'getAddressForFNFT', [id]])
    )

    // Use claim_many to claim
    const Distributor = new ethers.Contract(DISTRIBUTOR, DISTRIBUTOR_ABI, owner);
    let non  = await ethers.provider.getTransactionCount(owner.address);
    for(let i in addresses) {   
        if(i<453) {
            continue;
        }
        console.log("Claiming iteration: " + i);
        let tx = await Distributor.claim(addresses[i].smartWallAdd, {gasLimit:1050000, nonce:non++});
        //await tx.wait();
    }


}

async function multicall(network, provider, abi, calls, options = {}) {
    const multicallAbi = [
      'function aggregate(tuple(address target, bytes callData)[] calls) view returns (uint256 blockNumber, bytes[] returnData)',
      'function getFNFT(uint fnftId) external view returns (tuple(address asset, address pipeToContract, uint depositAmount, uint depositMul, uint split, uint depositStopTime, bool maturityExtension, bool isMulti, bool nontransferrable))',
    ];
  
    let net = await provider.getNetwork();
    let chainId = net.chainId;
  
    const multi = new ethers.Contract(MULTICALL, multicallAbi, provider);
  
    const itf = new ethers.utils.Interface(abi);
    try {
      const max = options?.limit || 500;
      const pages = Math.ceil(calls.length / max);
      const promises = [];
      Array.from(Array(pages)).forEach((x, i) => {
        const callsInPage = calls.slice(max * i, max * (i + 1));
        promises.push(
          multi.aggregate(
            callsInPage.map((call) => [call[0].toLowerCase(), itf.encodeFunctionData(call[1], call[2])]),
            options || {}
          )
        );
      });
      let results = await Promise.all(promises);
      results = results.reduce((prev, [, res]) => prev.concat(res), []);
      return results.map((call, i) => itf.decodeFunctionResult(calls[i][1], call));
    } catch (e) {
      return Promise.reject(e);
    }
  }


main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.log("Deployment Error.\n\n----------------------------------------------\n");
        console.error(error);
        process.exit(1);
    })
