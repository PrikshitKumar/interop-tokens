// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {InteropToken} from "../src/InteropToken.sol";
import {OnchainCrossChainOrder, ResolvedCrossChainOrder, Output, FillInstruction, IOriginSettler} from "../src/ERC7683.sol";

contract InteropTokenTest is Test {
    InteropToken public interopToken;

    address public owner;
    address public user1;
    address public user2;

    bytes32 constant ORDER_DATA_TYPE_HASH =
        keccak256(
            "TradeInfo(address from,address to,address token,uint256 amount,uint64 destinationChainId,bytes32 intent)"
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
        interopToken = new InteropToken(owner, "InteropToken", "IPT", 10000);

        // Optionally, mint tokens to owner for testing
        // interopToken._mint(owner, 1000);
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
                InteropToken.TradeInfo({
                    from: owner,
                    to: user2,
                    token: address(interopToken),
                    amount: 100,
                    destinationChainId: destinationChainId,
                    intent: bytes32("ERC-20 tokens Transfer to User2")
                })
            )
        });

        // Log each part of the order
        InteropToken.TradeInfo memory tradeInfo = abi.decode(
            order.orderData,
            (InteropToken.TradeInfo)
        );
        console.log("fillDeadline: ", order.fillDeadline);
        console.log("orderDataType: ");
        console.logBytes32(order.orderDataType);
        console.log("from: ", tradeInfo.from);
        console.log("to: ", tradeInfo.to);
        console.log("token: ", tradeInfo.token);
        console.log("amount: ", tradeInfo.amount);
        console.log("destinationChainId: ", tradeInfo.destinationChainId);
        console.log("intent: ");
        console.logBytes32(tradeInfo.intent);

        // User with whom the transaction is executed
        vm.startPrank(owner);

        // Approve the contract to spend owner's tokens
        interopToken.approve(address(interopToken), 100);

        uint256 allowance = interopToken.allowance(
            owner,
            address(interopToken)
        );
        console.log("Allowance: ", allowance);

        // Record logs emitted during the execution
        vm.recordLogs();

        // Call the function that emits the event
        // Call the `open` function
        interopToken.open(order);
        console.log("Open executed");

        // Stop recording logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

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
                bytes32 orderId = bytes32(logs[i].topics[1]);
                ResolvedCrossChainOrder memory resolvedOrder = abi.decode(
                    logs[i].data,
                    (ResolvedCrossChainOrder)
                );

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
            "Owner Balance: ",
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
    }
}
