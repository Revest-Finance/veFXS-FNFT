const hre = require("hardhat");
const ethers = hre.ethers;
const fs = require('fs');

const FXS_ADDRESS  = '0x3432b6a60d23ca0dfca7761b7ab56459d9c964d0'

const fxsWhaleAddress =  '0xd53E50c63B0D549f142A2dCfc454501aaA5B7f3F'

const user = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'

const user2 = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8'

const revestOwner = '0x801e08919a483ceA4C345b5f8789E506e2624ccf'

const fxsABI = [
    //Transfer
    'function transfer(address, uint) public returns(bool)',

    'function balanceOf(address) public returns (uint)'
]

async function main(){
    // Impersonate the token holder
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [fxsWhaleAddress],
    });

    const provider = new ethers.providers.JsonRpcProvider("https://rpc.vnet.tenderly.co/devnet/09ac07fb-73b0-4ccd-a487-4b647025859f/26d0fa98-66d5-455a-9970-cd31acab135c")

    const signerUser1 =  await ethers.getSigner(user)

    tx2 = await signerUser1.sendTransaction({
        to: user2, 
        value: ethers.utils.parseEther("1.0")
    })


//     const signerWhale = await ethers.getSigner(fxsWhaleAddress)
    
//     const fxs = ethers.utils.parseUnits("1.0", 18);

//     const fxsContract = new ethers.Contract(FXS_ADDRESS, fxsABI, provider)

//     const fxsWithSigner = fxsContract.connect(signerWhale)

//     tx = await fxsWithSigner.transfer(user, fxs)

//     blockNum =  await provider.getBlockNumber()

//     balance = await provider.getBalance(user)

//     const signerUser1 =  await ethers.getSigner(user)

//     tx2 = await signerUser1.sendTransaction({
//         to: user2, 
//         value: ethers.utils.parseEther("1.0")
//     })

//     console.log(blockNum)
//     console.log(tx)
//     console.log(tx2.value.toString())
//     console.log(balance.toString());
// }

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}