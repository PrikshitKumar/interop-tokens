// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TokenStorage {
    
    /// @dev ERC20 basic variables
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;
    uint256 internal _totalSupply;

    /// @dev Token information
    string internal _tokenName;
    string internal _tokenSymbol;
    uint8 internal _tokenDecimals;
    string internal constant _TOKEN_VERSION = "1.0.0";

    /// @dev pause information
    bool internal _tokenPaused = false;

    mapping(bytes32 => OpenOrder) public pendingOrders;

    struct OpenOrder {
        address from;
        OrderData orderData;
    }
    struct OrderData {
        address to;
        uint256 amount;
        uint64 destinationChainId;
        address feeToken;
        uint256 feeValue;
    }
    
    bytes32 immutable ORDER_DATA_TYPE_HASH =
        keccak256(
            "Order(address,uint256,uint64,address,uint256)"
        );
    
    /**
     * @notice The address of the Filler
     * @dev Responsible to execute the orders
     */
    address internal FILLER =
        address(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[49] private __gap;
}
