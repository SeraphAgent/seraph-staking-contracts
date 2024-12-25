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
// receive function
// fallback function
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.26;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SeraphPool
 * @dev A staking and reward distribution contract with time-based multipliers for stakers.
 */
contract SeraphPool is Ownable, ReentrancyGuard, Pausable {
    using SafeCast for *;

    //////////////////////////////
    //////Errors//////////////////
    //////////////////////////////

    error SeraphPool__NoStakedTokens();
    error SeraphPool__MinimumLockPeriod();
    error SeraphPool__MaximumLockPeriod();
    error SeraphPool__LockPeriodNotOver();
    error SeraphPool__StakingCapExceeded();
    error SeraphPool__RewardTokenNotFound();
    error SeraphPool__EtherNotAccepted();
    error SeraphPool__TokensNotAccepted();
    error SeraphPool__RewardTokenNotAllowed();

    //////////////////////////////
    //////State variables////////
    //////////////////////////////

    /**
     * @dev The token used for staking.
     */
    IERC20 public immutable stakingToken;

    /**
     * @dev Mapping of reward tokens to their total supplies.
     */
    mapping(address => uint256) public rewardTotalSupply;

    /**
     * @dev Mapping of allowed reward tokens.
     */
    mapping(address => bool) public allowedRewardTokens;

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
     * @dev The global reward index for each reward token.
     */
    mapping(address => uint256) private rewardIndex;

    /**
     * @dev Mapping of user addresses and reward tokens to their last known reward index.
     */
    mapping(address => mapping(address => uint256)) private rewardIndexOf;

    /**
     * @dev Mapping of user addresses and reward tokens to their earned rewards.
     */
    mapping(address => mapping(address => uint256)) private earned;

    /**
     * @dev The maximum multiplier for long lock periods.
     */
    uint256 public constant MAX_MULTIPLIER = 3 * MULTIPLIER; // Maximum 3x rewards for the longest lock

    /**
     * @dev Maximum staking cap for the pool.
     */
    uint256 public stakingCap;

    //////////////////////////////
    ///////Events/////////////////
    //////////////////////////////

    event Staked(address indexed _user, uint256 _amount, uint256 _lockPeriod);
    event Unstaked(address indexed _user, uint256 _amount);
    event RewardClaimed(address indexed _user, address _rewardToken, uint256 _reward);
    event RewardIndexUpdated(address indexed _rewardToken, uint256 _rewardAmount);
    event PausedStateChanged(bool indexed _isPaused);
    event StakingCapUpdated(uint256 indexed _newCap);
    event RewardTokenAdded(address indexed _rewardToken);
    event RewardTokenRemoved(address indexed _rewardToken);

    //////////////////////////////
    ///////Constructor///////////
    //////////////////////////////

    /**
     * @dev Initializes the contract with staking token and initial staking cap.
     * @param _stakingToken Address of the staking token contract.
     * @param _initialCap Initial staking cap.
     */
    constructor(address _stakingToken, uint256 _initialCap) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        stakingCap = _initialCap;
    }

    //////////////////////////////
    //////Receive function////////
    //////////////////////////////

    /**
     * @dev Prevents accidental Ether transfers to the contract.
     */
    receive() external payable {
        revert SeraphPool__EtherNotAccepted();
    }

    //////////////////////////////
    //////Fallback function///////
    //////////////////////////////

    /**
     * @dev Prevents accidental token transfers to the contract.
     */
    fallback() external payable {
        revert SeraphPool__TokensNotAccepted();
    }

    //////////////////////////////
    //////External functions//////
    //////////////////////////////

    /**
     * @dev Updates the reward index by adding new rewards to the pool for a specific token.
     * @param _rewardToken The address of the reward token.
     * @param _rewardAmount The amount of reward tokens to add.
     */
    function updateRewardIndex(address _rewardToken, uint256 _rewardAmount) external {
        _requireNotPaused();
        if (!allowedRewardTokens[_rewardToken]) revert SeraphPool__RewardTokenNotAllowed();
        if (totalSupply == 0) revert SeraphPool__NoStakedTokens();
        rewardTotalSupply[_rewardToken] += _rewardAmount;
        IERC20(_rewardToken).transferFrom(msg.sender, address(this), _rewardAmount);
        rewardIndex[_rewardToken] += (_rewardAmount * MULTIPLIER) / totalSupply;
        emit RewardIndexUpdated(_rewardToken, _rewardAmount);
    }

    /**
     * @dev Adds a new reward token to the allowed list.
     * @param _rewardToken The address of the reward token to allow.
     */
    function addRewardToken(address _rewardToken) external onlyOwner {
        allowedRewardTokens[_rewardToken] = true;
        emit RewardTokenAdded(_rewardToken);
    }

    /**
     * @dev Removes a reward token from the allowed list.
     * @param _rewardToken The address of the reward token to disallow.
     */
    function removeRewardToken(address _rewardToken) external onlyOwner {
        allowedRewardTokens[_rewardToken] = false;
        emit RewardTokenRemoved(_rewardToken);
    }

    /**
     * @dev Updates the staking cap.
     * @param _newCap The new maximum staking cap.
     */
    function updateStakingCap(uint256 _newCap) external onlyOwner {
        stakingCap = _newCap;
        emit StakingCapUpdated(_newCap);
    }

    /**
     * @dev Stakes tokens in the pool and sets a lock period.
     * @param _amount The amount of tokens to stake.
     * @param _lockPeriod The lock period in seconds.
     */
    function stake(uint256 _amount, uint256 _lockPeriod) external {
        _requireNotPaused();
        if (_lockPeriod < 1 weeks) revert SeraphPool__MinimumLockPeriod();
        if (_lockPeriod > 52 weeks) revert SeraphPool__MaximumLockPeriod();
        if (totalSupply + _amount > stakingCap) revert SeraphPool__StakingCapExceeded();

        _updateRewards(msg.sender);

        uint256 multiplier = MULTIPLIER + ((MAX_MULTIPLIER - MULTIPLIER) * _lockPeriod) / (52 weeks);
        lockMultiplier[msg.sender] = multiplier;
        lockEndTime[msg.sender] = block.timestamp + _lockPeriod;

        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;

        stakingToken.transferFrom(msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount, _lockPeriod);
    }

    /**
     * @dev Unstakes tokens after the lock period has ended.
     * @param _amount The amount of tokens to unstake.
     */
    function unstake(uint256 _amount) external {
        if (block.timestamp < lockEndTime[msg.sender]) revert SeraphPool__LockPeriodNotOver();

        _updateRewards(msg.sender);

        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;

        stakingToken.transfer(msg.sender, _amount);
        emit Unstaked(msg.sender, _amount);
    }

    /**
     * @dev Claims earned rewards for the caller for a specific reward token.
     * @param _rewardToken The address of the reward token to claim.
     * @return The amount of rewards claimed.
     */
    function claim(address _rewardToken) external returns (uint256) {
        if (rewardIndex[_rewardToken] == 0) revert SeraphPool__RewardTokenNotFound();

        _updateRewards(msg.sender);

        uint256 _reward = earned[msg.sender][_rewardToken];
        if (_reward > 0) {
            earned[msg.sender][_rewardToken] = 0;
            IERC20(_rewardToken).transfer(msg.sender, _reward);
            emit RewardClaimed(msg.sender, _rewardToken, _reward);
        }

        return _reward;
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
        emit PausedStateChanged(_shouldPause);
    }

    //////////////////////////////
    //////Private functions///////
    //////////////////////////////

    /**
     * @dev Calculates the rewards for a given account and reward token.
     * @param _account The address of the account to calculate rewards for.
     * @param _rewardToken The address of the reward token.
     * @return The calculated reward amount.
     */
    function _calculateRewards(address _account, address _rewardToken) private view returns (uint256) {
        uint256 _shares = balanceOf[_account];
        uint256 _multiplier = lockMultiplier[_account];
        return (_shares * (rewardIndex[_rewardToken] - rewardIndexOf[_account][_rewardToken]) * _multiplier)
            / (MULTIPLIER * MULTIPLIER);
    }

    /**
     * @dev Updates the rewards for a given account.
     * @param _account The address of the account to update rewards for.
     */
    function _updateRewards(address _account) private {
        for (address token = address(0); token != address(0); token = address(uint160(uint256(token) + 1))) {
            if (rewardIndex[token] > 0) {
                earned[_account][token] += _calculateRewards(_account, token);
                rewardIndexOf[_account][token] = rewardIndex[token];
            }
        }
    }

    //////////////////////////////
    //////View functions//////////
    //////////////////////////////

    /**
     * @dev Returns the rewards earned by a given account for a specific reward token.
     * @param _account The address of the account to check rewards for.
     * @param _rewardToken The address of the reward token.
     * @return The total rewards earned by the account.
     */
    function calculateRewardsEarned(address _account, address _rewardToken) external view returns (uint256) {
        return earned[_account][_rewardToken] + _calculateRewards(_account, _rewardToken);
    }
}
