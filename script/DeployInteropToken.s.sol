// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {InteropToken} from "../src/InteropToken.sol";
import {console} from "forge-std/console.sol";

contract DeployInteropToken is Script {
    function run() external {
        // Start broadcasting with the private key automatically from --private-key flag
        vm.startBroadcast();

        // Deploy the contract
        InteropToken token = new InteropToken(
            msg.sender, // Initial owner
            "InteropToken", // Token Name
            "ITP", // Token Symbol
            10000 // Initial supply (1 million tokens)
        );

        // Stop broadcasting
        vm.stopBroadcast();

        // Log the deployed contract address
        console.log("InteropToken deployed at:", address(token));
    }
}
