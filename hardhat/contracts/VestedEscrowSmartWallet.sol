// SPDX-License-Identifier: GNU-GPL v3.0 or later

import "./interfaces/IVotingEscrow.sol";
import "./interfaces/IRewardsHandler.sol";
import "./interfaces/IYieldDistributor.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../lib/forge-std/src/console.sol";


pragma solidity ^0.8.0;

/// @author RobAnon
contract VestedEscrowSmartWallet {

    using SafeERC20 for IERC20;

    uint private constant MAX_INT = 2 ** 256 - 1;

    address private immutable MASTER;

    address private immutable LOCK_TOKEN;

    address private immutable REWARD_TOKEN;

    address private immutable VOTING_ESCROW;

    address private immutable DISTRIBUTOR;

    uint private constant PERCENTAGE = 1000;

    constructor(address _votingEscrow, address _distributor) {
        MASTER = msg.sender;
        VOTING_ESCROW = _votingEscrow;
        LOCK_TOKEN = IVotingEscrow(_votingEscrow).token();
        REWARD_TOKEN = IVotingEscrow(_votingEscrow).token();
        DISTRIBUTOR = _distributor;
    }

    modifier onlyMaster() {
        require(msg.sender == MASTER, 'Unauthorized!');
        _;
    }

    function createLock(uint value, uint unlockTime) external onlyMaster {
        // Only callable from the parent contract, transfer tokens from user -> parent, parent -> VE

        // Single-use approval system
        if(IERC20(LOCK_TOKEN).allowance(address(this), VOTING_ESCROW) != MAX_INT) {
            IERC20(LOCK_TOKEN).approve(VOTING_ESCROW, MAX_INT);
        }
        // Create the lock
        IVotingEscrow(VOTING_ESCROW).create_lock(value, unlockTime);
        IYieldDistributor(DISTRIBUTOR).checkpoint();
        _cleanMemory();
    }


    function increaseAmount(uint value) external onlyMaster {
        IVotingEscrow(VOTING_ESCROW).increase_amount(value);
        IYieldDistributor(DISTRIBUTOR).checkpoint();
        _cleanMemory();
    }

    function increaseUnlockTime(uint unlockTime) external onlyMaster {
        IVotingEscrow(VOTING_ESCROW).increase_unlock_time(unlockTime);
        IYieldDistributor(DISTRIBUTOR).checkpoint();
        _cleanMemory();
    }

    function withdraw() external onlyMaster {
        address token = IVotingEscrow(VOTING_ESCROW).token();
        IVotingEscrow(VOTING_ESCROW).withdraw();
        uint bal = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(MASTER, bal);
        _cleanMemory();
    }

    function claimRewards(
        address caller, 
        address rewards, 
        uint performanceFee //address that receives the fee 
    ) external onlyMaster {
        //Claim yield from yieldDistributor to smart wallet
        IYieldDistributor(DISTRIBUTOR).getYield();

        //claiming fee
        uint bal = IERC20(REWARD_TOKEN).balanceOf(address(this));
        uint fee = bal * performanceFee / PERCENTAGE;
        bal -= fee;
        IERC20(REWARD_TOKEN).safeTransfer(rewards, fee);
        console.log("Fee in claimRewards: ", fee);
        emit FeeCollection(REWARD_TOKEN, fee);

        //distribute yield claim
        IERC20(REWARD_TOKEN).safeTransfer(caller, bal);
        _cleanMemory();
    }


    /// Proxy function to send arbitrary messages. Useful for delegating votes and similar activities
    function proxyExecute(
        address destination,
        bytes memory data
    ) external payable onlyMaster returns (bytes memory dataOut) {
        (bool success, bytes memory dataTemp)= destination.call{value:msg.value}(data);
        require(success, 'Proxy call failed!');
        dataOut = dataTemp;
    }

    /// Self-destructing clone pattern
    function cleanMemory() external onlyMaster {
        _cleanMemory();
    }

    function _cleanMemory() internal {
        selfdestruct(payable(MASTER));
    }

    event FeeCollection(address indexed token, uint indexed amount);
}
