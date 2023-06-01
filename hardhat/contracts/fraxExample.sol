// // SPDX-License-Identifier: GNU-GPL v3.0 or later

// pragma solidity ^0.8.0;

// import "./interfaces/IAddressRegistry.sol";
// import "./interfaces/IOutputReceiverV3.sol";
// import "./interfaces/ITokenVault.sol";
// import "./interfaces/IRevest.sol";
// import "./interfaces/IFNFTHandler.sol";
// import "./interfaces/ILockManager.sol";

// import "./interfaces/IFraxFarmERC20.sol";
// import "./interfaces/IFraxFarmBase.sol";
// import "./interfaces/IConvexWrapperV2.sol";
// import "./interfaces/IRewards.sol";

// import "./VestedEscrowSmartWallet.sol";

// // OZ imports
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
// import '@openzeppelin/contracts/utils/introspection/ERC165.sol';
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/proxy/Clones.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// // Libraries
// import "./lib/RevestHelper.sol";

// interface ITokenVaultTracker {
//     function tokenTrackers(address token) external view returns (IRevest.TokenTracker memory);
// }

// interface IWETH {
//     function deposit() external payable;
// }

// /**
//  * @title LiquidDriver <> Revest integration for tokenizing xLQDR positions
//  * @author RobAnon
//  * @dev 
//  */
// contract RevestConvexFrax is IOutputReceiverV3, Ownable, ERC165, ReentrancyGuard {
    
//     using SafeERC20 for IERC20;

//     address public constant CURVE_LP = 0xf43211935C781D5ca1a41d2041F397B8A7366C7A;

//     address public constant STAKING_TOKEN = 0x4659d5fF63A1E1EDD6D5DD9CC315e063c95947d0; // ConvexWrapperV2

//     address public constant STAKING_ADDRESS = 0xa537d64881b84faffb9Ae43c951EEbF368b71cdA;

//     address public constant CONVEX_DEPOSIT_TOKEN = 0xC07e540DbFecCF7431EA2478Eb28A03918c1C30E;

//     address public constant REWARDS = 0x3465B8211278505ae9C6b5ba08ECD9af951A6896;


//     // Where to find the Revest address registry that contains info about what contracts live where
//     address public addressRegistry;

//     // Token used for voting escrow
//     address public constant TOKEN = 0xf43211935C781D5ca1a41d2041F397B8A7366C7A;

//     // Template address for VE wallets
//     address public immutable TEMPLATE;

//     // The file which tells our frontend how to visually represent such an FNFT
//     string public METADATA = "https://revest.mypinata.cloud/ipfs/QmRLesf7CzwLapJS3aWWM9wS9HqgvX8Z36zQhWSd1uMFmp";

//     // Constant used for approval
//     uint private constant MAX_INT = 2 ** 256 - 1;

//     uint private constant DAY = 86400;

//     uint private constant MAX_LOCKUP = 2 * 365 days;

//     mapping (uint => bytes32) public kekIds;


//     // Initialize the contract with the needed valeus
//     constructor(address _provider) {
//         addressRegistry = _provider;
//         VestedEscrowSmartWallet wallet = new VestedEscrowSmartWallet();
//         TEMPLATE = address(wallet);
//     }

//     modifier onlyRevestController() {
//         require(msg.sender == IAddressRegistry(addressRegistry).getRevest(), 'Unauthorized Access!');
//         _;
//     }

//     modifier onlyTokenHolder(uint fnftId) {
//         IAddressRegistry reg = IAddressRegistry(addressRegistry);
//         require(IFNFTHandler(reg.getRevestFNFT()).getBalance(msg.sender, fnftId) > 0, 'E064');
//         _;
//     }

//     // Allows core Revest contracts to make sure this contract can do what is needed
//     // Mandatory method
//     function supportsInterface(bytes4 interfaceId) public view override(ERC165, IERC165) returns (bool) {
//         return interfaceId == type(IOutputReceiver).interfaceId
//             || interfaceId == type(IOutputReceiverV2).interfaceId
//             || interfaceId == type(IOutputReceiverV3).interfaceId
//             || super.supportsInterface(interfaceId);
//     }

//     function lockTokens(
//         uint endTime,
//         uint amountToLock
//     ) external nonReentrant returns (uint fnftId) {    

//         /// Mint FNFT
//         {
//             // Initialize the Revest config object
//             IRevest.FNFTConfig memory fnftConfig;

//             // Want FNFT to be extendable and support multiple deposits
//             fnftConfig.isMulti = true;

//             fnftConfig.maturityExtension = true;

//             // Will result in the asset being sent back to this contract upon withdrawal
//             // Results solely in a callback
//             fnftConfig.pipeToContract = address(this);  

//             // Set these two arrays according to Revest specifications to say
//             // Who gets these FNFTs and how many copies of them we should create
//             address[] memory recipients = new address[](1);
//             recipients[0] = _msgSender();

//             uint[] memory quantities = new uint[](1);
//             quantities[0] = 1;

//             address revest = IAddressRegistry(addressRegistry).getRevest();

            
//             fnftId = IRevest(revest).mintTimeLock(endTime, recipients, quantities, fnftConfig);
//         }

//         address smartWallAdd;
//         {
//             // We deploy the smart wallet
//             smartWallAdd = Clones.cloneDeterministic(TEMPLATE, keccak256(abi.encode(TOKEN, fnftId)));
//             VestedEscrowSmartWallet wallet = VestedEscrowSmartWallet(smartWallAdd);

//             // Transfer the tokens from the user to this wallet
//             IERC20(CURVE_LP).safeTransferFrom(msg.sender, smartWallAdd, amountToLock);

//             // We deposit our funds into the wallet, store kek_id
//             kekIds[fnftId] = wallet.createLock(amountToLock, endTime, msg.sender);
//             wallet.cleanMemory();
//             emit DepositERC20OutputReceiver(msg.sender, TOKEN, amountToLock, fnftId, abi.encode(smartWallAdd));
//         }
//     }


//     function receiveRevestOutput(
//         uint fnftId,
//         address,
//         address payable caller,
//         uint
//     ) external override  {
        
//         // Security check to make sure the Revest vault is the only contract that can call this method
//         address vault = IAddressRegistry(addressRegistry).getTokenVault();
//         require(_msgSender() == vault, 'E016');

//         address smartWallAdd = Clones.cloneDeterministic(TEMPLATE, keccak256(abi.encode(TOKEN, fnftId)));
//         VestedEscrowSmartWallet wallet = VestedEscrowSmartWallet(smartWallAdd);

//         uint balance = wallet.withdraw(kekIds[fnftId], caller);
//         wallet.cleanMemory();
//         emit WithdrawERC20OutputReceiver(caller, TOKEN, balance, fnftId, abi.encode(smartWallAdd));
//     }

//     // Not applicable, as these cannot be split
//     function handleFNFTRemaps(uint, uint[] memory, address, bool) external pure override {
//         require(false, 'Not applicable');
//     }
    
//     // Allows custom parameters to be passed during withdrawals
//     // This and the proceeding method are both parts of the V2 output receiver interface
//     // and not typically necessary. For the sake of demonstration, they are included
//     function receiveSecondaryCallback(
//         uint fnftId,
//         address payable owner,
//         uint quantity,
//         IRevest.FNFTConfig memory config,
//         bytes memory args
//     ) external payable override {}

//     // Callback from Revest.sol to extend maturity
//     function handleTimelockExtensions(uint fnftId, uint expiration, address caller) external override onlyRevestController {
//         require(expiration - block.timestamp <= MAX_LOCKUP, 'Max lockup is 2 years');
//         address smartWallAdd = Clones.cloneDeterministic(TEMPLATE, keccak256(abi.encode(TOKEN, fnftId)));
//         VestedEscrowSmartWallet wallet = VestedEscrowSmartWallet(smartWallAdd);
//         wallet.increaseUnlockTime(expiration, kekIds[fnftId], caller);
//     }

//     /// Prerequisite: User has approved this contract to spend tokens on their behalf
//     function handleAdditionalDeposit(uint fnftId, uint amountToDeposit, uint, address caller) external override onlyRevestController {
//         address smartWallAdd = Clones.cloneDeterministic(TEMPLATE, keccak256(abi.encode(TOKEN, fnftId)));
//         VestedEscrowSmartWallet wallet = VestedEscrowSmartWallet(smartWallAdd);
//         IERC20(TOKEN).safeTransferFrom(caller, smartWallAdd, amountToDeposit);
//         wallet.increaseAmount(amountToDeposit, kekIds[fnftId], caller);
//     }

//     // Not applicable
//     function handleSplitOperation(uint fnftId, uint[] memory proportions, uint quantity, address caller) external override {}

//     // Claims REWARDS on user's behalf
//     function triggerOutputReceiverUpdate(
//         uint fnftId,
//         bytes memory
//     ) external override nonReentrant onlyTokenHolder(fnftId) {
//         address smartWallAdd = Clones.cloneDeterministic(TEMPLATE, keccak256(abi.encode(TOKEN, fnftId)));
//         VestedEscrowSmartWallet wallet = VestedEscrowSmartWallet(smartWallAdd);
//         wallet.claimRewards(msg.sender);
//     }       


//     /// Admin Functions

//     function setAddressRegistry(address addressRegistry_) external override onlyOwner {
//         addressRegistry = addressRegistry_;
//     }

//     function setMetadata(string memory _meta) external onlyOwner {
//         METADATA = _meta;
//     }

//     /// If funds are mistakenly sent to smart wallets, this will allow the owner to assist in rescue
//     function rescueNativeFunds() external onlyOwner {
//         payable(msg.sender).transfer(address(this).balance);
//     }

//     /// Under no circumstances should this contract ever contain ERC-20 tokens at the end of a transaction
//     /// If it does, someone has mistakenly sent funds to the contract, and this function can rescue their tokens
//     function rescueERC20(address token) external onlyOwner {
//         uint amount = IERC20(token).balanceOf(address(this));
//         IERC20(token).safeTransfer(msg.sender, amount);
//     }

//     /// View Functions

//     function getCustomMetadata(uint) external view override returns (string memory) {
//         return METADATA;
//     }
    
//     // Will give balance in LPs
//     function getValue(uint fnftId) public view override returns (uint) {
//         return IConvexWrapperV2(STAKING_TOKEN).totalBalanceOf(Clones.predictDeterministicAddress(TEMPLATE, keccak256(abi.encode(TOKEN, fnftId))));
//     }

//     // Must always be in native token
//     function getAsset(uint) external pure override returns (address) {
//         return CURVE_LP;
//     }

//     function getOutputDisplayValues(uint fnftId) external view override returns (bytes memory displayData) {
//         (address[] memory tokens, uint256[] memory rewardAmounts) = earned(fnftId);
//         string[] memory rewardsDesc = new string[](rewardAmounts.length);
//         bool hasRewards = rewardAmounts.length > 0;
//         if(hasRewards) {
//             for(uint i = 0; i < tokens.length; i++) {
//                 address token = tokens[i];
//                 string memory par1 = string(abi.encodePacked(RevestHelper.getName(token),": "));
//                 string memory par2 = string(abi.encodePacked(RevestHelper.amountToDecimal(rewardAmounts[i], token), " [", RevestHelper.getTicker(token), "] Tokens Available"));
//                 rewardsDesc[i] = string(abi.encodePacked(par1, par2));
//             }
//         }
//         address smartWallet = getAddressForFNFT(fnftId);
//         uint maxExtension = block.timestamp / (1 days) * (1 days) + MAX_LOCKUP; //Ensures no confusion with time zones and date-selectors
//         displayData = abi.encode(smartWallet, rewardsDesc, hasRewards, maxExtension, TOKEN);
//     }

//     function getAddressRegistry() external view override returns (address) {
//         return addressRegistry;
//     }

//     function getRevest() internal view returns (IRevest) {
//         return IRevest(IAddressRegistry(addressRegistry).getRevest());
//     }

//     function getAddressForFNFT(uint fnftId) public view returns (address smartWallAdd) {
//         smartWallAdd = Clones.predictDeterministicAddress(TEMPLATE, keccak256(abi.encode(TOKEN, fnftId)));
//     }

    
//     //helper function to combine earned tokens on staking contract and any tokens that are on this vault
//     function earned(uint fnftId) internal view returns (address[] memory token_addresses, uint256[] memory total_earned) {
//         //get list of reward tokens
//         address smartWallAdd = getAddressForFNFT(fnftId);

//         address[] memory rewardTokens = IFraxFarmERC20(STAKING_ADDRESS).getAllRewardTokens();
//         uint256[] memory stakedearned = IFraxFarmERC20(STAKING_ADDRESS).earned(smartWallAdd);
//         IConvexWrapperV2.EarnedData[] memory convexrewards = IConvexWrapperV2(STAKING_TOKEN).earnedView(smartWallAdd);

//         uint256 extraRewardsLength = IRewards(REWARDS).rewardTokenLength();
//         token_addresses = new address[](rewardTokens.length + extraRewardsLength + convexrewards.length);
//         total_earned = new uint256[](rewardTokens.length + extraRewardsLength + convexrewards.length);

//         //add any tokens that happen to be already claimed but sitting on the vault
//         //(ex. withdraw claiming REWARDS)
//         for(uint256 i = 0; i < rewardTokens.length; i++){
//             token_addresses[i] = rewardTokens[i];
//             total_earned[i] = stakedearned[i] + IERC20(rewardTokens[i]).balanceOf(smartWallAdd);
//         }

//         IRewards.EarnedData[] memory extraRewards = IRewards(REWARDS).claimableRewards(smartWallAdd);
//         for(uint256 i = 0; i < extraRewards.length; i++){
//             token_addresses[i+rewardTokens.length] = extraRewards[i].token;
//             total_earned[i+rewardTokens.length] = extraRewards[i].amount;
//         }

//         //add convex farm earned tokens
//         for(uint256 i = 0; i < convexrewards.length; i++){
//             token_addresses[i+rewardTokens.length+extraRewardsLength] = convexrewards[i].token;
//             total_earned[i+rewardTokens.length+extraRewardsLength] = convexrewards[i].amount;
//         }
//     }
    
// }