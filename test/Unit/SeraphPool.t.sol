// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import { SeraphPool } from "../../src/SeraphPool.sol";
import { Test, console } from "forge-std/Test.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StakedERC20Mock } from "../mocks/StakedERC20Mock.sol";
import { RewardsERC20Mock } from "../mocks/RewardsERC20Mock.sol";
import { SeraphPoolScript } from "../../script/SeraphPool.s.sol";

contract SeraphPoolTest is StdCheats, Test {
    SeraphPool public pool;
    StakedERC20Mock public stakedToken;
    SeraphPoolScript public deployer;
    RewardsERC20Mock public rewardsToken1;
    RewardsERC20Mock public rewardsToken2;

    address public staker1 = makeAddr("staker1");
    address public staker2 = makeAddr("staker2");
    address public owner = makeAddr("owner");
    address public stakingToken = 0x4f81837C2f4A189A0B69370027cc2627d93785B4;

    function setUp() public {
        stakedToken = new StakedERC20Mock("Staked", "STK", owner, 4_000_000 * 1e18);
        vm.prank(owner);
        stakedToken.transfer(staker1, 1e24);
        vm.prank(owner);
        stakedToken.transfer(staker2, 1e24);

        rewardsToken1 = new RewardsERC20Mock("Rewards1", "RWD1", owner, 3_000_000 * 1e9, 9);
        rewardsToken2 = new RewardsERC20Mock("Rewards2", "RWD2", owner, 3_000_000 * 1e18, 18);

        vm.prank(owner);
        rewardsToken1.transfer(staker1, 1e15);
        vm.prank(owner);
        rewardsToken1.transfer(staker2, 1e15);
        vm.prank(owner);
        rewardsToken2.transfer(staker1, 1e24);
        vm.prank(owner);
        rewardsToken2.transfer(staker2, 1e24);

        pool = new SeraphPool(address(stakedToken), 1_000_000 * 1e18);

        vm.prank(address(this));
        pool.transferOwnership(owner);
    }

    function testInitialStateChange() public {
        deployer = new SeraphPoolScript();
        pool = deployer.run();

        vm.prank(0x4B463ca9D3c53F07DE05a5739A0F6932824E8aB7);
        pool.transferOwnership(owner);
        assertEq(pool.owner(), owner);
        assertEq(address(pool.stakingToken()), 0x4f81837C2f4A189A0B69370027cc2627d93785B4);
        vm.expectRevert();
        pool.allowedRewardTokens(0);
        assertEq(pool.totalSupply(), 0);
        assertEq(pool.stakingCap(), 0);
    }

    function testSetupState() public {
        deployer = new SeraphPoolScript();
        pool = deployer.run();
        vm.prank(0x4B463ca9D3c53F07DE05a5739A0F6932824E8aB7);
        pool.transferOwnership(owner);

        vm.expectRevert();
        pool.addRewardToken(address(rewardsToken1));
        vm.expectRevert();
        pool.addRewardToken(address(rewardsToken2));
        vm.expectRevert();
        pool.updateStakingCap(1_000_000 * 1e18);
        vm.prank(owner);
        pool.addRewardToken(address(rewardsToken1));
        vm.prank(owner);
        pool.addRewardToken(address(rewardsToken2));
        vm.prank(owner);
        pool.updateStakingCap(1_000_000 * 1e18);
        assertEq(address(pool.stakingToken()), stakingToken);
        assertEq(pool.stakingCap(), 1_000_000 * 1e18);
    }

    function testStakeOverCap() public {
        vm.prank(owner);
        stakedToken.approve(address(pool), 1_000_000 * 1e18);
        vm.prank(owner);
        pool.stake(1_000_000 * 1e18);
        vm.prank(staker1);
        stakedToken.approve(address(pool), 1_000_000 * 1e18);
        vm.prank(staker1);
        vm.expectRevert();
        pool.stake(1_000_000 * 1e18);
        vm.prank(staker2);
        stakedToken.approve(address(pool), 1_000_000 * 1e18);
        vm.prank(staker2);
        vm.expectRevert();
        pool.stake(1_000_000 * 1e18);
        assertEq(pool.totalSupply(), 1_000_000 * 1e18);
        assertEq(pool.balanceOf(owner), 1_000_000 * 1e18);
    }

    function testStake() public {
        vm.prank(owner);
        pool.updateStakingCap(3 * 1e24);
        vm.prank(owner);
        stakedToken.approve(address(pool), 1_000_000 * 1e18);
        vm.prank(owner);
        pool.stake(1_000_000 * 1e18);
        vm.prank(staker1);
        stakedToken.approve(address(pool), 1_000_000 * 1e18);
        vm.prank(staker1);
        pool.stake(1_000_000 * 1e18);
        vm.prank(staker2);
        stakedToken.approve(address(pool), 1_000_000 * 1e18);
        vm.prank(staker2);
        pool.stake(1_000_000 * 1e18);
        assertEq(pool.totalSupply(), 3e24);
        assertEq(pool.balanceOf(owner), 1e24);
        assertEq(pool.balanceOf(staker1), 1e24);
        assertEq(pool.balanceOf(staker2), 1e24);
    }

    function testClaim() public {
        vm.prank(owner);
        pool.updateStakingCap(3 * 1e24);
        vm.prank(owner);
        pool.addRewardToken(address(rewardsToken2));
        vm.prank(staker1);
        stakedToken.approve(address(pool), 1_000_000 * 1e18);
        vm.prank(staker1);
        pool.stake(1_000_000 * 1e18);
        vm.prank(owner);
        rewardsToken2.approve(address(pool), 1e24);
        vm.prank(owner);
        pool.updateRewardIndex(address(rewardsToken2), 1e24);
        vm.prank(staker2);
        stakedToken.approve(address(pool), 1_000_000 * 1e18);
        vm.prank(staker2);
        pool.stake(1_000_000 * 1e18);
        vm.prank(staker1);
        pool.claim();
        vm.prank(staker2);
        pool.claim();
        assertEq(rewardsToken2.balanceOf(staker1), 2e24);
        assertEq(stakedToken.balanceOf(staker1), 0);
        assertEq(rewardsToken2.balanceOf(staker2), 1e24); //  original
        assertEq(stakedToken.balanceOf(staker2), 0);
        assertEq(rewardsToken2.balanceOf(owner), 0);
        assertEq(stakedToken.balanceOf(owner), 2e24);
    }
}
