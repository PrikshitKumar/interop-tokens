// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

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
    mapping(bytes32 => TradeInfo) public pendingOrders;

    struct TradeInfo {
        address from;
        address to;
        address token;
        uint256 amount;
        uint64 destinationChainId;
        bytes32 intent;
    }

    bytes32 immutable ORDER_DATA_TYPE_HASH =
        keccak256(
            "TradeInfo(address from,address to,address token,uint256 amount,uint64 destinationChainId,bytes32 intent)"
        );

    event TransferredToContractOnSourceChain(
        address indexed from,
        address indexed to,
        uint256 indexed amount
    );

    error WrongOrderDataType();

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
        (
            ResolvedCrossChainOrder memory resolvedOrder,
            TradeInfo memory tradeInfo
        ) = _resolve(order);

        require(tradeInfo.amount != 0, "Invalid Order");

        require(
            pendingOrders[resolvedOrder.orderId].amount == 0,
            "Order already pending"
        );

        pendingOrders[resolvedOrder.orderId] = tradeInfo;

        _transfer(msg.sender, address(this), tradeInfo.amount);
        // TODO: Transfer the RelayFee (Native Tokens) to Filler

        emit IOriginSettler.Open(
            keccak256(resolvedOrder.fillInstructions[0].originData),
            resolvedOrder
        );
    }

    function _resolve(
        OnchainCrossChainOrder calldata order
    )
        internal
        view
        returns (
            ResolvedCrossChainOrder memory resolvedOrder,
            TradeInfo memory tradeInfo
        )
    {
        if (order.orderDataType != ORDER_DATA_TYPE_HASH) {
            revert WrongOrderDataType();
        }

        tradeInfo = decode7683OrderData(order.orderData);

        Output[] memory _maxSpent = new Output[](1);
        Output[] memory _minReceived = new Output[](1);
        FillInstruction[] memory _fillInstructions = new FillInstruction[](1);

        _maxSpent[0] = Output({
            token: _toBytes32(tradeInfo.token),
            amount: tradeInfo.amount,
            recipient: _toBytes32(tradeInfo.to),
            chainId: tradeInfo.destinationChainId
        });

        _minReceived[0] = Output({
            token: _toBytes32(tradeInfo.token),
            amount: tradeInfo.amount, // This amount represents the minimum relayer fee compensated for facilitating the transaction to Filler
            recipient: _toBytes32(address(0)),
            chainId: block.chainid
        });

        _fillInstructions[0] = FillInstruction({
            destinationChainId: tradeInfo.destinationChainId,
            destinationSettler: _toBytes32(tradeInfo.to),
            originData: order.orderData
        });

        resolvedOrder = ResolvedCrossChainOrder({
            user: msg.sender,
            originChainId: block.chainid,
            openDeadline: type(uint32).max, // No deadline for origin orders
            fillDeadline: order.fillDeadline,
            orderId: _generateUUID(), // Generate order ID as hash of order data
            maxSpent: _maxSpent,
            minReceived: _minReceived,
            fillInstructions: _fillInstructions
        });
    }

    function fill(
        bytes32 orderId,
        bytes calldata originData,
        bytes calldata fillerData
    ) external nonReentrant {
        TradeInfo memory tradeInfo = decode7683OrderData(originData);
        _transfer(address(this), tradeInfo.to, tradeInfo.amount);

        // TODO: To be Decided, what fillerData should contain
        // decode7683FillInstruction(fillerData)
    }

    function _generateUUID() internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    block.timestamp, // Current block timestamp
                    block.prevrandao, // Randomness beacon value in PoS
                    msg.sender, // Transaction sender
                    blockhash(block.number - 1) // Previous block hash
                )
            );
    }

    function _toBytes32(address input) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(input)));
    }

    function decode7683OrderData(
        bytes memory orderData
    ) public pure returns (TradeInfo memory) {
        return abi.decode(orderData, (TradeInfo));
    }

    function decode7683FillInstruction(
        bytes memory fillInstruction
    ) public pure returns (FillInstruction memory) {
        return abi.decode(fillInstruction, (FillInstruction));
    }
}
