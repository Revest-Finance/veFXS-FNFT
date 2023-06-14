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
import "contracts/lib/RevestHelper.sol";

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
    address public constant REWARD_TOKEN = 0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0;

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
        assertGt(expectedValue, 2e18, "Deposit value is lower than expected!");

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
        assertEq(FXS.balanceOf(address(admin)), 1e17, "Amount of fee received is incorrect!"); //10% fee of amount 1e18 is 1e17

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
        assertGt(revestVe.getValue(fnftId), oriVeFXS, "Additional deposit not success!");

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
        uint overly_expiration = time + (5 * 365 * 60 * 60 * 24 - 3600); //5 years in the future
        expiration = time + (4 * 365 * 60 * 60 * 24 - 3600); // 4 years in future in future

        //attempt to extend FNFT Maturity more than 2 year max
        hoax(fxsWhale);
        vm.expectRevert("Max lockup is 4 years");
        revest.extendFNFTMaturity(fnftId, overly_expiration);

        //Attempt to extend FNFT Maturity
        hoax(fxsWhale);
        revest.extendFNFTMaturity(fnftId, expiration);
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
        assertEq(currentFXS - oriFXS, 9e17, "Withdraw amount does not match!");

        //Logging
        console.log("Original balance of FXS: ", oriFXS);
        console.log("Current balance of FXS: ", currentFXS);
    }

    // // /**
    // //  * Tgus test case focus on testing if the traditional wallet work on yield claiming 
    // //  */
    function testClaimYieldOnTraditionalWallet() public {
         //Testing normal contract claim yield
        console.log("Current timestamp: ", block.timestamp);
        console.log("Original Yield: ", IYieldDistributor(DISTRIBUTOR).yields(smartWalletAddress));


        hoax(fxsWhale);
        console.log("Yield: ", IYieldDistributor(DISTRIBUTOR).getYield());
        console.log("veFXS balance: ", veFXS.balanceOf(fxsWhale));

        hoax(fxsWhale, fxsWhale);
        IVotingEscrow(VOTING_ESCROW).create_lock(1e18, block.timestamp + (2 * 365 * 60 * 60 * 24));
        hoax(fxsWhale, fxsWhale);
        IYieldDistributor(DISTRIBUTOR).checkpoint();


        console.log("veFXS balance: ", veFXS.balanceOf(fxsWhale));

        //Skipping one years of timestamp
        uint timeSkip1 = (1 * 365 * 60 * 60 * 24 + 1); //s 2 years
        skip(timeSkip1);

        hoax(fxsWhale, fxsWhale);
        console.log("Earned: ", IYieldDistributor(DISTRIBUTOR).earned(fxsWhale));
        hoax(fxsWhale, fxsWhale);
        console.log("Yield: ", IYieldDistributor(DISTRIBUTOR).getYield());
        hoax(fxsWhale, fxsWhale);
        IYieldDistributor(DISTRIBUTOR).checkpoint();
    }

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
        // hoax(fxsWhale);
        // IYieldDistributor(DISTRIBUTOR).checkpointOtherUser(smartWalletAddress);

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
        assertGt(yieldToClaim, 0, "Yield should be greater than 0!");
        assertEq(curFXS, oriFXS + yieldToClaim, "Does not receive enough yield!");

        //Console
        console.log("Yield to claim: ", yieldToClaim);
        console.log("Original balance of FXS: ", oriFXS);
        console.log("Current balance of FXS: ", curFXS);
    }

     /**
     * This test case focus on if the getOutputDisplayValue() output correctly
     */
    function testOutputDisplay() public {
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

        //Skipping one years of timestamp
        uint timeSkip = (1 * 365 * 60 * 60 * 24 + 1); //s 2 years
        skip(timeSkip);

         //Yield Claim check
        hoax(fxsWhale);
        uint yieldToClaim = IYieldDistributor(DISTRIBUTOR).earned(smartWalletAddress);

        //Getting output display values
        bytes memory displayData = revestVe.getOutputDisplayValues(fnftId);
        (address adr, string memory rewardDesc, bool hasRewards, uint maxExtensions, address token, int128 lockedBalance) = abi.decode(displayData, (address, string, bool, uint, address, int128));

        string memory par1 = string(abi.encodePacked(RevestHelper.getName(REWARD_TOKEN),": "));
        string memory par2 = string(abi.encodePacked(RevestHelper.amountToDecimal(yieldToClaim, REWARD_TOKEN), " [", RevestHelper.getTicker(REWARD_TOKEN), "] Tokens Available"));
        string memory expectedRewardsDesc = string(abi.encodePacked(par1, par2));

        //checker
        assertEq(adr, smartWalletAddress, "Encoded address is incorrect!");
        assertEq(rewardDesc, expectedRewardsDesc, "Reward description is incorrect!");
        assertEq(hasRewards, yieldToClaim > 0, "Encoded hasRewards is incorrect!");
        assertEq(token, address(FXS), "Encoded vault token is incorrect!");
        assertEq(lockedBalance, 9e17, "Encoded locked balance is incorrect!");

        //Logging
        console.log(adr);
        console.logString(rewardDesc);
        console.log(hasRewards);
        console.log(maxExtensions);
        console.log(token);
        console.logInt(lockedBalance);
    }

    // _____________________________________ Below are additional basic test for the contract ___________________________

    /**
     * 
     */
    function testAddressRegistry() public {
        //Getter Method test
        address addressRegistry = revestVe.getAddressRegistry();
        assertEq(addressRegistry, Provider, "Address Registry is incorrect!");

        //Calling from non-owner
        hoax(address(0xdead));
        vm.expectRevert("Ownable: caller is not the owner");
        revestVe.setAddressRegistry(address(0xdead));

        //Setter Method test
        hoax(revestVe.owner());
        revestVe.setAddressRegistry(address(0xdead));
        address newAddressRegistry = revestVe.getAddressRegistry();
        assertEq(newAddressRegistry, address(0xdead), "New Address Registry is not set correctly!");
    }

    function testRevestAdmin() public {
        //Getter Method test
        address revestAdmin = revestVe.ADMIN();
        assertEq(revestAdmin, admin, "Revest Admin is incorrect!");

        //Calling from non-owner
        hoax(address(0xdead));
        vm.expectRevert("Ownable: caller is not the owner");
        revestVe.setRevestAdmin(address(0));

        //Setter Method test
        hoax(revestVe.owner());
        revestVe.setRevestAdmin(address(0xdead));
        address newAddressRegistry = revestVe.ADMIN();
        assertEq(newAddressRegistry, address(0xdead), "New revest admin is not set correctly");
    }

    function testAsset() public {
        //Getter Method test
        address asset = revestVe.getAsset(0);
        assertEq(asset, VOTING_ESCROW, "Asset/Underlying Ve contract is incorrect");
    }

    function testWeiFee() public {
        //Getter Method  test
        uint weiFee = revestVe.getFlatWeiFee(fxsWhale);
        assertEq(weiFee, 1 ether, "Current weiFee is incorrect!");

        //Calling from non-owner
        hoax(address(0xdead));
        vm.expectRevert("Ownable: caller is not the owner");
        revestVe.setWeiFee(2 ether);
        
         //Setter Method test
        hoax(revestVe.owner());
        revestVe.setWeiFee(2 ether);
        uint newWeiFee = revestVe.getFlatWeiFee(fxsWhale);
        assertEq(newWeiFee, 2 ether, "New wei fei is not set correctly");
    }

    function testERC20Fee() public {
        //Getter Method
        uint fee = revestVe.getERC20Fee(fxsWhale);
        assertEq(fee, 10, "Current fee percentage is incorrect!"); //10%

        //Calling from non-owner
        hoax(address(0xdead));
        vm.expectRevert("Ownable: caller is not the owner");
        revestVe.setFeePercentage(20);

        //Setter Method test
        hoax(revestVe.owner());
        revestVe.setFeePercentage(20);
        uint newFee = revestVe.getERC20Fee(fxsWhale);
        assertEq(newFee, 20, "New fee percentage is not set correctly!");
    }

    function testMetaData() public {
        //Getter Method
        string memory metadata = revestVe.getCustomMetadata(0);
        assertEq(metadata, "https://revest.mypinata.cloud/ipfs/QmXYdhFqtKFtYW9aEQ8cpPKTm3T1Dv3Hd1uz9ZuYpzeN89", "Metadata is incorrect!");

        //Calling from non-owner
        hoax(address(0xdead));
        vm.expectRevert("Ownable: caller is not the owner");
        revestVe.setMetadata("https://revest.mypinata.cloud/ipfs/fake");

        //Setter Method test
        hoax(address(revestVe.owner()));
        revestVe.setMetadata("https://revest.mypinata.cloud/ipfs/fake");
        string memory newMetadata = revestVe.getCustomMetadata(0);
        assertEq(newMetadata, "https://revest.mypinata.cloud/ipfs/fake", "Metadata is not set correctly!");
    }

    function testHandleFNFTRemaps() public {
        vm.expectRevert("Not applicable");
        revestVe.handleFNFTRemaps(0, new uint[](0), address(0xdead), false);
    }

    function testRescueNativeFunds() public {
        //Fund the contract some money that is falsely allocated
        vm.deal(address(revestVe), 10 ether);
        assertEq(address(revestVe).balance, 10 ether, "Amount of fund does not match!");

        //Calling rescue fund from not owner
        hoax(address(0xdead));
        vm.expectRevert("Ownable: caller is not the owner");
        revestVe.rescueNativeFunds();

        //Balance of Revest Owner before rescueing fund
        uint initialBalance = address(revestVe.owner()).balance;

        //Rescue native fund
        hoax(revestVe.owner(), revestVe.owner());
        revestVe.rescueNativeFunds();
        uint currentBalance = address(revestVe.owner()).balance;
        assertGt(currentBalance, initialBalance, "Fund has not been withdrawn to revest owner!");
    }

    function testRescueERC20() public {
        //Fund the contract some money that is false allocated #PEPE
        ERC20 PEPE = ERC20(0x6982508145454Ce325dDbE47a25d4ec3d2311933);

        deal(address(PEPE), address(revestVe), 10 ether);
        assertEq(PEPE.balanceOf(address(revestVe)), 10 ether, "Amount of fund does not match!");

        //Calling rescue fund from not owner
        hoax(address(0xdead));
        vm.expectRevert("Ownable: caller is not the owner");
        revestVe.rescueERC20(address(PEPE));


        //Balance of Revest Owner before rescueing fund
        uint initialBalance = PEPE.balanceOf(revestVe.owner());

        //Rescue PEPE
        hoax(revestVe.owner(), revestVe.owner());
        revestVe.rescueERC20(address(PEPE));
        uint currentBalance = PEPE.balanceOf(revestVe.owner());

        assertGt(currentBalance, initialBalance, "Fund has not been withdrawn to revest owner!");
    }

    receive() external payable {

    }
}
