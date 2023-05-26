// SPDX-License-Identifier: GNU-GPL v3.0 or later

pragma solidity ^0.8.0;

import "./interfaces/IAddressRegistry.sol";
import "./interfaces/IOutputReceiverV3.sol";
import "./interfaces/ITokenVault.sol";
import "./interfaces/IRevest.sol";
import "./interfaces/IFNFTHandler.sol";
import "./interfaces/ILockManager.sol";
import "./interfaces/IRewardsHandler.sol";
import "./interfaces/IVotingEscrow.sol";
import "./interfaces/IFeeReporter.sol";
import "./interfaces/IDistributor.sol";
import "./VestedEscrowSmartWallet.sol";
import "./SmartWalletWhitelistV2.sol";

// OZ imports
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import '@openzeppelin/contracts/utils/introspection/ERC165.sol';
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

// Libraries
import "./lib/RevestHelper.sol";

interface IWETH {
    function deposit() external payable;
}

/**
 * @title SpiritSwap <> Revest integration for tokenizing inSPIRIT positions
 * @author RobAnon
 * @dev 
 */
contract RevestSpiritSwap is IOutputReceiverV3, Ownable, ERC165, IFeeReporter, ReentrancyGuard {
    
    using SafeERC20 for IERC20;

    // Where to find the Revest address registry that contains info about what contracts live where
    address public addressRegistry;

    // Address of voting escrow contract
    address public immutable VOTING_ESCROW;

    // Token used for voting escrow
    address public immutable TOKEN;

    // Distributor for rewards address
    address public DISTRIBUTOR;

    // NFT Garage Admin Account 
    address public ADMIN;

    // SPIRIT token    
    address public constant REWARD_TOKEN = 0x5Cc61A78F164885776AA610fb0FE1257df78E59B;

    // Template address for VE wallets
    address public immutable TEMPLATE;

    // The file which tells our frontend how to visually represent such an FNFT
    string public METADATA = "https://revest.mypinata.cloud/ipfs/QmXYdhFqtKFtYW9aEQ8cpPKTm3T1Dv3Hd1uz9ZuYpzeN89";

    // Constant used for approval
    uint private constant MAX_INT = 2 ** 256 - 1;

    uint private constant WEEK = 7 * 86400;

    uint private constant MAX_LOCKUP = 4 * 365 days;

    uint private constant FREE_AMOUNT = 100 ether;

    // Fee tracker
    uint private weiFee = 1 ether;

    // For tracking if a given contract has approval for token
    mapping (address => mapping (address => bool)) private approvedContracts;

    // For tracking wallet approvals for tokens
    // Works for up to 256 tokens
    mapping (address => mapping (uint => uint)) private walletApprovals;


    /// Mapping for tracking SPIRIT holders whitelist
    mapping (address => bool) public whitelist;

    // WFTM contract
    address private constant WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;


    // Control variable to let all users utilize smart wallets for proxy execution
    bool public globalProxyEnabled;

    // Control variable to enable a given FNFT to utilize their smart wallet for proxy execution
    mapping (uint => bool) public proxyEnabled;

    // Control variable to enable the whitelist or disable it
    bool public whitelistEnabled;

    // Initialize the contract with the needed valeus
    constructor(address _provider, address _vE, address _distro, address _spiritAdmin) {
        addressRegistry = _provider;
        VOTING_ESCROW = _vE;
        TOKEN = IVotingEscrow(_vE).token();
        VestedEscrowSmartWallet wallet = new VestedEscrowSmartWallet(REWARD_TOKEN);
        TEMPLATE = address(wallet);
        DISTRIBUTOR = _distro;
        ADMIN = _spiritAdmin;
    }

    modifier onlyRevestController() {
        require(msg.sender == IAddressRegistry(addressRegistry).getRevest(), 'Unauthorized Access!');
        _;
    }

    modifier onlyTokenHolder(uint fnftId) {
        IAddressRegistry reg = IAddressRegistry(addressRegistry);
        require(IFNFTHandler(reg.getRevestFNFT()).getBalance(msg.sender, fnftId) > 0, 'E064');
        _;
    }

    // Allows core Revest contracts to make sure this contract can do what is needed
    // Mandatory method
    function supportsInterface(bytes4 interfaceId) public view override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IOutputReceiver).interfaceId
            || interfaceId == type(IOutputReceiverV2).interfaceId
            || interfaceId == type(IOutputReceiverV3).interfaceId
            || super.supportsInterface(interfaceId);
    }


    function lockSpiritSwapTokens(
        uint endTime,
        uint amountToLock,
        bool useWhitelist
    ) external payable nonReentrant returns (uint fnftId) {    
        require(msg.value >= weiFee, 'Insufficient fee!');
        require(!useWhitelist || (whitelistEnabled && whitelist[msg.sender]), '!whitelisted');

        // Immediately remove sender from whitelist to follow checks-effects-interactions
        if(useWhitelist) {
            whitelist[msg.sender] = false;
        }

        // Pay fee: this is dependent on this contract being whitelisted to allow it to pay
        // nothing via the typical method
        // Pay fee to SPIRIT ADMIN
        {
            uint wftmFee = msg.value;
            IWETH(WFTM).deposit{value: msg.value}();
            IERC20(WFTM).safeTransfer(ADMIN, wftmFee);
        }

        /// Mint FNFT
        {
            // Initialize the Revest config object
            IRevest.FNFTConfig memory fnftConfig;

            // Want FNFT to be extendable and support multiple deposits
            fnftConfig.isMulti = true;

            fnftConfig.maturityExtension = true;

            // Will result in the asset being sent back to this contract upon withdrawal
            // Results solely in a callback
            fnftConfig.pipeToContract = address(this);  

            // Set these two arrays according to Revest specifications to say
            // Who gets these FNFTs and how many copies of them we should create
            address[] memory recipients = new address[](1);
            recipients[0] = _msgSender();

            uint[] memory quantities = new uint[](1);
            quantities[0] = 1;

            address revest = IAddressRegistry(addressRegistry).getRevest();
            
            fnftId = IRevest(revest).mintTimeLock(endTime, recipients, quantities, fnftConfig);
        }

        address smartWallAdd;
        {
            // We deploy the smart wallet
            smartWallAdd = Clones.cloneDeterministic(TEMPLATE, keccak256(abi.encode(TOKEN, fnftId)));
            VestedEscrowSmartWallet wallet = VestedEscrowSmartWallet(smartWallAdd);

            // Transfer the tokens from the user to the smart wallet
            if(useWhitelist) {
                amountToLock = FREE_AMOUNT;
                IERC20(TOKEN).safeTransfer(smartWallAdd, amountToLock);
            } else {
                IERC20(TOKEN).safeTransferFrom(msg.sender, smartWallAdd, amountToLock);
            }

            // We use our admin powers on SmartWalletWhitelistV2 to approve the newly created smart wallet
            SmartWalletWhitelistV2(IVotingEscrow(VOTING_ESCROW).smart_wallet_checker()).approveWallet(smartWallAdd);

            // We deposit our funds into the wallet
            wallet.createLock(amountToLock, endTime, VOTING_ESCROW);
            emit DepositERC20OutputReceiver(msg.sender, TOKEN, amountToLock, fnftId, abi.encode(smartWallAdd));
        }
    }


    function receiveRevestOutput(
        uint fnftId,
        address,
        address payable owner,
        uint
    ) external override nonReentrant {
        // Security check to make sure the Revest vault is the only contract that can call this method
        address vault = IAddressRegistry(addressRegistry).getTokenVault();
        require(_msgSender() == vault, 'E016');

        address smartWallAdd = Clones.cloneDeterministic(TEMPLATE, keccak256(abi.encode(TOKEN, fnftId)));
        VestedEscrowSmartWallet wallet = VestedEscrowSmartWallet(smartWallAdd);

        wallet.withdraw(VOTING_ESCROW);
        uint balance = IERC20(TOKEN).balanceOf(address(this));
        IERC20(TOKEN).safeTransfer(owner, balance);

        // Clean up memory
        SmartWalletWhitelistV2(IVotingEscrow(VOTING_ESCROW).smart_wallet_checker()).revokeWallet(smartWallAdd);

        emit WithdrawERC20OutputReceiver(owner, TOKEN, balance, fnftId, abi.encode(smartWallAdd));
    }

    // Not applicable, as these cannot be split
    function handleFNFTRemaps(uint, uint[] memory, address, bool) external pure override {
        require(false, 'Not applicable');
    }

    // Allows custom parameters to be passed during withdrawals
    function receiveSecondaryCallback(
        uint fnftId,
        address payable owner,
        uint quantity,
        IRevest.FNFTConfig memory config,
        bytes memory args
    ) external payable override {}

    // Callback from Revest.sol to extend maturity
    function handleTimelockExtensions(uint fnftId, uint expiration, address) external override onlyRevestController {
        require(expiration - block.timestamp <= MAX_LOCKUP, 'Max lockup is 2 years');
        address smartWallAdd = Clones.cloneDeterministic(TEMPLATE, keccak256(abi.encode(TOKEN, fnftId)));
        VestedEscrowSmartWallet wallet = VestedEscrowSmartWallet(smartWallAdd);
        wallet.increaseUnlockTime(expiration, VOTING_ESCROW);
    }

    /// Prerequisite: User has approved this contract to spend tokens on their behalf
    function handleAdditionalDeposit(uint fnftId, uint amountToDeposit, uint, address caller) external override nonReentrant onlyRevestController {
        address smartWallAdd = Clones.cloneDeterministic(TEMPLATE, keccak256(abi.encode(TOKEN, fnftId)));
        VestedEscrowSmartWallet wallet = VestedEscrowSmartWallet(smartWallAdd);
        IERC20(TOKEN).safeTransferFrom(caller, smartWallAdd, amountToDeposit);
        wallet.increaseAmount(amountToDeposit, VOTING_ESCROW);
    }

    // Not applicable
    function handleSplitOperation(uint fnftId, uint[] memory proportions, uint quantity, address caller) external override {}

    // Claims rewards on user's behalf
    function triggerOutputReceiverUpdate(
        uint fnftId,
        bytes memory
    ) external override onlyTokenHolder(fnftId) {
        address rewardsAdd = IAddressRegistry(addressRegistry).getRewardsHandler();
        address smartWallAdd = Clones.cloneDeterministic(TEMPLATE, keccak256(abi.encode(TOKEN, fnftId)));
        VestedEscrowSmartWallet wallet = VestedEscrowSmartWallet(smartWallAdd);
        { 
            // Want this to be re-run if we change fee distributors or rewards handlers
            address virtualAdd = address(uint160(uint256(keccak256(abi.encodePacked(DISTRIBUTOR, rewardsAdd)))));
            if(!_isApproved(smartWallAdd, virtualAdd)) {
                address[] memory addrArray = new address[](1);
                addrArray[0] = REWARD_TOKEN;
                wallet.proxyApproveAll(addrArray, rewardsAdd);
                _setIsApproved(smartWallAdd, virtualAdd, true);
            }
        }
        wallet.claimRewards(DISTRIBUTOR, VOTING_ESCROW, msg.sender, rewardsAdd, ADMIN);
    }       

    function proxyExecute(
        uint fnftId,
        address destination,
        bytes memory data
    ) external onlyTokenHolder(fnftId) returns (bytes memory dataOut) {
        require(globalProxyEnabled || proxyEnabled[fnftId], 'Proxy access not enabled!');
        address smartWallAdd = Clones.cloneDeterministic(TEMPLATE, keccak256(abi.encode(TOKEN, fnftId)));
        VestedEscrowSmartWallet wallet = VestedEscrowSmartWallet(smartWallAdd);
        dataOut = wallet.proxyExecute(destination, data);
        wallet.cleanMemory();
    }

    // Utility functions

    function _isApproved(address wallet, address feeDistro) internal view returns (bool) {
        uint256 _id = uint256(uint160(feeDistro));
        uint256 _mask = 1 << _id % 256;
        return (walletApprovals[wallet][_id / 256] & _mask) != 0;
    }

    function _setIsApproved(address wallet, address feeDistro, bool _approval) internal {
        uint256 _id = uint256(uint160(feeDistro));
        if (_approval) {
            walletApprovals[wallet][_id / 256] |= 1 << _id % 256;
        } else {
            walletApprovals[wallet][_id / 256] &= 0 << _id % 256;
        }
    }


    /// Admin Functions

    function setAddressRegistry(address addressRegistry_) external override onlyOwner {
        addressRegistry = addressRegistry_;
    }

    function setDistributor(address _distro) external onlyOwner {
        DISTRIBUTOR = _distro;
    }

    function setSpiritAdmin(address _admin) external onlyOwner {
        ADMIN = _admin;
    }

    function setWeiFee(uint _fee) external onlyOwner {
        weiFee = _fee;
    }

    function setMetadata(string memory _meta) external onlyOwner {
        METADATA = _meta;
    }

    function setGlobalProxyEnabled(bool enable) external onlyOwner {
        globalProxyEnabled = enable;
    }

    function setProxyStatusForFNFT(uint fnftId, bool status) external onlyOwner {
        proxyEnabled[fnftId] = status;
    }

    /// If funds are mistakenly sent to smart wallets, this will allow the owner to assist in rescue
    function rescueNativeFunds() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    /// Under no circumstances should this contract ever contain ERC-20 tokens at the end of a transaction
    /// If it does, someone has mistakenly sent funds to the contract, and this function can rescue their tokens
    function rescueERC20(address token) external onlyOwner {
        uint amount = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    /// Can both add to and remove from the whitelist, depending on the value of bool
    function batchModifyWhitelist(address[] memory holders, bool addToWhitelist) external onlyOwner {
        for(uint i = 0; i < holders.length; i++) {
            whitelist[holders[i]] = addToWhitelist;
        }
    }

    function setWhitelistActive(bool _enableWhitelist) external onlyOwner {
        whitelistEnabled = _enableWhitelist;
    }

    /// View Functions

    function getCustomMetadata(uint) external view override returns (string memory) {
        return METADATA;
    }

    // Will give balance in xLQDR
    function getValue(uint fnftId) public view override returns (uint) {
        return IVotingEscrow(VOTING_ESCROW).balanceOf(Clones.predictDeterministicAddress(TEMPLATE, keccak256(abi.encode(TOKEN, fnftId))));
    }

    // Must always be in native token
    function getAsset(uint) external view override returns (address) {
        return VOTING_ESCROW;
    }

    function getOutputDisplayValues(uint fnftId) external view override returns (bytes memory displayData) {
        (uint reward, bool hasRewards) = getRewardsForFNFT(fnftId);
        string memory rewardsDesc;
        if(hasRewards) {
            string memory par1 = string(abi.encodePacked(RevestHelper.getName(REWARD_TOKEN),": "));
            string memory par2 = string(abi.encodePacked(RevestHelper.amountToDecimal(reward, REWARD_TOKEN), " [", RevestHelper.getTicker(REWARD_TOKEN), "] Tokens Available"));
            rewardsDesc = string(abi.encodePacked(par1, par2));
        }
        address smartWallet = getAddressForFNFT(fnftId);
        uint maxExtension = block.timestamp / (1 weeks) * (1 weeks) + MAX_LOCKUP; //Ensures no confusion with time zones and date-selectors
        (int128 spiritBalance, ) = IVotingEscrow(VOTING_ESCROW).locked(smartWallet);
        displayData = abi.encode(smartWallet, rewardsDesc, hasRewards, maxExtension, TOKEN, spiritBalance);
    }

    function getAddressRegistry() external view override returns (address) {
        return addressRegistry;
    }

    function getRevest() internal view returns (IRevest) {
        return IRevest(IAddressRegistry(addressRegistry).getRevest());
    }

    function getFlatWeiFee(address) external view override returns (uint) {
        return weiFee;
    }

    function getERC20Fee(address) external pure override returns (uint) {
        return 0;
    }

    function getAddressForFNFT(uint fnftId) public view returns (address smartWallAdd) {
        smartWallAdd = Clones.predictDeterministicAddress(TEMPLATE, keccak256(abi.encode(TOKEN, fnftId)));
    }

    // Find rewards for a given smart wallet using the Curve formulae
    function getRewardsForFNFT(uint fnftId) private view returns (uint reward, bool rewardsPresent) {
        uint userEpoch;
        IDistributor distro = IDistributor(DISTRIBUTOR);
        IVotingEscrow voting = IVotingEscrow(VOTING_ESCROW);
        address smartWallAdd = getAddressForFNFT(fnftId);
        
        uint lastTokenTime = distro.last_token_time();
        lastTokenTime = lastTokenTime / WEEK * WEEK;

        uint maxUserEpoch = voting.user_point_epoch(smartWallAdd);
        uint startTime = distro.start_time();
        
        if(maxUserEpoch == 0) {
            return (reward, rewardsPresent);
        }

        uint weekCursor = distro.time_cursor_of(smartWallAdd);
        if(weekCursor == 0) {
            userEpoch = findTimestampUserEpoch(smartWallAdd, startTime, maxUserEpoch);
        } else {
            userEpoch = distro.user_epoch_of(smartWallAdd);
        }

        if(userEpoch == 0) {
            userEpoch = 1;
        }

        IVotingEscrow.Point memory userPoint = voting.user_point_history(smartWallAdd, userEpoch);

        if(weekCursor == 0) {
            weekCursor = (userPoint.ts + WEEK - 1) / WEEK * WEEK;
        }

        if(weekCursor >= lastTokenTime) {
            return (reward, rewardsPresent);
        }

        if(weekCursor < startTime) {
            weekCursor = startTime;
        }

        IVotingEscrow.Point memory oldUserPoint;

        for(uint i = 0; i < 150; i++) {
            if(weekCursor >= lastTokenTime) {
                break;
            }

            if(weekCursor >= userPoint.ts && userEpoch <= maxUserEpoch) {
                userEpoch++;
                oldUserPoint = userPoint;
                if(userEpoch > maxUserEpoch) {
                    IVotingEscrow.Point memory tmpPoint;
                    userPoint = tmpPoint;
                } else {
                    userPoint = voting.user_point_history(smartWallAdd, userEpoch);
                }
            } else {
                uint balanceOf;
                {
                    int128 dt = int128(uint128(weekCursor - oldUserPoint.ts));
                    int128 res = oldUserPoint.bias - dt * oldUserPoint.slope;
                    balanceOf = res > 0 ? uint(int256(res)) : 0;
                }
                if(balanceOf == 0 && userEpoch > maxUserEpoch) {
                    break;
                } 
                if(balanceOf > 0) {
                    
                    reward += balanceOf * distro.tokens_per_week(weekCursor) / distro.ve_supply(weekCursor);
                    if(reward > 0 && !rewardsPresent) {
                        rewardsPresent = true;
                    } 
                    
                }
                weekCursor += WEEK;
            }
        }

        return (reward, rewardsPresent);
    }

    // Implementation of Binary Search
    function findTimestampUserEpoch(address user, uint timestamp, uint maxUserEpoch) private view returns (uint timestampEpoch) {
        uint min;
        uint max = maxUserEpoch;
        for(uint i = 0; i < 128; i++) {
            if(min >= max) {
                break;
            }
            uint mid = (min + max + 2) / 2;
            uint ts = IVotingEscrow(VOTING_ESCROW).user_point_history(user, mid).ts;
            if(ts <= timestamp) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return min;
    }

    
}
