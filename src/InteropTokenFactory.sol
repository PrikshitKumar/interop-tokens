// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {InteropToken} from "./InteropToken.sol";

/**
 * @dev Factory contract for deploying InteropToken contract using CREATE2.
 *
 * This implementation provides a way to deterministically deploy InteropToken contract
 * using the CREATE2 opcode.
 *
 * The factory can deploy different types of InteropToken contract based on the
 * InteropTokenType enum defined in the InteropToken contract.
 */
contract InteropTokenFactory {
    /**
     * @notice Emitted when a new InteropToken contract is created.
     * @dev This event is triggered upon the successful creation of a new `InteropToken` contract,
     *      providing the address of the newly deployed contract and the salt used during its deployment.
     *
     * @param deployedAddress The address of the newly deployed InteropToken contract
     * @param salt The salt value used in CREATE2 deployment
     */
    event InteropTokenCreated(address indexed deployedAddress, bytes32 salt);

    /**
     * @dev Error thrown when the CREATE2 deployment fails
     */
    error InteropTokenCreate2Failed();

    /**
     * @notice Deploys a new InteropToken contract using CREATE2.
     * @dev This function creates a new InteropToken contract with the specified parameters.
     * The address of the deployed contract is deterministic and depends on the salt value.
     *
     * Requirements:
     * - The deployment must not fail
     * - The salt value must not have been used before
     *
     * @param _initialOwner The address of initial owner of tokens
     * @param _tokenName The name of the token
     * @param _tokenSymbol The symbol of the token
     * @param _initialSupply The initial supply of tokens to mint
     * @param _salt A unique value used to determine the contract address
     * 
     * @return deployedAddress The address of the newly deployed InteropToken contract
     * 
     * Error:
     * - `InteropTokenCreate2Failed`: Reverted if the deployment failed by verifying that the returned address is zero.
     * 
     * Emits
     * - `InteropTokenCreated`: Emitted when a new InteropToken contract is created.
     */
    function deployInteropTokenFromFactory(
        address _initialOwner,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _initialSupply,
        bytes32 _salt
    ) public returns (address) {
        address deployedAddress;
        bytes memory bytecode = abi.encodePacked(
            type(InteropToken).creationCode,
            abi.encode(
                _initialOwner,
                _tokenName,
                _tokenSymbol,
                _initialSupply
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
            revert InteropTokenCreate2Failed();
        }

        emit InteropTokenCreated(deployedAddress, _salt);

        return deployedAddress;
    }
}
