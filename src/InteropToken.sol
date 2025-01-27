// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IOriginSettler} from "./ERC7683.sol";

contract InteropToken is ERC20, Ownable, ReentrancyGuard, IOriginSettler {
    mapping(bytes32 => TradeInfo) public pendingOrders;

    struct TradeInfo {
        address from;
        address to;
        address token;
        uint256 amount;
        uint64 destinationChainId;
    }

    bytes32 immutable ORDER_DATA_TYPE_HASH = keccak256(TradeInfo);

    address constant bridgeOnSourceChain = address(1);

    event TransferredToBridgeOnSourceChain(
        address indexed from,
        address indexed to,
        uint256 indexed amount
    );

    constructor(
        address _initialOwner,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _initialSupply
    ) ERC20(_tokenName, _tokenSymbol) {
        _mint(_initialOwner, _initialSupply);
        _transferOwnership(_initialOwner);
    }

    function transferTokensCrossChain(
        address from,
        address to,
        uint256 amount,
        uint256 destinationChainId,
        bytes32 intent
    ) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        super._transfer(from, bridgeOnSourceChain, amount);

        emit TransferredToBridgeOnSourceChain(from, to, amount);
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

        require(
            pendingOrders[resolvedOrder.orderId].amount == 0,
            "Order already pending"
        );
        pendingOrders[resolvedOrder.orderId] = tradeInfo;

        // TODO: Assets should only be releaseable to the filler
        // on this chain once a proof of fill is submitted in a separate function. Ideally we can use RIP7755
        // to implement the storage proof escrow system.
        transferFrom(msg.sender, address(this), tradeInfo.amount);

        // The OpenEvent contains originData which is required to make the destination chain fill, so we only
        // emit the user calls.
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

        (tradeInfo) = decode7683OrderData(order.orderData);

        resolvedOrder = ResolvedCrossChainOrder({
            user: msg.sender,
            originChainId: block.chainid,
            openDeadline: type(uint32).max, // no deadline since user is msg.sender
            fillDeadline: order.fillDeadline,
            minReceived: new Output[](1){
                token: _toBytes32(tradeInfo.token),
                amount: tradeInfo.amount,
                recipient: _toBytes32(tradeInfo.to),
                chainId: block.chainid
            },
            maxSpent: new Output[](1){
                token: _toBytes32(tradeInfo.token),
                amount: tradeInfo.amount,
                recipient: _toBytes32(tradeInfo.to),
                chainId: tradeInfo.destinationChainId
            },
            fillInstructions: new FillInstruction[](1){
                destinationChainId: tradeInfo.destinationChainId,
                destinationSettler: _toBytes32(tradeInfo.to),
                originData: "To be decided"
            },
            orderId: "Generate a UUID"
        });
    }

    function _toBytes32(address input) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(input)));
    }

    function decode7683OrderData(
        bytes memory orderData
    ) public pure returns (TradeInfo) {
        TradeInfo memory decodedOrderData = abi.decode(orderData, (TradeInfo));
        return decodedOrderData;
    }
}
