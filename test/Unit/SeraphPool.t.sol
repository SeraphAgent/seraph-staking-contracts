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

    address public staker = makeAddr("staker");
    address public owner = makeAddr("owner");
    address public stakingToken = 0x4f81837C2f4A189A0B69370027cc2627d93785B4;

    function setUp() public {
        deployer = new SeraphPoolScript();
        pool = deployer.run();

        vm.prank(0x4B463ca9D3c53F07DE05a5739A0F6932824E8aB7);
        pool.transferOwnership(owner);

        // stakedToken = new StakedERC20Mock("Stake", "STK", staker, 1_000_000 * 1e18);
        rewardsToken1 = new RewardsERC20Mock("Rewards", "RWD", owner, 1_000_000, 9);
        rewardsToken2 = new RewardsERC20Mock("Rewards", "RWD", owner, 1_000_000, 18);
    }

    function testInitialStateChange() public {
        assertEq(pool.owner(), owner);
        assertEq(address(pool.stakingToken()), 0x4f81837C2f4A189A0B69370027cc2627d93785B4);
        vm.expectRevert();
        pool.allowedRewardTokens(0);
        assertEq(pool.totalSupply(), 0);
        assertEq(pool.stakingCap(), 0);
    }

    function testSetupState() public {
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
}
