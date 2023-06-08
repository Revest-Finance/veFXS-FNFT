// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "contracts/RevestVeFXS.sol";
import "contracts/VestedEscrowSmartWallet.sol";
import "contracts/SmartWalletWhitelistV2.sol";
import "contracts/interfaces/IVotingEscrow.sol";
import "contracts/interfaces/IYieldDistributor.sol";
import "contracts/interfaces/ILockManager.sol";
import "contracts/interfaces/IRevest.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


interface Revest {
    function withdrawFNFT(uint tokenUID, uint quantity) external;
    function depositAdditionalToFNFT(uint fnftId, uint amount,uint quantity) external returns (uint);
    function extendFNFTMaturity(uint fnftId,uint endTime ) external returns (uint);
    function modifyWhitelist(address contra, bool listed) external;

}

contract veFXSRevest is Test {
    address public Provider = 0xd2c6eB7527Ab1E188638B86F2c14bbAd5A431d78;
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public VOTING_ESCROW = 0xc8418aF6358FFddA74e09Ca9CC3Fe03Ca6aDC5b0;
    address public veFXSAdmin = 0xB1748C79709f4Ba2Dd82834B8c82D4a505003f27;
    address public revestOwner = 0x801e08919a483ceA4C345b5f8789E506e2624ccf;
    address public DISTRIBUTOR = 0xc6764e58b36e26b08Fd1d2AeD4538c02171fA872;
    address public LOCK_MANAGER = 0x226124E83868812D3Dae87eB3C5F28047E1070B7; 

    Revest revest = Revest(0x9f551F75DB1c301236496A2b4F7CeCb2d1B2b242);
    ERC20 FXS = ERC20(0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0);

    RevestVeFXS revestVe;
    SmartWalletWhitelistV2 smartWalletChecker;
    IVotingEscrow veFXS =  IVotingEscrow(VOTING_ESCROW);

    address admin = makeAddr("admin");
    address fxsWhale = 0xd53E50c63B0D549f142A2dCfc454501aaA5B7f3F;

    uint fnftId;
    uint fnftId2;

    address smartWalletAddress;


    function setUp() public {
        revestVe  = new RevestVeFXS(Provider, VOTING_ESCROW, DISTRIBUTOR, admin);
        smartWalletChecker = new SmartWalletWhitelistV2(admin);
        
        hoax(admin, admin);
        smartWalletChecker.changeAdmin(address(revestVe), true);

        vm.label(address(admin), "admin");
        vm.label(address(fxsWhale), "fxsWhale");
        vm.label(address(revest), "revest");
        vm.label(address(revestOwner), "revestOwner");
        vm.label(address(FXS), "FXS");

        hoax(revestOwner, revestOwner);
        revest.modifyWhitelist(address(revestVe), true);

        hoax(veFXSAdmin, veFXSAdmin);
        veFXS.commit_smart_wallet_checker(address(smartWalletChecker));

        hoax(veFXSAdmin, veFXSAdmin);
        veFXS.apply_smart_wallet_checker();
    }

    /**
     * This test case focus on if the user is able to mint the FNFT after deposit 1 token of FXS into veFXS 
     */
    function testMint() public {
        uint time = block.timestamp;
    
        //Outline the parameters that will govern the FNFT
        uint expiration = time + (2 * 365 * 60 * 60 * 24); // 2 years 
        uint amount = 1.1e18; //FXS 

        //Mint the FNFT
        hoax(fxsWhale);
        FXS.approve(address(revestVe), amount);
        hoax(fxsWhale);
        fnftId = revestVe.lockTokens(expiration, amount);

        uint expectedValue = revestVe.getValue(fnftId);
        smartWalletAddress = revestVe.getAddressForFNFT(fnftId);

        //Check
        assert(expectedValue >= 2e18);

        //Logging
        console.log("veFXS balance should be around 2e18: ", expectedValue);
        console.log("SmartWallet add at address: ", smartWalletAddress);
        console.log("The minted FNFT has the ID: ", fnftId);
    }


    /**
     * This test case focus on if when the admin can receive the fee
     */
    function testReceiveFee() public {
        //Outline the parameters that will govern the FNFT
        uint time = block.timestamp;
        uint expiration = time + (2 * 365 * 60 * 60 * 24); // 2 years 
        uint amount = 1e18; //FXS  

        //Balance of admin before the minting the lock
        uint oriBal = FXS.balanceOf(address(admin));

        //Minting the FNFT
        hoax(fxsWhale);
        FXS.approve(address(revestVe), amount);
        hoax(fxsWhale);
        fnftId = revestVe.lockTokens(expiration, amount);

        //Check
        assertEq(FXS.balanceOf(address(admin)), 1e17); //10% fee of amount 1e18 is 1e17

        //Logging
        console.log("FXS balance of revest admin before minting: ", oriBal);
        console.log("FXS balance of revest admin after minting: ", FXS.balanceOf(address(admin)));
    }

    /**
     * This test case focus on if user can deposit additional amount into the vault
     */
    function testDepositAdditional() public {
        // Outline the parameters that will govern the FNFT
        uint time = block.timestamp;
        uint expiration = time + (2 * 365 * 60 * 60 * 24); // 2 years 
        uint amount = 1e18; //FXS  

        //Minting the FNFT
        hoax(fxsWhale);
        FXS.approve(address(revestVe), amount);
        hoax(fxsWhale);
        fnftId = revestVe.lockTokens(expiration, amount);
        smartWalletAddress = revestVe.getAddressForFNFT(fnftId);

        //veFXS Balance after first time deposit
        uint oriVeFXS = revestVe.getValue(fnftId);

        //Destroy the address of smart wallet for testing purpose
        destroyAccount(smartWalletAddress, address(admin));

        //Deposit additional fund for FNFT
        hoax(fxsWhale);
        FXS.approve(address(revestVe), amount);
        hoax(fxsWhale);
        revest.depositAdditionalToFNFT(fnftId, amount, 1);

        //Check
        assert(revestVe.getValue(fnftId) > oriVeFXS);

        //Logging
        console.log("Original veFXS balance in Smart Wallet: ", oriVeFXS);
        console.log("New veFXS balance in Smart Wallet: ", revestVe.getValue(fnftId));
    }

    /**
     * This test case focus on if user can extend the locking period on the vault
     */
    function testExtendLockingPeriod() public {
        // Outline the parameters that will govern the FNFT
        uint time = block.timestamp;
        uint expiration = time + (2 * 365 * 60 * 60 * 24); // 2 years 
        uint amount = 1e18; //FXS  

        //Minting the FNFT
        hoax(fxsWhale);
        FXS.approve(address(revestVe), amount);
        hoax(fxsWhale);
        fnftId = revestVe.lockTokens(expiration, amount);
        smartWalletAddress = revestVe.getAddressForFNFT(fnftId);

        //Skipping two weeks of timestamp
        uint timeSkip = (2 * 7 * 60 * 60 * 24); // 2 week years
        skip(timeSkip);

        //Destroy the address of smart wallet for testing purpose
        destroyAccount(smartWalletAddress, address(admin));

        //Calculating expiration time for new extending time
        time = block.timestamp;
        expiration = time + (4 * 365 * 60 * 60 * 24 - 3600); // 4 year in future in future

        //Attempt to extend FNFT Maturity
        hoax(fxsWhale);
        revest.extendFNFTMaturity(fnftId, expiration);

        IRevest.Lock memory currentLock = ILockManager(LOCK_MANAGER).getLock(fnftId);
        uint newExpiry = currentLock.timeLockExpiry;

        console.log("New Expiration: ", newExpiry);
    }

    /**
     * This test case focus on if user can unlock and withdaw their fnft
     */
    function testUnlockAndWithdraw() public {
        // Outline the parameters that will govern the FNFT
        uint time = block.timestamp;
        uint expiration = time + (2 * 365 * 60 * 60 * 24); // 2 years 
        uint amount = 1e18; //FXS  

        //Minting the FNFT
        hoax(fxsWhale);
        FXS.approve(address(revestVe), amount);
        hoax(fxsWhale);
        fnftId = revestVe.lockTokens(expiration, amount);
        smartWalletAddress = revestVe.getAddressForFNFT(fnftId);

        //Original balance of FXS after depositing the FNFT
        uint oriFXS = FXS.balanceOf(fxsWhale);

        //Destroying teh address of smart wallet for testing purpose
        destroyAccount(smartWalletAddress, address(admin));

        //Skipping two weeks of timestamp
        uint timeSkip = (2 * 365 * 60 * 60 * 24 + 1); // 2 week years
        skip(timeSkip);
        
         //Destroy the address of smart wallet for testing purpose
        destroyAccount(smartWalletAddress, address(admin));

        //Unlocking and withdrawing the NFT
        hoax(fxsWhale);
        revest.withdrawFNFT(fnftId, 1);
        uint currentFXS = FXS.balanceOf(fxsWhale);

        //Check
        assertEq(currentFXS - oriFXS, 9e17);

        //Logging
        console.log("Original balance of FXS: ", oriFXS);
        console.log("Current balance of FXS: ", currentFXS);
    }

    // /**
    //  * Tgus test case focus on testing if the traditional wallet work on yield claiming 
    //  */
    // function testClaimYieldOnTraditionalWallet() public {
    //      //Testing normal contract claim yield
    //     console.log("Current timestamp: ", block.timestamp);
    //     console.log("Original Yield: ", IYieldDistributor(DISTRIBUTOR).yields(smartWalletAddress));


    //     hoax(fxsWhale);
    //     console.log("Yield: ", IYieldDistributor(DISTRIBUTOR).getYield());
    //     console.log("veFXS balance: ", veFXS.balanceOf(fxsWhale));

    //     hoax(fxsWhale, fxsWhale);
    //     IVotingEscrow(VOTING_ESCROW).create_lock(1e18, block.timestamp + (2 * 365 * 60 * 60 * 24));
    //     hoax(fxsWhale, fxsWhale);
    //     IYieldDistributor(DISTRIBUTOR).checkpoint();


    //     console.log("veFXS balance: ", veFXS.balanceOf(fxsWhale));

    //     //Skipping one years of timestamp
    //     uint timeSkip1 = (1 * 365 * 60 * 60 * 24 + 1); //s 2 years
    //     skip(timeSkip1);

    //     hoax(fxsWhale, fxsWhale);
    //     console.log("Earned: ", IYieldDistributor(DISTRIBUTOR).earned(fxsWhale));
    //     hoax(fxsWhale, fxsWhale);
    //     console.log("Yield: ", IYieldDistributor(DISTRIBUTOR).getYield());
    //     hoax(fxsWhale, fxsWhale);
    //     IYieldDistributor(DISTRIBUTOR).checkpoint();
    // }

    /**
     * This test case focus on if user can receive yield from their fnft
     */
    function testClaimYield() public {
        // Outline the parameters that will govern the FNFT
        uint time = block.timestamp;
        uint expiration = time + (2 * 365 * 60 * 60 * 24); // 2 years 
        uint amount = 1e18; //FXS  

        //Minting the FNFT and Checkpoint for Yield Distributor
        hoax(fxsWhale);
        FXS.approve(address(revestVe), amount);
        hoax(fxsWhale);
        fnftId = revestVe.lockTokens(expiration, amount);
        smartWalletAddress = revestVe.getAddressForFNFT(fnftId);
        hoax(fxsWhale);
        IYieldDistributor(DISTRIBUTOR).checkpointOtherUser(smartWalletAddress);

        //Original balance of FXS before claiming yield
        uint oriFXS = FXS.balanceOf(fxsWhale);

        //Skipping one years of timestamp
        uint timeSkip = (1 * 365 * 60 * 60 * 24 + 1); //s 2 years
        skip(timeSkip);

        //Destroy the address of smart wallet for testing purpose
        destroyAccount(smartWalletAddress, address(admin));

        //Yield Claim check
        hoax(fxsWhale);
        uint yieldToClaim = IYieldDistributor(DISTRIBUTOR).earned(smartWalletAddress);

        //Claim yield
        hoax(fxsWhale);
        revestVe.triggerOutputReceiverUpdate(fnftId, bytes(""));
        
        //Balance of FXS after claiming yield
        uint curFXS = FXS.balanceOf(fxsWhale);

        //Checker
        assertGt(yieldToClaim, 0);
        assertEq(curFXS, oriFXS + yieldToClaim);

        //Console
        console.log("Original balance of FXS: ", oriFXS);
        console.log("Current balance of FXS: ", curFXS);
    }

    function testOutputDisplay() public {

        //console.log("Earned: ", IYieldDistributor(DISTRIBUTOR).earned(smartWalletAddress));
    }


}
