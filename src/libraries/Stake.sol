// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

library Stake {
    // error InvalidLockMonths(uint256 lockMonths);

    struct Staker {
        uint256 staked;
        uint256 lockedFrom;
        uint256 lockedUntil;
        uint256 lockMonths; // 1 to 12
    }

    ///FIGURE OUT TIME
    struct Batch {
        uint256 timestamp;
        uint256 totalStaked;
        uint256 totalRewards;
    }

    uint256 internal constant MIN_LOCK_MONTHS = 1;
    uint256 internal constant MAX_LOCK_MONTHS = 12;
    uint256 internal constant MIN_WEIGHT = 100; // 100%
    uint256 internal constant MAX_WEIGHT = 200; // 200%

    function stakerLockedWeight(uint256 lockMonths) internal pure returns (uint256) {
        // if (lockMonths < MIN_LOCK_MONTHS || lockMonths > MAX_LOCK_MONTHS) {
        //     revert InvalidLockMonths(lockMonths);
        // }
        //check steps division precision
        uint256 stakeWeight =
            MIN_WEIGHT + (lockMonths - 1) * (MAX_WEIGHT - MIN_WEIGHT) / (MAX_LOCK_MONTHS - MIN_LOCK_MONTHS);
        assert(stakeWeight > 0);
        return stakeWeight;
    }

    function getDistribution(Staker memory staker) internal view returns (uint256) {
        // if (staker.lockMonths < MIN_LOCK_MONTHS || staker.lockMonths > MAX_LOCK_MONTHS) {
        //     revert InvalidLockMonths(staker.lockMonths);
        // }
        uint256 weightMultiplier = stakerLockedWeight(staker.lockMonths);
        uint256 currentTime = block.timestamp;
        // need to restake or getting 0?
        uint256 lockDurationLeft = staker.lockedUntil > currentTime ? staker.lockedUntil - currentTime : 0;
        uint256 totalLockDuration = staker.lockedUntil - staker.lockedFrom;
        // test values
        uint256 lockProgressDivisor = MIN_WEIGHT - (lockDurationLeft / totalLockDuration) * MIN_WEIGHT;
        uint256 distribution = staker.staked * weightMultiplier * lockProgressDivisor / MIN_WEIGHT / MIN_WEIGHT;
        return distribution;
    }
}
