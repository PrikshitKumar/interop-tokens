// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {OnchainCrossChainOrder, ResolvedCrossChainOrder, Output, FillInstruction, IOriginSettler, IDestinationSettler} from "./ERC7683.sol";

contract InteropToken is
    ERC20,
    Ownable,
    ReentrancyGuard,
    IOriginSettler,
    IDestinationSettler
{
    struct OrderData {
        address to;
        uint256 amount;
        uint64 destinationChainId;
        address feeToken;
        uint256 feeValue;
    }

    struct OpenOrder {
        address from;
        OrderData orderData;
    }

    /**
     * @notice The address of the Filler
     * @dev Responsible to execute the orders
     */
    address private FILLER =
        address(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496);

    /**
     * @notice Restricts access to only the authorized filler.
     * @dev This modifier ensures that only the designated filler can execute the function it is applied to.
     *
     * Error:
     * - `UnauthorizedFiller`: Reverted if the caller is not the authorized filler.
     */
    modifier onlyFiller() {
        if (msg.sender != FILLER) revert UnauthorizedFiller(msg.sender, FILLER);
        _;
    }

    mapping(bytes32 => OpenOrder) public pendingOrders;
    mapping(bytes32 => bool) public executedOrders;

    bytes32 immutable ORDER_DATA_TYPE_HASH =
        keccak256("Order(address,uint256,uint64,address,uint256)");

    error WrongOrderType();
    error OrderNotPending();
    error UnauthorizedFiller(address sender, address filler);

    event Fill(bytes32 indexed orderId);
    event Acknowledge(bytes32 indexed orderId);
    event Cancel(bytes32 indexed orderId);

    constructor(
        address _initialOwner,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _initialSupply
    ) ERC20(_tokenName, _tokenSymbol) Ownable(_initialOwner) {
        _mint(_initialOwner, _initialSupply);
    }

    /// @notice Opens a cross-chain order
    /// @dev To be called by the user
    /// @dev This method must emit the Open event
    /// @param order The OnchainCrossChainOrder definition
    function open(OnchainCrossChainOrder calldata order) external nonReentrant {
        OrderData memory orderData = decode7683OrderData(order.orderData);
        ResolvedCrossChainOrder memory resolvedOrder = this.resolve(order);

        require(orderData.amount != 0, "Invalid Order");
        require(
            pendingOrders[resolvedOrder.orderId].orderData.amount == 0,
            "Order already pending"
        );
        OpenOrder memory openOrder = OpenOrder({
            from: msg.sender,
            orderData: orderData
        });

        pendingOrders[resolvedOrder.orderId] = openOrder;

        // order amount is taken in custody of the contract
        // to be released in the event of order cancellation due to filler failure
        // to be burnt in the event of a successful cross-chain transfer
        _transfer(msg.sender, address(this), orderData.amount);
        // TODO: Transfer the RelayFee (Native Tokens) to Filler

        emit IOriginSettler.Open(
            keccak256(resolvedOrder.fillInstructions[0].originData),
            resolvedOrder
        );
    }

    function resolve(
        OnchainCrossChainOrder calldata order
    ) external view returns (ResolvedCrossChainOrder memory) {
        if (order.orderDataType != ORDER_DATA_TYPE_HASH) {
            revert WrongOrderType();
        }

        OrderData memory orderData = decode7683OrderData(order.orderData);

        Output[] memory _maxSpent = new Output[](1);
        Output[] memory _minReceived = new Output[](1);
        FillInstruction[] memory _fillInstructions = new FillInstruction[](1);

        _maxSpent[0] = Output({
            token: _toBytes32(orderData.feeToken),
            amount: orderData.feeValue,
            recipient: _toBytes32(orderData.to),
            chainId: orderData.destinationChainId
        });

        _minReceived[0] = Output({
            token: _toBytes32(address(this)),
            amount: orderData.amount, // This amount represents the minimum relayer fee compensated for facilitating the transaction to Filler
            recipient: _toBytes32(address(0)), // TODO : Add filler address here from the implementation authority contract
            chainId: block.chainid
        });

        _fillInstructions[0] = FillInstruction({
            destinationChainId: orderData.destinationChainId,
            destinationSettler: _toBytes32(address(this)), // Token address is assumed to be matching on the destination chain
            originData: order.orderData
        });

        return
            ResolvedCrossChainOrder({
                user: msg.sender,
                originChainId: block.chainid,
                openDeadline: type(uint32).max, // No deadline for origin orders
                fillDeadline: order.fillDeadline,
                orderId: _generateOrderId(), // Generate order ID as hash of order data
                maxSpent: _maxSpent,
                minReceived: _minReceived,
                fillInstructions: _fillInstructions
            });
    }

    function fill(
        bytes32 orderId,
        bytes calldata originData,
        bytes calldata fillerData
    ) external nonReentrant onlyFiller {
        if (
            executedOrders[orderId] ||
            pendingOrders[orderId].orderData.amount == 0
        ) {
            revert OrderNotPending();
        }

        // TODO: Validate the sender to be an authorized filler address on implementation authority
        OrderData memory orderData = decode7683OrderData(originData);
        _mint(orderData.to, orderData.amount);

        emit Fill(orderId);

        // TODO: To be Decided, what fillerData should contain
        // decode7683FillInstruction(fillerData);
        fillerData;
    }

    // TODO: Add a confirmOrder function; called by the filler

    function cancel(bytes32 orderId) external nonReentrant onlyFiller {
        require(
            pendingOrders[orderId].orderData.amount != 0,
            "Order not found"
        );
        OpenOrder memory openOrder = pendingOrders[orderId];
        _transfer(address(this), openOrder.from, openOrder.orderData.amount);
        delete pendingOrders[orderId];
        emit Cancel(orderId);
    }

    function _generateOrderId() internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    block.timestamp, // Current block timestamp
                    block.prevrandao, // Randomness beacon value in PoS
                    msg.sender, // Transaction sender
                    block.number // Current block Number
                )
            );
    }

    function _toBytes32(address input) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(input)));
    }

    function decode7683OrderData(
        bytes memory orderData
    ) public pure returns (OrderData memory) {
        return abi.decode(orderData, (OrderData));
    }

    function decode7683FillInstruction(
        bytes memory fillInstruction
    ) public pure returns (FillInstruction memory) {
        return abi.decode(fillInstruction, (FillInstruction));
    }
}
