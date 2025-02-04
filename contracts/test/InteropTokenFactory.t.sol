// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenProxyFactory} from "src/proxy/TokenProxyFactory.sol";

import {TokenProxy} from "src/proxy/TokenProxy.sol";

import {ImplementationAuthority} from "src/proxy/ImplementationAuthority.sol";

import {InteropToken} from "src/InteropToken.sol";

contract TokenProxyFactoryTest is Test {
    TokenProxyFactory factory;
    InteropToken interopToken;
    ImplementationAuthority implementationAuthority;

    address deployer;
    address initialOwner;
    string tokenName = "Test Token";
    string tokenSymbol = "TST";
    uint8 decimals = 18;
    bytes32 salt = keccak256("unique-salt");
    // const SALT = ethers.randomBytes(32);

    function setUp() public {
        interopToken = new InteropToken();
        implementationAuthority = new ImplementationAuthority(address(interopToken));
        factory = new TokenProxyFactory();
        deployer = address(this);
        initialOwner = vm.addr(1);
    }

    function testDeployInteropTokenSuccess() public {
        address deployedAddress = factory.deployTokenProxyFromFactory(
            address(implementationAuthority),
            initialOwner,
            tokenName,
            tokenSymbol,
            decimals,
            salt
        );

        // Ensure the deployed address is non-zero
        assertTrue(deployedAddress != address(0));

        // Check if it's actually an InteropToken contract
        InteropToken token = InteropToken(deployedAddress);
        assertEq(token.name(), tokenName);
        assertEq(token.symbol(), tokenSymbol);
    }

    function testDeploymentWithSameSalt() public {
        // First deployment succeeds
        factory.deployTokenProxyFromFactory(
            address(implementationAuthority),
            initialOwner,
            tokenName,
            tokenSymbol,
            decimals,
            salt
        );

        // Expect the next deployment to fail before calling the function
        vm.expectRevert(TokenProxyFactory.TokenProxyCreate2Failed.selector);

        // This should revert and trigger `InteropTokenCreate2Failed`
        factory.deployTokenProxyFromFactory(
            address(implementationAuthority),
            initialOwner,
            tokenName,
            tokenSymbol,
            decimals,
            salt
        );
    }

    function testCreate2AddressDeterministic() public {
        bytes32 initCodeHash = keccak256(
            abi.encodePacked(
                type(TokenProxy).creationCode,
                abi.encode(address(implementationAuthority),initialOwner, tokenName, tokenSymbol, decimals)
            )
        );

        address expectedAddress = vm.computeCreate2Address(
            salt,
            initCodeHash,
            address(factory)
        );

        address deployedAddress = factory.deployTokenProxyFromFactory(
            address(implementationAuthority),
            initialOwner,
            tokenName,
            tokenSymbol,
            decimals,
            salt
        );

        assertEq(deployedAddress, expectedAddress);
    }
}
