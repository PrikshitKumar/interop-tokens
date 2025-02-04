// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {InteropToken} from "../src/InteropToken.sol";

import {TokenStorage} from "../src/TokenStorage.sol";

import {TokenProxy} from "../src/proxy/TokenProxy.sol";
import {ImplementationAuthority} from "../src/proxy/ImplementationAuthority.sol";

import {OnchainCrossChainOrder, ResolvedCrossChainOrder, Output, FillInstruction, IOriginSettler} from "../src/interface/IERC7683.sol";

contract ProxyInteropTokenTest is Test {
    InteropToken public interopToken;
    TokenProxy public deployedProxy;
    InteropToken public tokenProxy;
    ImplementationAuthority public implementationAuthority;

    address public owner;
    address public user1;
    address public user2;

    bytes32 constant ORDER_DATA_TYPE_HASH =
        keccak256(
            "Order(address,uint256,uint64,address,uint256)"
        );

    // Setup the Users
    function setUp() public {
        // Fetch default test accounts provided by Foundry
        owner = address(this); // The contract address is the owner by default
        user1 = vm.addr(1); // Fetch address 1 (used as a test account)
        user2 = vm.addr(2); // Fetch address 2 (another test account)

        // Log the addresses to console
        console.log("Owner Address: ", owner);
        console.log("User1 Address: ", user1);
        console.log("User2 Address: ", user2);

        // Deploy the contract
        interopToken = new InteropToken();
        implementationAuthority = new ImplementationAuthority(address(interopToken));
        deployedProxy = new TokenProxy(address(implementationAuthority),"InteropToken", "IPT", 18);
        console.log("setup complete\n token proxy at:", address(tokenProxy));
        console.log("implementation at:", address(interopToken));
        console.log("implementation authority at", address(implementationAuthority));

        // forcing the abi of interop token on the token proxy for proxy interactions
        tokenProxy = InteropToken(address(deployedProxy));
    }

    // Test: Ensure that the proxy delegates correctly to the logic contract
    function testInitialDeployment() public {
        // Should use logic contract (interopToken) via proxy
        string memory tokenName = tokenProxy.name();
        assertEq(tokenName, "InteropToken");  

        string memory tokenSymbol = tokenProxy.symbol();
        assertEq(tokenSymbol, "IPT");         
        
        uint8  tokenDecimals = tokenProxy.decimals();
        assertEq(tokenDecimals, 18);          
        
        address  tokenOwner = tokenProxy.owner();
        assertEq(tokenOwner,address(this)); // deployer of proxy is the owner of the token contract  
    }

    function testMint() public {
        // Mint tokens by the owner
        vm.startPrank(owner);

        // Record logs emitted during the execution
        vm.recordLogs();

        // Call the function that emits the event
        tokenProxy.mint(address(owner), 10000);

        // Stop recording logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Assert that owner's balance increased by the minted amount
        console.log("Owner Balance: ", tokenProxy.balanceOf(owner));
        assertEq(
            tokenProxy.balanceOf(owner),
            10000,
            "Owner Balance mismatched"
        );
    }    
}
