# SeraphPool Frontend Integration Guide

## Overview

The `SeraphPool` contract facilitates staking of ERC-20 tokens, reward distribution, and controlled withdrawals based on lock periods. This document provides details for integrating the smart contract into a frontend application.

## Contract Information

**Contract Address (Base Chain):** `0xd4F3aa15cFC819846Fc7a001c240eb9ea00f0108`
**Contract Address stTAO (Base Chain):** `0x4f81837C2f4A189A0B69370027cc2627d93785B4`
**Contract Address SERAPH (Base Chain):** `0x806041b6473da60abbe1b256d9a2749a151be6c6`

## Important Considerations

- **StakingCap & minLockTime:** 5% SERAPH & 2 weeks
- **Approval Required:** Users must approve the contract to spend tokens before staking.
- **Lock Period:** Tokens can only be unstaked after the lock period expires.
- **Sufficient Rewards:** The contract must have sufficient rewards before claims can be processed.

## Function Guide & Integration

### 1. Staking Tokens

#### `stake(uint256 _amount)`

**Description:**
Users can stake ERC-20 tokens in the pool.

**Inputs:**

- `_amount` (`uint256`): Amount of tokens to stake.

**Outputs:**

- Emits `Staked` event: `(address user, uint256 amount, uint256 lockPeriod)`

**Integration Steps:**

1. Approve the contract to spend `_amount` tokens.
2. Call `stake(_amount)`.
3. Listen for the `Staked` event.

---

### 2. Unstaking Tokens

#### `unstake(uint256 _amount)`

**Description:**
Allows users to withdraw their staked tokens after the lock period has ended.

**Inputs:**

- `_amount` (`uint256`): Amount of tokens to unstake.

**Outputs:**

- Emits `Unstaked` event: `(address user, uint256 amount)`

**Integration Steps:**

1. Verify the lock period has expired.
2. Call `unstake(_amount)`.
3. Listen for the `Unstaked` event.

---

### 3. Claiming Rewards

#### `claim()`

**Description:**
Users can claim earned rewards based on their stake duration.

**Inputs:**

- None

**Outputs:**

- Transfers earned rewards to the user.
- Emits `RewardClaimed` event: `(address user, address rewardToken, uint256 rewardAmount)`

**Integration Steps:**

1. Display pending rewards (`calculateRewardsEarned`).
2. Call `claim()`.
3. Listen for `RewardClaimed` events.

---

### 4. Checking Earned Rewards

#### `calculateRewardsEarned(address _account, address _rewardToken) → uint256`

**Description:**
Returns the amount of rewards a user has earned.

**Inputs:**

- `_account` (`address`): User's wallet address.
- `_rewardToken` (`address`): Address of the reward token.

**Outputs:**

- `uint256`: Amount of earned rewards.

**Integration Steps:**

1. Call `calculateRewardsEarned(userAddress, rewardTokenAddress)`.
2. Display the reward balance.

---

## Admin Functions (Owner Only)

### Updating Reward Index

#### `updateRewardIndex(address _rewardToken, uint256 _rewardAmount)`

**Description:**
Allows the owner to update the reward index to distribute new rewards.

**Inputs:**

- `_rewardToken` (`address`): Token used for rewards.
- `_rewardAmount` (`uint256`): Amount of tokens allocated for rewards.

---

### Managing Reward Tokens

#### `addRewardToken(address _rewardToken)`

**Description:**
Adds a new reward token.

**Inputs:**

- `_rewardToken` (`address`): ERC-20 token.

#### `removeRewardToken(address _rewardToken)`

**Description:**
Removes an existing reward token.

**Inputs:**

- `_rewardToken` (`address`): ERC-20 token.

---

### Managing Staking Cap

#### `updateStakingCap(uint256 _newCap)`

**Description:**
Updates the staking cap for the pool.

**Inputs:**

- `_newCap` (`uint256`): New staking cap.

---

### Contract Pause/Unpause

#### `pause()` / `unpause()`

**Description:**
Allows the owner to pause or resume staking activities.
