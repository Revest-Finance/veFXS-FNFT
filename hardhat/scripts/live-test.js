const hre = require("hardhat");
const ethers = hre.ethers;
const fs = require('fs');

const seperator = "\t-----------------------------------------"

const abi = [
    // Some details about the token
    "function symbol() view returns (string)",

    // Get the account balance
    "function balanceOf(address) view returns (uint)",

    // Send some of your tokens to someone else
    "function transfer(address to, uint amount)",

    // An event triggered whenever anyone transfers to someone else
    "event Transfer(address indexed from, address indexed to, uint amount)",

    "function approve(address spender, uint256 amount) external returns (bool)",
];

async function main() {

    const REVEST_LQDR = "0xb80f5a586BC247D993E6dbaCD8ADD211ec6b0cA5";
    const LQDR_TOKEN = "0x10b620b2dbAC4Faa7D7FFD71Da486f5D44cd86f9";

    const amountToDeposit = ethers.utils.parseEther('0.01'); // Lock very small amount

    const signers = await ethers.getSigners();
    const owner = signers[0];
    const network = await ethers.provider.getNetwork();
    const chainId = network.chainId;

    const RevestLD = await ethers.getContractAt('RevestLiquidDriver', REVEST_LQDR, owner);
    const Token = await ethers.getContractAt('IERC20', LQDR_TOKEN, owner);

    // Only need to do ONCE
    
    let tx = await Token.approve(REVEST_LQDR, ethers.constants.MaxInt256);
    await tx.wait();

    const maturityDate = Math.floor(Date.now()/1000) + 2 * 365 * 24 * 3600;
    console.log("Maturity date: ", maturityDate);

    let weiFee = await RevestLD.getFlatWeiFee(LQDR_TOKEN);
    console.log("Wei Fee: ", ethers.utils.formatEther(weiFee));
    
    tx = await RevestLD.lockLiquidDriverTokens(maturityDate, amountToDeposit, {value:weiFee});
    await tx.wait();
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.log("Testing Error.\n\n----------------------------------------------\n");
        console.error(error);
        process.exit(1);
    })
