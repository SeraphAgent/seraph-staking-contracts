// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { TaoPool } from "../../src/TaoPool.sol";
import { StakedERC20Mock } from "../Mocks/StakedERC20Mock.sol";
import { RewardsERC20Mock } from "../Mocks/RewardsERC20Mock.sol";

// Declare any custom errors used in TaoPool
error TaoPool__NoStakedTokens();
error TaoPool__MinimumLockPeriod();
error TaoPool__MaximumLockPeriod();
error TaoPool__LockPeriodNotOver();
error TaoPool__StakingCapExceeded();
error TaoPool__RewardTokenNotFound();
error TaoPool__EtherNotAccepted();
error TaoPool__TokensNotAccepted();
error TaoPool__RewardTokenNotAllowed();
error TaoPool__InvalidStakeId();
error TaoPool__BalanceMismatch();

contract TaoPoolTest is Test {
    TaoPool public pool;
    StakedERC20Mock public stakedToken;
    RewardsERC20Mock public rewardsToken;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    uint256 public constant INITIAL_BALANCE = 1000e18;
    uint256 public constant STAKE_AMOUNT = 100e18;
    uint256 public constant STAKING_CAP = 1000e18;

    function setUp() public {
        // Deploy mock tokens
        stakedToken = new StakedERC20Mock("Staked Token", "STK", alice, INITIAL_BALANCE);
        rewardsToken = new RewardsERC20Mock("Rewards Token", "REW", address(this), INITIAL_BALANCE, 18);

        // Deploy pool with staking cap
        pool = new TaoPool(address(stakedToken), STAKING_CAP);

        // Mint initial balances
        stakedToken.mint(alice, INITIAL_BALANCE);
        stakedToken.mint(bob, INITIAL_BALANCE);
        rewardsToken.mint(address(pool), INITIAL_BALANCE);

        // Approve pool for alice and bob
        vm.prank(alice);
        stakedToken.approve(address(pool), type(uint256).max);
        vm.prank(bob);
        stakedToken.approve(address(pool), type(uint256).max);
    }

    function testInitialState() public {
        assertEq(pool.getStakedToken(), address(stakedToken));
        assertEq(pool.totalSupply(), 0);
    }

    function testStake() public {
        vm.prank(alice);
        pool.stake(STAKE_AMOUNT, 1 weeks);

        assertEq(pool.getStakeBalance(alice), STAKE_AMOUNT);
        assertEq(pool.totalSupply(), STAKE_AMOUNT);
        assertEq(stakedToken.balanceOf(address(pool)), STAKE_AMOUNT);
    }

    function testStakeZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(TaoPool__NoStakedTokens.selector);
        pool.stake(0, 1 weeks);
    }

    function testMultipleStakes() public {
        vm.prank(alice);
        pool.stake(STAKE_AMOUNT, 1 weeks);

        vm.prank(bob);
        pool.stake(STAKE_AMOUNT, 1 weeks);

        assertEq(pool.getStakeBalance(alice), STAKE_AMOUNT);
        assertEq(pool.getStakeBalance(bob), STAKE_AMOUNT);
        assertEq(pool.totalSupply(), STAKE_AMOUNT * 2);
    }

    // TODO: Add test for claim rewards
    // function testClaimRewards() public {
    //     vm.prank(alice);
    //     pool.stake(STAKE_AMOUNT, 1 weeks);

    //     // Move forward 1 week
    //     vm.warp(block.timestamp + 1 weeks);

    //     // Assume rewards are distributed
    //     pool.updateRewardIndex(address(rewardsToken), 100e18);

    //     vm.prank(alice);
    //     pool.claim();

    //     uint256 rewardsBalance = rewardsToken.balanceOf(alice);
    //     assertGt(rewardsBalance, 0, "Alice should have received rewards");
    // }

    // function testClaimWithoutStaking() public {
    //     vm.prank(alice);
    //     vm.expectRevert(TaoPool__NoStakedTokens.selector);
    //     pool.claim();
    // }

    // Add more tests for reward calculation, etc.
}
