const hre = require("hardhat");
const ethers = hre.ethers;
const fs = require('fs');

const seperator = "\t-----------------------------------------"

async function main() {

    let RevestSpirSwap;
    let RevestContract;
    let SmartWalletChecker;

    const REVEST = '0x36C2732f1B2ED69CF17133aB01f2876B614a2F27';
    const revestABI = ['function modifyWhitelist(address contra, bool listed) external'];

    const PROVIDERS = {
        1:'0xD721A90dd7e010c8C5E022cc0100c55aC78E0FC4',
        4:"0x21744C9A65608645E1b39a4596C39848078C2865",
        137:"0xC03bB46b3BFD42e6a2bf20aD6Fa660e4Bd3736F8",
        250:"0xe0741aE6a8A6D87A68B7b36973d8740704Fd62B9",
        43114:"0x64e12fEA089e52A06A7A76028C809159ba4c1b1a",
        31337:"0xe0741aE6a8A6D87A68B7b36973d8740704Fd62B9",
    };

    const WETH ={
        1:"0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
        4:"0xc778417e063141139fce010982780140aa0cd5ab",
        137:"0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270",
        250:"0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83",
        43114:"0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7",
        31337:"0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83",
    };

    const UNISWAP = {
        1: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
        4: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
        137: "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff", //QuickSwap
        250: "0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52", //SpiritSwap
        43114: "0xE54Ca86531e17Ef3616d22Ca28b0D458b6C89106",//Pangolin
        31337: "0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52"
    }

    const signers = await ethers.getSigners();
    const owner = signers[0];
    const network = await ethers.provider.getNetwork();
    const chainId = network.chainId;

    
    let PROVIDER_ADDRESS = PROVIDERS[chainId];
    let UNISWAP_ADDRESS = UNISWAP[chainId];

    const SPIRIT_ADMIN = "0x4d5362dd18ea4ba880c829b0152b7ba371741e59";

    const OLD_APPROVALS = ["0x3Fdf3f0B6A5904cF90EAF7a388dFc277b0AA0017","0x1547e599eE4EaF9774b0657FE68A16cf8A7352A6","0x099EA71e5B0C7E350dee2f5EA397AB4E7C489580","0xeafbf21a795168967004b6af14d3fE6a66107fa3","0x9FeF5Cd50C6120651FDF71CB12e89E9fc563e8b6","0x5b826FAEDE6043D0538f72f345C5Fb76c5AA6256","0x44e314190D9E4cE6d4C0903459204F8E21ff940A","0xcf8660e267d44cC804DdBee6b1cE44F9ED564889","0xd12FaB721684540F7D2E3dfD22205bAF83FF3D82","0x142ED7b2bA7be67F54b1BB312353a5Bb849252F9","0xbBf62f98D2F15F4D92a71a676a9baAC84eaB37d8","0x7969c5eD335650692Bc04293B07F5BF2e7A673C0","0x928144CD396aC88C84d60086e3Db20555C56322c","0x181158114b7473a4c1482e8d8f5b5a522C41f2CD","0xB51C59a88B3473b05765c23988282c3F9b3ecc1e","0x2bC001fFEB862d843e0a02a7163C7d4828e5FB10"];

                        

    const VOTING_ESCROW = "0x2FBFf41a9efAEAE77538bd63f1ea489494acdc08";

    const DISTRIBUTOR = "0x18CeF75C2b032D7060e9Cf96F29aDF74a9a17ce6";

    const SPIRIT_TOKEN = "0x5cc61a78f164885776aa610fb0fe1257df78e59b";

    const WFTM_TOKEN = "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83";

    const CURRENT_WALLET_ADMIN = "0x4d5362dd18ea4ba880c829b0152b7ba371741e59";
    
    console.log(seperator);
    console.log("\tDeploying SpiritSwap <> Revest Integration");

    console.log(seperator);
    console.log("\tDeploying RevestSpiritSwap");
    const RevestSpiritSwapFactory = await ethers.getContractFactory("RevestSpiritSwap");
    RevestSpirSwap = await RevestSpiritSwapFactory.deploy(PROVIDER_ADDRESS, VOTING_ESCROW, DISTRIBUTOR, SPIRIT_ADMIN);
    await RevestSpirSwap.deployed();
    console.log("\RevestSpiritSwap Deployed at: " + RevestSpirSwap.address);
    
    RevestContract = new ethers.Contract(REVEST, revestABI, owner);
    let tx = await RevestContract.modifyWhitelist(RevestSpirSwap.address, true);
    await tx.wait();

    
    console.log(seperator);
    console.log("\tDeploying Upgraded SmartWallet");
    const SmartWalletCheckerFactory = await ethers.getContractFactory("SmartWalletWhitelistV2");
    SmartWalletChecker = await SmartWalletCheckerFactory.deploy(owner.address);
    await SmartWalletChecker.deployed();
    console.log("\tSmartWalletChecker Deployed at: " + SmartWalletChecker.address);

    
    tx = await SmartWalletChecker.changeAdmin(RevestSpirSwap.address, true);
    await tx.wait();
    tx = await SmartWalletChecker.changeAdmin(CURRENT_WALLET_ADMIN, true);
    await tx.wait();
    tx = await SmartWalletChecker.batchApproveWallets(OLD_APPROVALS);
    await tx.wait();

    console.log("\tSuccessfull deployed contracts!");

}



main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.log("Deployment Error.\n\n----------------------------------------------\n");
        console.error(error);
        process.exit(1);
    })
