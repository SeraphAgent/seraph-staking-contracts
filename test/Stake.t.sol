// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import { SeraphPool } from "../src/SeraphPool.sol";
import { Test, console } from "forge-std/Test.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

contract SeraphPoolTest is StdCheats, Test {
    SeraphPool pool;

    function setUp() public {
        pool =
            new SeraphPool(0x4f81837C2f4A189A0B69370027cc2627d93785B4, 0x806041B6473DA60abbe1b256d9A2749A151be6C6, 100);
    }

    function testStake() public { }
}
