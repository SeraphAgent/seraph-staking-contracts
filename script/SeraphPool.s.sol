// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Script, console } from "forge-std/Script.sol";
import { SeraphPool } from "../src/SeraphPool.sol";

contract SeraphPoolScript is Script {
    function setUp() public { }

    function run() public returns (SeraphPool) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        SeraphPool pool = new SeraphPool(0x4f81837C2f4A189A0B69370027cc2627d93785B4, 0);
        vm.stopBroadcast();
        return pool;
    }
}
