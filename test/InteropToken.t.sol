// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {InteropToken} from "../src/InteropToken.sol";
import {OnchainCrossChainOrder, ResolvedCrossChainOrder, Output, FillInstruction, IOriginSettler} from "../src/ERC7683.sol";

contract InteropTokenTest is Test {
    InteropToken public interopToken;

    address public owner;
    address public user1;
    address public user2;

    bytes32 constant ORDER_DATA_TYPE_HASH =
        keccak256("Order(address,uint256,uint64,address,uint256)");

    // Setup the Users
    function setUp() public {
        // Fetch default test accounts provided by Foundry
        owner = address(this); // The contract address is the owner by default
        user1 = vm.addr(1); // Fetch address 1 (used as a test account)
        user2 = vm.addr(2); // Fetch address 2 (another test account)

        // Deploy the contract
        interopToken = new InteropToken(owner, "InteropToken", "IPT", 10000);
    }

    // Test that owner can transfer tokens successfully
    function testOpenOrder() public {
        // Assert that user2's balance increased by the transfer amount
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
                InteropToken.OrderData({
                    to: user2,
                    amount: 100,
                    destinationChainId: destinationChainId,
                    feeToken: address(0),
                    feeValue: 0
                })
            )
        });

        // User with whom the transaction is executed
        vm.startPrank(owner);

        // Record logs emitted during the execution
        vm.recordLogs();

        // Call the function that emits the event
        // Call the `open` function
        interopToken.open(order);

        // Stop recording logs
        Vm.Log[] memory logs = vm.getRecordedLogs();
        FillInstruction[] memory fillInstructions;
        bytes32 orderId;

        // Search for the emitted Open event
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics[0] ==
                keccak256(
                    "Open(bytes32,(address,uint256,uint32,uint32,bytes32,(bytes32,uint256,bytes32,uint256)[],(bytes32,uint256,bytes32,uint256)[],(uint64,bytes32,bytes)[]))"
                )
            ) {
                // Decode the topics and data
                ResolvedCrossChainOrder memory resolvedOrder = abi.decode(
                    logs[i].data,
                    (ResolvedCrossChainOrder)
                );

                orderId = resolvedOrder.orderId;

                fillInstructions = resolvedOrder.fillInstructions;
            }
        }

        vm.stopPrank();

        // Assert that the tokens were transferred to the contract
        assertEq(
            interopToken.balanceOf(address(interopToken)),
            100,
            "Contract should hold the transferred tokens"
        );

        // Assert that owner's balance decreased
        assertEq(
            interopToken.balanceOf(owner),
            9900,
            "Owner's balance should decrease"
        );

        for (uint256 i = 0; i < fillInstructions.length; i++) {
            interopToken.fill(
                orderId,
                fillInstructions[i].originData,
                bytes("")
            );
        }

        // Assert that owner's balance decreased
        assertEq(
            interopToken.balanceOf(user2),
            100,
            "User2's balance should increase"
        );

        interopToken.confirm(orderId);
        (address from, ) = interopToken.pendingOrders(orderId);
        assertEq(from, address(0), "Order must be removed from pending orders");
    }
}
