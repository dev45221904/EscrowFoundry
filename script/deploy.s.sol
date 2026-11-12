// SPDX-License-Identifier: MIT
pragma solidity ^0.8.35;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {Escrow} from "../src/Escrow.sol";

contract DeployEscrow is Script {
    address constant TOKEN = 0xb8b401e1C72423Ff4050cb4044cA70f894Fb646F; // RED token
    uint256 constant AMOUNT = 100e18;

    function run() external returns (Escrow escrow) {
        address buyer = vm.envAddress("BUYER_ADDRESS");

        vm.startBroadcast();
        escrow = new Escrow(buyer, TOKEN, AMOUNT);
        vm.stopBroadcast();

        console.log("Escrow deployed at:", address(escrow));
    }
}