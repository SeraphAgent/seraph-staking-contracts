# SeraphPool Frontend Integration Guide

## Overview

The `SeraphPool` contract enables users to stake tokens, earn rewards, and withdraw them based on lock periods. This guide outlines the smart contract's key functions and how to integrate them into a frontend.

## Contract Details on Base

**0xb9262208c2c8f7D16Ea90671f858CBE6bdC179E6**

## ⚠️ Notes

- Ensure ERC-20 approval before staking.
- Users must wait until the lock period expires before unstaking.
- The contract must have sufficient rewards before claiming.

## Functions & Integration

### Staking

#### `stake(uint256 _amount, uint256 _lockPeriod)`

**Description:**  
Allows users to stake ERC-20 tokens for a defined lock period.

**Inputs:**

- `_amount` (uint256): The amount of tokens to stake.
- `_lockPeriod` (uint256): Duration in seconds (must be within min/max range).

**Outputs:**

- Emits `Staked` event: `(address user, uint256 amount, uint256 lockPeriod, uint256 stakeId)`

**Frontend Integration:**

1. Approve the contract to spend `_amount` tokens.
2. Call `stake(_amount, _lockPeriod)`.
3. Listen for `Staked` event.

### Unstaking

#### `unstake(uint256 _stakeId)`

**Description:**  
Allows users to withdraw staked tokens after the lock period.

**Inputs:**

- `_stakeId` (uint256): The index of the stake.

**Outputs:**

- Emits `Unstaked` event: `(address user, uint256 amount, uint256 stakeId)`

**Frontend Integration:**

1. Fetch user's stakes.
2. Check if lock period is over.
3. Call `unstake(_stakeId)`.
4. Listen for `Unstaked` event.

### Claiming Rewards

#### `claim()`

**Description:**  
Users can claim rewards based on staking duration and reward distribution.

**Inputs:**

- None

**Outputs:**

- Transfers reward tokens to user.
- Emits `RewardClaimed` event: `(address user, address rewardToken, uint256 rewardAmount)`

**Frontend Integration:**

1. Display pending rewards (`calculateRewardsEarned`).
2. Call `claim()`.
3. Listen for `RewardClaimed` events.

### Checking Rewards

#### `calculateRewardsEarned(address _account, address _rewardToken) → uint256`

**Description:**  
Returns the user's earned rewards for a specific token.

**Inputs:**

- `_account` (address): User's wallet address.
- `_rewardToken` (address): ERC-20 token address.

**Outputs:**

- Returns `(uint256)`: Amount of rewards earned.

**Frontend Integration:**

1. Call `calculateRewardsEarned(userAddress, rewardTokenAddress)`.
2. Display reward balance.

### Admin Functions (Owner Only)

#### `updateRewardIndex(address _rewardToken, uint256 _rewardAmount)`

**Description:**  
Admin updates the global reward index.

**Inputs:**

- `_rewardToken` (address): Token to distribute.
- `_rewardAmount` (uint256): Amount to distribute.

#### `addRewardToken(address _rewardToken)`

**Description:**  
Adds a new reward token.

**Inputs:**

- `_rewardToken` (address): ERC-20 token.

#### `removeRewardToken(address _rewardToken)`

**Description:**  
Removes a reward token.

**Inputs:**

- `_rewardToken` (address): ERC-20 token.

#### `updateStakingCap(uint256 _newCap)`

**Description:**  
Updates max staking capacity.

**Inputs:**

- `_newCap` (uint256): New staking cap.

#### `pause() / unpause()`

**Description:**  
Pauses or resumes staking.
