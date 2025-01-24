# SeraphPool Frontend Integration Guide

## Overview

The `SeraphPool` contract is a staking and reward distribution system for ERC-20 tokens. It allows users to stake tokens, earn rewards, and withdraw their tokens based on predefined lock periods. This guide provides details on integrating the smart contract into a frontend application.

## Contract Information

- **Contract Address Staking v1 (Base Chain), 7.5% cap:** `0xd4F3aa15cFC819846Fc7a001c240eb9ea00f0108`
- **Contract Address Staking v2 (Base Chain), unlimited staking cap:** `0xD4b47EE9879470179bAC7BECf49d2755ce5a8ea0`
- **Contract Address stTAO (Base Chain):** `0x4f81837C2f4A189A0B69370027cc2627d93785B4`
- **Contract Address SERAPH (Base Chain):** `0x806041b6473da60abbe1b256d9a2749a151be6c6`

## Key Considerations

- **Staking Cap & Minimum Lock Time:** unlimited SERAPH & 2 weeks.
- **Approval Required:** Users must approve the contract to spend tokens before staking.
- **Lock Period:** Tokens can only be unstaked after the lock period expires after any `stake` call (2 weeks).
- **Sufficient Rewards:** The contract must have enough rewards before claims can be processed. Distributed in random times to stakers.

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

#### `claim(address[] calldata _tokenAddresses)`

**Description:**
Claims rewards for the caller across an array of reward tokens. Rewards are calculated based on the user's stakes and the global reward index.

**Inputs:**

- `_tokenAddresses` (`address[]`): Array of reward token addresses.

**Outputs:**

- Transfers earned rewards to the user.
- Emits `RewardClaimed` event for each claimed token: `(address user, address rewardToken, uint256 rewardAmount)`

**Integration Steps:**

1. Ensure the contract is not paused.
2. Call `claim(_tokenAddresses)`.
3. Listen for `RewardClaimed` events for each token in `_tokenAddresses`.

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

---

### Recovering ERC-20 Tokens

#### `recoverERC20(address _token, uint256 _amount)`

**Description:**
Allows the owner to recover mistakenly sent ERC-20 tokens.

**Inputs:**

- `_token` (`address`): Address of the ERC-20 token.
- `_amount` (`uint256`): Amount of tokens to recover.
