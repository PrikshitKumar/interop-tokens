// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TokenProxy} from "./TokenProxy.sol";

/**
 * @dev Factory contract for deploying TokenProxy contract using CREATE2.
 *
 * This implementation provides a way to deterministically deploy TokenProxy contract
 * using the CREATE2 opcode.
 *
 */
contract TokenProxyFactory {
    /**
     * @notice Emitted when a new TokenProxy contract is created.
     * @dev This event is triggered upon the successful creation of a new `TokenProxy` contract,
     *      providing the address of the newly deployed contract and the salt used during its deployment.
     *
     * @param deployedAddress The address of the newly deployed TokenProxy contract
     * @param salt The salt value used in CREATE2 deployment
     */
    event TokenProxyCreated(address indexed deployedAddress, bytes32 salt);

    /**
     * @dev Error thrown when the CREATE2 deployment fails
     */
    error TokenProxyCreate2Failed();

    /**
     * @notice Deploys a new TokenProxy contract using CREATE2.
     * @dev This function creates a new TokenProxy contract with the specified parameters.
     * The address of the deployed contract is deterministic and depends on the salt value.
     *
     * Requirements:
     * - The deployment must not fail
     * - The salt value must not have been used before
     *
     * @param _initialOwner The address of initial owner of tokens
     * @param _tokenName The name of the token
     * @param _tokenSymbol The symbol of the token
     * @param _salt A unique value used to determine the contract address
     * 
     * @return deployedAddress The address of the newly deployed TokenProxy contract
     * 
     * Error:
     * - `TokenProxyCreate2Failed`: Reverted if the deployment failed by verifying that the returned address is zero.
     * 
     * Emits
     * - `TokenProxyCreated`: Emitted when a new TokenProxy contract is created.
     */
    function deployTokenProxyFromFactory(
        address _implementationAuthority,
        address _initialOwner,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint8 _decimals,
        bytes32 _salt
    ) public returns (address) {
        address deployedAddress;
        bytes memory bytecode = abi.encodePacked(
            type(TokenProxy).creationCode,
            abi.encode(
                _implementationAuthority,
                _initialOwner,
                _tokenName,
                _tokenSymbol,
                _decimals
            )
        );

        // solhint-disable-next-line no-inline-assembly
        assembly {
            // CREATE2 deploys a new contract with the provided bytecode
            // 0: The amount of Ether to send to the new contract (in this case, 0)
            // add(bytecode, 32): The starting position of the actual contract bytecode
            //          (skipping the first 32 bytes which store the length of the bytecode array)
            // mload(bytecode): The length of the bytecode
            // salt: A unique value used to determine the contract address
            deployedAddress := create2(
                0,
                add(bytecode, 32),
                mload(bytecode),
                _salt
            )
        }

        if (deployedAddress == address(0)) {
            revert TokenProxyCreate2Failed();
        }

        emit TokenProxyCreated(deployedAddress, _salt);

        return deployedAddress;
    }
}
