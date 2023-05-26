const hre = require("hardhat");
const ethers = hre.ethers;

const PROVIDERS = {
    1:'0xD721A90dd7e010c8C5E022cc0100c55aC78E0FC4',
    4:"0x21744C9A65608645E1b39a4596C39848078C2865",
    137:"0xC03bB46b3BFD42e6a2bf20aD6Fa660e4Bd3736F8",
    250:"0xe0741aE6a8A6D87A68B7b36973d8740704Fd62B9",
    43114:"0x64e12fEA089e52A06A7A76028C809159ba4c1b1a"
};

const UNISWAP = {
    1: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
    4: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
    137: "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff", //QuickSwap
    250: "0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52", //SpiritSwap
    43114: "0xE54Ca86531e17Ef3616d22Ca28b0D458b6C89106"//Pangolin
}


// Current is Fantom Opera deployment



async function main() {


    const SPIRIT_ADMIN = "0xB106c39D2408c15D750f21797e232890E7C3eBEc";
    let SMART_WALL_CHECKER = "0x30De38C5006923f0A95a6C73e145b03B17CA02ef";
    let REVEST_SPIRIT_SWAP = "0xF830457d8AEB9Ad6a00A85A6A5967913C19bC5F9";

    const DEPLOYER = "0x8cA573430Fd584065C080fF1d2eA1a8DfB259Ae8";

    const VOTING_ESCROW = "0x2FBFf41a9efAEAE77538bd63f1ea489494acdc08";

    const DISTRIBUTOR = "0x18CeF75C2b032D7060e9Cf96F29aDF74a9a17ce6";

    const SPIRIT_TOKEN = "0x5cc61a78f164885776aa610fb0fe1257df78e59b";

    const WFTM_TOKEN = "0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83";

    const CURRENT_WALLET_ADMIN = "0x4d5362dd18ea4ba880c829b0152b7ba371741e59";

    const network = await ethers.provider.getNetwork();
    const chainId = network.chainId;
    /*
    await run("verify:verify", {
        address: "0xfb7ee4ed98060879ae9a87e37270a8cf363370fd",
        constructorArguments: [
            PROVIDERS[chainId], VOTING_ESCROW, DISTRIBUTOR, SPIRIT_ADMIN
        ],
    });
    */
    await run("verify:verify", {
        address: "0x75AA4DC201818823F309c7eFa847D025fD5Fcd3D",
        constructorArguments: [
            DEPLOYER
        ],
    });


}

main()
.then(() => process.exit(0))
.catch(error => {
    console.error(error);
    process.exit(1);
});
