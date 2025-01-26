## Packet Structure:

### ERC-20 Transfer (initiated by User from chain1):

```json // User Inputs
{
  "recepient": "<Recipient Address on Destination Chain | Address>",
  "value": "<Amount of tokens to be transferred | uint256>",
  "destinationChainId": "<Destination Chain ID | uint256>",
  "intent": "<Purpose of transfer / action | bytes32>"
}
```

### Packet generation for Destination Chain (x-chain communication standard - Prepared by Relayer through Events emitted by Contract-1)

```json
// Standard order struct for user-opened orders
struct OnchainCrossChainOrder {
	"fillDeadline": "<The timestamp by which the order must be filled on the destination chain | uint32>",
    "orderDataType": "<Type identifier for the order data. Helps in orderData decoding | bytes32>",
    "orderData": "<Encoded form of user inputed data | bytes>"
}
```

### Packet Decoding on Destination Chain (x-chain communication standard)

```json
// Defines all requirements for filling an order by unbundling the implementation-specific orderData
struct ResolvedCrossChainOrder {
	"user": "<The address of the user who is initiating the transfer | address>",
	"originChainId" : "<The chainId of the origin chain | uint256>",
	"openDeadline" : "<The timestamp by which the order must be opened | uint32>",
	"fillDeadline" : "<The timestamp by which the order must be filled on the destination chain | uint32>",
	"orderId": "<The unique identifier for this order within this settlement system (can be a Nonce) | bytes32>",
	"maxSpent": [
        // The max outputs that the filler will send. It's possible the actual amount depends on the state of the destination.
        // Array of Output struct declared below: Output[]
    ],
	"minReceived": [
        // The minimum outputs that must be given to the filler as part of order settlement
        // Array of Output struct declared below: Output[]
        // Setting the `recipient` of an `Output` to address(0) indicates that the filler is not known when creating this order.
    ],
	"fillInstructions": [
        // Each instruction in this array is parameterizes a single leg of the fill. This provides the filler with the information necessary to perform the fill on the destination(s).
    ]
}

// Tokens that must be received for a valid order fulfillment
struct Output {
	// address(0) used as a sentinel for the native token
	"token": "<The address of the ERC20 token on the destination chain | bytes32>",
	"amount" : "<The amount of the token to be sent | uint256>",
	"recipient" : "<Recipient Address on the destination chain | bytes32>",
	"chainId" : "<The destination chain for this output | uint256>"
}

// Provides all the origin-generated information required to produce a valid fill leg
struct FillInstruction {
	"destinationChainId" : "<The chain that this instruction is intended to be filled on | uint256>",
	"destinationSettler" : "<The contract address that the instruction is intended to be filled on | bytes32>",
	"originData": "<The data generated on the origin chain needed by the destinationSettler to process the fill | bytes>"
}
```

### Packet Transmission Failed

```json

```
