// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {TokenProxy} from "../src/proxy/TokenProxy.sol";
import {ImplementationAuthority} from "../src/proxy/ImplementationAuthority.sol";
import {InteropToken} from "../src/InteropToken.sol";
import {console} from "forge-std/console.sol";

contract DeployInteropToken is Script {
    function run() external {
        // Start broadcasting with the private key automatically from --private-key flag
        vm.startBroadcast();
        
        // Deploy the contract
        InteropToken logic = new InteropToken();

        ImplementationAuthority implementationAuthority = new ImplementationAuthority(address(logic));

        InteropToken token = InteropToken(address(new TokenProxy(address(implementationAuthority),address(this),"InteropToken", "IPT", 18)));
        
        // Stop broadcasting
        vm.stopBroadcast();

        // Log the deployed contract address
        console.log("InteropToken deployed at:", address(token));
    }
}
