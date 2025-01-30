// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {InteropTokenFactory} from "src/InteropTokenFactory.sol";
import {InteropToken} from "src/InteropToken.sol";

contract InteropTokenFactoryTest is Test {
    InteropTokenFactory factory;
    address deployer;
    address initialOwner;
    string tokenName = "Test Token";
    string tokenSymbol = "TST";
    uint256 initialSupply = 10000;
    bytes32 salt = keccak256("unique-salt");
    // const SALT = ethers.randomBytes(32);

    function setUp() public {
        factory = new InteropTokenFactory();
        deployer = address(this);
        initialOwner = vm.addr(1);
    }

    function testDeployInteropTokenSuccess() public {
        address deployedAddress = factory.deployInteropTokenFromFactory(
            initialOwner,
            tokenName,
            tokenSymbol,
            initialSupply,
            salt
        );

        // Ensure the deployed address is non-zero
        assertTrue(deployedAddress != address(0));

        // Check if it's actually an InteropToken contract
        InteropToken token = InteropToken(deployedAddress);
        assertEq(token.name(), tokenName);
        assertEq(token.symbol(), tokenSymbol);
        assertEq(token.totalSupply(), initialSupply);
        assertEq(token.balanceOf(initialOwner), initialSupply);
    }

    function testFailDeployWithSameSalt() public {
        // First deployment succeeds
        factory.deployInteropTokenFromFactory(
            initialOwner,
            tokenName,
            tokenSymbol,
            initialSupply,
            salt
        );

        // Expect the next deployment to fail before calling the function
        // The CreateCollision error is typically thrown when there is an address collision in the EVM. In your case, this means that the contract address for the newly deployed InteropToken already exists, which can happen if the same salt is used in a CREATE2 operation.
        vm.expectRevert("CreateCollision");

        // This should revert and trigger `InteropTokenCreate2Failed`
        factory.deployInteropTokenFromFactory(
            initialOwner,
            tokenName,
            tokenSymbol,
            initialSupply,
            salt
        );
    }

    function testCreate2AddressDeterministic() public {
        bytes32 initCodeHash = keccak256(
            abi.encodePacked(
                type(InteropToken).creationCode,
                abi.encode(initialOwner, tokenName, tokenSymbol, initialSupply)
            )
        );

        address expectedAddress = vm.computeCreate2Address(
            salt,
            initCodeHash,
            address(factory)
        );

        address deployedAddress = factory.deployInteropTokenFromFactory(
            initialOwner,
            tokenName,
            tokenSymbol,
            initialSupply,
            salt
        );

        assertEq(deployedAddress, expectedAddress);
    }
}
