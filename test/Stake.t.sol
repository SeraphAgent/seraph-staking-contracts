// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import { SeraphPool } from "../src/SeraphPool.sol";
import { Test, console } from "forge-std/Test.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

contract SeraphPoolTest is StdCheats, Test {
    SeraphPool pool;

    function setUp() public {
        pool = new SeraphPool();
    }

    function testStake() public { }
}
