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

pragma solidity ^0.8.26;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

contract SeraphPool is Ownable, ReentrancyGuard, Pausable {
    using SafeCast for *;

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    constructor(address _stakingToken, address _rewardToken) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public lockEndTime;
    mapping(address => uint256) public lockMultiplier;
    uint256 public totalSupply;

    uint256 private constant MULTIPLIER = 1e18;
    uint256 private rewardIndex;
    mapping(address => uint256) private rewardIndexOf;
    mapping(address => uint256) private earned;

    uint256 public constant MAX_MULTIPLIER = 3 * MULTIPLIER; // Maximum 3x rewards for the longest lock

    function updateRewardIndex(uint256 _reward, address _token) external onlyOwner {
        _requireNotPaused();
        require(totalSupply > 0, "No staked tokens");
        IERC20(_token).transferFrom(msg.sender, address(this), _reward);
        rewardIndex += (_reward * MULTIPLIER) / totalSupply;
    }

    function _calculateRewards(address account) private view returns (uint256) {
        uint256 shares = balanceOf[account];
        uint256 multiplier = lockMultiplier[account];
        return (shares * (rewardIndex - rewardIndexOf[account]) * multiplier) / (MULTIPLIER * MULTIPLIER);
    }

    function calculateRewardsEarned(address account) external view returns (uint256) {
        return earned[account] + _calculateRewards(account);
    }

    function _updateRewards(address account) private {
        earned[account] += _calculateRewards(account);
        rewardIndexOf[account] = rewardIndex;
    }

    function stake(uint256 amount, uint256 lockPeriod) external {
        _requireNotPaused();
        require(lockPeriod >= 1 weeks, "Minimum lock period is 1 week");
        require(lockPeriod <= 52 weeks, "Maximum lock period is 52 weeks");

        _updateRewards(msg.sender);

        uint256 multiplier = MULTIPLIER + ((MAX_MULTIPLIER - MULTIPLIER) * lockPeriod) / (52 weeks);
        lockMultiplier[msg.sender] = multiplier;
        lockEndTime[msg.sender] = block.timestamp + lockPeriod;

        balanceOf[msg.sender] += amount;
        totalSupply += amount;

        stakingToken.transferFrom(msg.sender, address(this), amount);
    }

    function unstake(uint256 amount) external {
        require(block.timestamp >= lockEndTime[msg.sender], "Lock period not over");

        _updateRewards(msg.sender);

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;

        stakingToken.transfer(msg.sender, amount);
    }

    function claim() external returns (uint256) {
        _updateRewards(msg.sender);

        uint256 reward = earned[msg.sender];
        if (reward > 0) {
            earned[msg.sender] = 0;
            rewardToken.transfer(msg.sender, reward);
        }

        return reward;
    }

    function pause(bool _shouldPause) external onlyOwner {
        if (_shouldPause) {
            super._pause();
        } else {
            super._unpause();
        }
    }
}
