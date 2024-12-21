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

/**
 * @title SeraphPool
 * @dev A staking and reward distribution contract with time-based multipliers for stakers.
 */
contract SeraphPool is Ownable, ReentrancyGuard, Pausable {
    using SafeCast for *;

    //////////////////////////////
    //////State variables////////
    //////////////////////////////

    /**
     * @dev The token used for staking.
     */
    IERC20 public immutable stakingToken;

    /**
     * @dev The token used for distributing rewards.
     */
    IERC20 public immutable rewardToken;

    /**
     * @dev Mapping of user addresses to their staked balances.
     */
    mapping(address => uint256) public balanceOf;

    /**
     * @dev Mapping of user addresses to their lock end times.
     */
    mapping(address => uint256) public lockEndTime;

    /**
     * @dev Mapping of user addresses to their lock multipliers.
     */
    mapping(address => uint256) public lockMultiplier;

    /**
     * @dev The total amount of tokens staked in the pool.
     */
    uint256 public totalSupply;

    /**
     * @dev The constant multiplier used for reward calculations.
     */
    uint256 private constant MULTIPLIER = 1e18;

    /**
     * @dev The global reward index for the pool.
     */
    uint256 private rewardIndex;

    /**
     * @dev Mapping of user addresses to their last known reward index.
     */
    mapping(address => uint256) private rewardIndexOf;

    /**
     * @dev Mapping of user addresses to their earned rewards.
     */
    mapping(address => uint256) private earned;

    /**
     * @dev The maximum multiplier for long lock periods.
     */
    uint256 public constant MAX_MULTIPLIER = 3 * MULTIPLIER; // Maximum 3x rewards for the longest lock

    //////////////////////////////
    ///////Constructor///////////
    //////////////////////////////

    /**
     * @dev Initializes the contract with staking and reward tokens.
     * @param _stakingToken Address of the staking token contract.
     * @param _rewardToken Address of the reward token contract.
     */
    constructor(address _stakingToken, address _rewardToken) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    //////////////////////////////
    //////External functions//////
    //////////////////////////////

    /**
     * @dev Updates the reward index by adding new rewards to the pool.
     * @param _reward The amount of reward tokens to add.
     * @param _token The address of the reward token.
     */
    function updateRewardIndex(uint256 _reward, address _token) external onlyOwner {
        _requireNotPaused();
        require(totalSupply > 0, "No staked tokens");
        IERC20(_token).transferFrom(msg.sender, address(this), _reward);
        rewardIndex += (_reward * MULTIPLIER) / totalSupply;
    }

    /**
     * @dev Stakes tokens in the pool and sets a lock period.
     * @param amount The amount of tokens to stake.
     * @param lockPeriod The lock period in seconds.
     */
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

    /**
     * @dev Unstakes tokens after the lock period has ended.
     * @param amount The amount of tokens to unstake.
     */
    function unstake(uint256 amount) external {
        require(block.timestamp >= lockEndTime[msg.sender], "Lock period not over");

        _updateRewards(msg.sender);

        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;

        stakingToken.transfer(msg.sender, amount);
    }

    /**
     * @dev Claims earned rewards for the caller.
     * @return The amount of rewards claimed.
     */
    function claim() external returns (uint256) {
        _updateRewards(msg.sender);

        uint256 reward = earned[msg.sender];
        if (reward > 0) {
            earned[msg.sender] = 0;
            rewardToken.transfer(msg.sender, reward);
        }

        return reward;
    }

    /**
     * @dev Pauses or unpauses the contract.
     * @param _shouldPause A boolean indicating whether to pause or unpause.
     */
    function pause(bool _shouldPause) external onlyOwner {
        if (_shouldPause) {
            super._pause();
        } else {
            super._unpause();
        }
    }

    //////////////////////////////
    //////Internal functions//////
    //////////////////////////////

    /**
     * @dev Updates the rewards for a given account.
     * @param account The address of the account to update rewards for.
     */
    function _updateRewards(address account) private {
        earned[account] += _calculateRewards(account);
        rewardIndexOf[account] = rewardIndex;
    }

    //////////////////////////////
    //////Private functions///////
    //////////////////////////////

    /**
     * @dev Calculates the rewards for a given account.
     * @param account The address of the account to calculate rewards for.
     * @return The calculated reward amount.
     */
    function _calculateRewards(address account) private view returns (uint256) {
        uint256 shares = balanceOf[account];
        uint256 multiplier = lockMultiplier[account];
        return (shares * (rewardIndex - rewardIndexOf[account]) * multiplier) / (MULTIPLIER * MULTIPLIER);
    }

    //////////////////////////////
    //////View functions//////////
    //////////////////////////////

    /**
     * @dev Returns the rewards earned by a given account.
     * @param account The address of the account to check rewards for.
     * @return The total rewards earned by the account.
     */
    function calculateRewardsEarned(address account) external view returns (uint256) {
        return earned[account] + _calculateRewards(account);
    }
}
