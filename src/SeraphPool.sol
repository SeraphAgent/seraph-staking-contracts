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
    error SeraphPool__InvalidStakeId();

    //////////////////////////////
    //////State variables////////
    //////////////////////////////

    /**
     * @dev The token used for staking.
     */
    IERC20 public immutable stakingToken;

    /**
     * @dev List of allowed reward tokens.
     */
    address[] public allowedRewardTokens;

    /**
     * @dev Mapping of reward tokens to their total supplies.
     */
    mapping(address => uint256) public rewardTotalSupply;

    /**
     * @dev Struct for tracking individual stakes.
     */
    struct Stake {
        uint256 amount;
        uint256 lockEndTime;
        uint256 lockMultiplier;
    }

    /**
     * @dev Mapping of user addresses to their stakes.
     */
    mapping(address => Stake[]) public stakes;

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

    event Staked(address indexed _user, uint256 _amount, uint256 _lockPeriod, uint256 _stakeId);
    event Unstaked(address indexed _user, uint256 _amount, uint256 _stakeId);
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
     * @dev Stakes tokens in the pool and sets a lock period.
     * Each stake is treated as an independent entry.
     * @param _amount The amount of tokens to stake.
     * @param _lockPeriod The lock period in seconds.
     */
    function stake(uint256 _amount, uint256 _lockPeriod) external nonReentrant whenNotPaused {
        if (_lockPeriod < 1 weeks) revert SeraphPool__MinimumLockPeriod();
        if (_lockPeriod > 52 weeks) revert SeraphPool__MaximumLockPeriod();
        if (totalSupply + _amount > stakingCap) revert SeraphPool__StakingCapExceeded();

        uint256 lockEndTime = block.timestamp + _lockPeriod;
        uint256 multiplier = MULTIPLIER + ((MAX_MULTIPLIER - MULTIPLIER) * _lockPeriod) / (52 weeks);

        // Add the new stake entry
        stakes[msg.sender].push(Stake({ amount: _amount, lockEndTime: lockEndTime, lockMultiplier: multiplier }));

        totalSupply += _amount;

        stakingToken.transferFrom(msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount, _lockPeriod, stakes[msg.sender].length - 1);
    }

    /**
     * @dev Unstakes tokens after the lock period for a specific stake ID.
     * @param _stakeId The ID of the stake to unstake.
     */
    function unstake(uint256 _stakeId) external nonReentrant {
        if (_stakeId >= stakes[msg.sender].length) revert SeraphPool__InvalidStakeId();
        Stake storage userStake = stakes[msg.sender][_stakeId];
        if (block.timestamp < userStake.lockEndTime) revert SeraphPool__LockPeriodNotOver();

        uint256 amount = userStake.amount;

        // Clear the stake
        userStake.amount = 0;

        totalSupply -= amount;

        stakingToken.transfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount, _stakeId);
    }

    /**
     * @dev Claims rewards for the caller across all reward tokens.
     * Rewards are calculated based on the user's stakes and the global reward index.
     * Emits the RewardClaimed event for each reward token.
     */
    function claim() external nonReentrant whenNotPaused {
        // Update the user's rewards for all reward tokens
        _updateRewards(msg.sender);

        for (uint256 i = 0; i < allowedRewardTokens.length; i++) {
            address rewardToken = allowedRewardTokens[i];
            uint256 reward = earned[msg.sender][rewardToken];

            if (reward > 0) {
                // Reset the earned rewards for the token
                earned[msg.sender][rewardToken] = 0;

                // Ensure sufficient balance exists for distribution
                if (IERC20(rewardToken).balanceOf(address(this)) < reward) {
                    revert SeraphPool__RewardTokenNotFound();
                }

                // Transfer the reward to the user
                IERC20(rewardToken).transfer(msg.sender, reward);

                emit RewardClaimed(msg.sender, rewardToken, reward);
            }
        }
    }

    //////////////////////////////
    //////Private functions///////
    //////////////////////////////

    /**
     * @dev Checks if a reward token is allowed.
     * @param _rewardToken The address of the reward token.
     * @return True if the reward token is allowed, false otherwise.
     */
    function _isRewardTokenAllowed(address _rewardToken) private view returns (bool) {
        for (uint256 i = 0; i < allowedRewardTokens.length; i++) {
            if (allowedRewardTokens[i] == _rewardToken) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Calculates the rewards for a given account and reward token.
     * @param _account The address of the account to calculate rewards for.
     * @param _rewardToken The address of the reward token.
     * @return The calculated reward amount.
     */
    function _calculateRewards(address _account, address _rewardToken) private view returns (uint256) {
        uint256 rewards = 0;
        Stake[] memory userStakes = stakes[_account];

        for (uint256 i = 0; i < userStakes.length; i++) {
            Stake memory _stake = userStakes[i];
            uint256 stakeReward = (
                _stake.amount * (rewardIndex[_rewardToken] - rewardIndexOf[_account][_rewardToken])
                    * _stake.lockMultiplier
            ) / (MULTIPLIER * MULTIPLIER);
            rewards += stakeReward;
        }

        return rewards;
    }

    /**
     * @dev Updates the rewards for a given account across all stakes.
     * @param _account The address of the account to update rewards for.
     */
    function _updateRewards(address _account) private {
        for (uint256 i = 0; i < allowedRewardTokens.length; i++) {
            address token = allowedRewardTokens[i];
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

    //////////////////////////////
    //////External functions//////
    //////////////////////////////

    /**
     * @dev Updates the reward index for a reward token.
     * @param _rewardToken The address of the reward token.
     * @param _rewardAmount The amount of the reward tokens to distribute.
     */
    function updateRewardIndex(address _rewardToken, uint256 _rewardAmount) external onlyOwner {
        if (!_isRewardTokenAllowed(_rewardToken)) revert SeraphPool__RewardTokenNotAllowed();
        if (totalSupply == 0) revert SeraphPool__NoStakedTokens();

        rewardTotalSupply[_rewardToken] += _rewardAmount;
        IERC20(_rewardToken).transferFrom(msg.sender, address(this), _rewardAmount);
        rewardIndex[_rewardToken] += (_rewardAmount * MULTIPLIER) / totalSupply;

        emit RewardIndexUpdated(_rewardToken, _rewardAmount);
    }

    /**
     * @dev Adds a reward token to the allowed list.
     * @param _rewardToken The reward token address.
     */
    function addRewardToken(address _rewardToken) external onlyOwner {
        if (_isRewardTokenAllowed(_rewardToken)) revert SeraphPool__RewardTokenNotAllowed();

        allowedRewardTokens.push(_rewardToken);
        emit RewardTokenAdded(_rewardToken);
    }

    /**
     * @dev Removes a reward token from the allowed list.
     * @param _rewardToken The reward token address.
     */
    function removeRewardToken(address _rewardToken) external onlyOwner {
        bool found = false;
        for (uint256 i = 0; i < allowedRewardTokens.length; i++) {
            if (allowedRewardTokens[i] == _rewardToken) {
                allowedRewardTokens[i] = allowedRewardTokens[allowedRewardTokens.length - 1];
                allowedRewardTokens.pop();
                found = true;
                break;
            }
        }
        if (!found) revert SeraphPool__RewardTokenNotFound();

        emit RewardTokenRemoved(_rewardToken);
    }

    /**
     * @dev Updates the staking cap.
     * @param _newCap The new staking cap.
     */
    function updateStakingCap(uint256 _newCap) external onlyOwner {
        stakingCap = _newCap;
        emit StakingCapUpdated(_newCap);
    }

    /**
     * @dev Allows the owner to recover ERC20 tokens mistakenly sent to the contract.
     * @param _token The address of the ERC20 token to recover.
     * @param _amount The amount of tokens to recover.
     */
    function recoverERC20(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(msg.sender, _amount);
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pause() external whenNotPaused onlyOwner {
        super._pause();
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() external whenPaused onlyOwner {
        super._unpause();
    }
}
