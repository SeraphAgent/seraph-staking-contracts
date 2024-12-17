// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// TODO: timestamp for batch
// TODO: fallback and recieve
// TODO: recoverALL to stakers
// TODO: recoverALL to owner
// TODO: batchClaims based on time
// TODO; depositERC20 + add batch time

pragma solidity ^0.8.26;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Stake } from "./libraries/Stake.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

error InvalidLockMonths(uint256 lockMonths);

contract SeraphPool is Ownable, ReentrancyGuard, Pausable {
    using SafeCast for *;
    using Stake for Stake.Staker;

    constructor(address _seraphToken, address _rewardToken) Ownable(msg.sender) {
        seraphToken = _seraphToken;
    }

    struct User {
        uint256 pendingRewards;
        Stake.Staker[] stakes;
    }

    struct UnstakeParameter {
        uint256 stakeId;
        uint256 value;
    }

    mapping(address => User) public users;
    mapping(address => bool) public rewardTokenAllowed;

    address public seraphToken;
    uint256 public poolTokenReserve;

    event LogStake(address indexed by, address indexed from, uint256 stakeId, uint256 value, uint256 lockUntil);
    event LogUnstakeLocked(address indexed to, uint256 stakeId, uint256 value);
    event LogUnstakeLockedMultiple(address indexed to, uint256 totalValue);
    event LogClaimVaultRewards(address indexed by, address indexed from, uint256 value);
    event LogReceiveVaultRewards(address indexed by, uint256 value);

    function balanceOf(address _user) external view virtual returns (uint256 balance) {
        // gets storage pointer to _user
        User storage user = users[_user];
        // loops over each user stake and adds to the total balance.
        for (uint256 i = 0; i < user.stakes.length; i++) {
            balance += user.stakes[i].staked;
        }
    }

    function getStake(address _user, uint256 _stakeId) external view virtual returns (Stake.Staker memory) {
        // read stake at specified index and return
        return users[_user].stakes[_stakeId];
    }

    function getStakesLength(address _user) external view virtual returns (uint256) {
        // read stakes array length and return
        return users[_user].stakes.length;
    }

    function pause(bool _shouldPause) external onlyOwner {
        // checks if caller is authorized to pause
        // _requireIsFactoryController();
        // checks bool input and pause/unpause the contract depending on
        // msg.sender's request
        if (_shouldPause) {
            super._pause();
        } else {
            super._unpause();
        }
    }

    function stake(uint256 _value, uint256 _lockDuration) external virtual nonReentrant {
        _requireNotPaused();
        if (_lockDuration < Stake.MIN_LOCK_MONTHS || _lockDuration > Stake.MAX_LOCK_MONTHS) {
            revert InvalidLockMonths(_lockDuration);
        }
        User storage user = users[msg.sender];
        uint256 lockUntil = block.timestamp + _lockDuration * 30 days;
        Stake.Staker memory staker = Stake.Staker({
            staked: _value,
            lockedFrom: block.timestamp,
            lockedUntil: lockUntil,
            lockMonths: _lockDuration
        });
        user.stakes.push(staker);

        IERC20(seraphToken).transferFrom(msg.sender, address(this), _value);

        poolTokenReserve += _value;

        emit LogStake(msg.sender, msg.sender, (user.stakes.length - 1), _value, lockUntil);
    }

    // function sync() external virtual {
    //     _requireNotPaused();
    //     // calls internal function
    //     _sync();
    // }

    function depositERC20(address _token, uint256 _value) external virtual onlyOwner {
        _requireNotPaused();
        require(rewardTokenAllowed, "Not allowed token");

        IERC20(_token).transferFrom(msg.sender, address(this), _value);
    }

    ///FIGURE OUT TIME
    function pendingRewards(address _staker) external view virtual returns (uint256 pendingRewards) {
        User storage user = users[_staker];
        uint256 stakesLength = users[_staker].stakes.length;
        uint256 cumulativeDistribution;

        if (stakesLength > 0) {
            // loops through stakes and calculates pending rewards
            for (uint256 i = 0; i < stakesLength; i++) {
                uint256 pendingDistribution = Stake.getDistribution(user.stakes[i], batchTime);
                cumulativeDistribution += pendingDistribution;
            }
        }
    }

    function claimVaultRewards() external virtual {
        // checks if the contract is in a paused state
        _requireNotPaused();
        // calls internal function
        _claimVaultRewards(msg.sender);
    }

    function unstake(uint256 _stakeId) external virtual {
        _requireNotPaused();
        User storage user = users[msg.sender];
        Stake.Staker storage staker = user.stakes[_stakeId];
        require(block.timestamp > staker.lockedUntil, "Stake is locked");
        IERC20(seraphToken).transfer(msg.sender, staker.staked);
        poolTokenReserve -= staker.staked;

        emit LogUnstakeLocked(msg.sender, _stakeId, staker.staked);
    }

    // function unstakeMultiple(uint256 _stakes) external virtual {
    //     User storage user = users[msg.sender];
    //     Stake.Staker storage staker = user.stakes[_stakeId];

    //     for (uint256 i = 0; i < _stakes.length; i++) {
    //
    // }

    function _claimVaultRewards(address _staker, address _rewardToken) internal virtual {
        User storage user = users[_staker];
        uint256 pendingDistribution = uint256(user.pendingRewards);
        // if pending yield is zero - just return silently
        if (pendingDistribution == 0) return;
        // clears user pending revenue distribution
        user.pendingRewards = 0;

        IERC20(_rewardToken).transfer(_staker, pendingDistribution);

        // emits an event
        emit LogClaimVaultRewards(msg.sender, _staker, pendingDistribution);
    }

    function addRewardToken(address _rewardToken) external onlyOwner {
        rewardTokenAllowed[_rewardToken] = true;
    }
}
