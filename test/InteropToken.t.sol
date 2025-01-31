// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {InteropToken} from "../src/InteropToken.sol";

import {TokenStorage} from "../src/TokenStorage.sol";

import {OnchainCrossChainOrder, ResolvedCrossChainOrder, Output, FillInstruction, IOriginSettler} from "../src/interface/IERC7683.sol";

contract InteropTokenTest is Test {
    InteropToken public interopToken;

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
        interopToken.init("InteropToken", "IPT", 18, 10000);

    }

    // Test that owner can transfer tokens successfully
    function testOpenOrder() public {
        // Assert that user2's balance increased by the transfer amount
        console.log("Owner Balance: ", interopToken.balanceOf(owner));
        assertEq(
            interopToken.balanceOf(owner),
            10000,
            "Initial Owner Balance mismatched"
        );

        uint64 destinationChainId = 1234; // Replace with actual ChainId
        OnchainCrossChainOrder memory order = OnchainCrossChainOrder({
            fillDeadline: 1769494252, // Example timestamp: 2026-01-27
            orderDataType: ORDER_DATA_TYPE_HASH,
            orderData: abi.encode(
                TokenStorage.OrderData({
                    to: user2,
                    amount: 100,
                    destinationChainId: destinationChainId,
                    feeToken: address(0),
                    feeValue: 0
                })
            )
        });

        // Log each part of the order
        InteropToken.OrderData memory orderData = abi.decode(
            order.orderData,
            (TokenStorage.OrderData)
        );
        console.log("fillDeadline: ", order.fillDeadline);
        console.log("OrderType: ");
        console.logBytes32(order.orderDataType);
        console.log("to: ", orderData.to);
        console.log("amount: ", orderData.amount);
        console.log("destinationChainId: ", orderData.destinationChainId);

        // User with whom the transaction is executed
        vm.startPrank(owner);

        // Record logs emitted during the execution
        vm.recordLogs();

        // Call the function that emits the event
        // Call the `open` function
        interopToken.open(order);
        console.log("Open executed");

        // Stop recording logs
        Vm.Log[] memory logs = vm.getRecordedLogs();
        FillInstruction[] memory fillInstructions;
        bytes32 orderId;

        // Search for the emitted Open event
        for (uint256 i = 0; i < logs.length; i++) {
            console.log("Finding Order: ");
            console.logBytes32(logs[i].topics[0]);
            if (
                logs[i].topics[0] ==
                keccak256(
                    "Open(bytes32,(address,uint256,uint32,uint32,bytes32,(bytes32,uint256,bytes32,uint256)[],(bytes32,uint256,bytes32,uint256)[],(uint64,bytes32,bytes)[]))"
                )
            ) {
                console.log("Open Event Found");

                // Decode the topics and data
                orderId = bytes32(logs[i].topics[1]);
                ResolvedCrossChainOrder memory resolvedOrder = abi.decode(
                    logs[i].data,
                    (ResolvedCrossChainOrder)
                );

                fillInstructions = resolvedOrder.fillInstructions;
                for (uint256 j = 0; j < fillInstructions.length; j++) {
                    console.log("fillInstruction at ", j, " is: ");
                    console.log(
                        "Destination ChainId: ",
                        fillInstructions[j].destinationChainId
                    );
                    console.log("Destination Settler: ");
                    console.logBytes32(fillInstructions[j].destinationSettler);
                    console.log("originData: ");
                    console.logBytes(fillInstructions[j].originData);
                }

                // Log the event details
                console.log("Order ID from Event caught: ");
                console.logBytes32(orderId);
                console.log(
                    "Resolved Order User from Event caught:",
                    resolvedOrder.user
                );
                console.log(
                    "Resolved Order Origin Chain ID from Event caught:",
                    resolvedOrder.originChainId
                );
                console.log(
                    "Resolved Order Fill Deadline from Event caught:",
                    resolvedOrder.fillDeadline
                );
            }
        }

        vm.stopPrank();

        console.log(
            "Bridge Balance: ",
            interopToken.balanceOf(address(interopToken))
        );

        // Assert that the tokens were transferred to the contract
        assertEq(
            interopToken.balanceOf(address(interopToken)),
            100,
            "Contract should hold the transferred tokens"
        );

        console.log("Owner Balance: ", interopToken.balanceOf(owner));

        // Assert that owner's balance decreased
        assertEq(
            interopToken.balanceOf(owner),
            9900,
            "Owner's balance should decrease"
        );

        for (uint256 i = 0; i < fillInstructions.length; i++) {
            interopToken.fill(orderId, fillInstructions[i].originData, bytes(""));
        }

        console.log(
            "Bridge Balance: ",
            interopToken.balanceOf(address(interopToken))
        );

        console.log("User2 Balance: ", interopToken.balanceOf(user2));

        // Assert that owner's balance decreased
        assertEq(
            interopToken.balanceOf(user2),
            100,
            "User2's balance should increase"
        );
    }
}
