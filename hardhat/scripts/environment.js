const hre = require("hardhat");
const ethers = hre.ethers;
const fs = require('fs');

async function main(){
    console.log("Fetching hello world contracts");
    const contract = $contracts["HelloWorld"];

    const provider = new ethers.providers.JsonRpcProvider('https://rpc.vnet.tenderly.co/devnet/09ac07fb-73b0-4ccd-a487-4b647025859f/26d0fa98-66d5-455a-9970-cd31acab135c');
    const factory = new ethers.ContractFactory(contract.abi, contract.evm.bytecode, provider.getSigner);

    console.log("Deploying hello world contracts");
    const helloWorld = await factory.deploy("Hello World");

    console.log("Calling setGreeting function");
    await helloWorld.setGreeting("Hello Sandboxes");

    console.log(await helloWorld.getGreeting());
}

main()
