## Overview

A monorepo for ERC-20 token bridging, featuring services and clients to enable token transfers between any two EVM-compatible networks.

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

- To run the tests on externally running chains

```shell
$ forge test --fork-url "http://127.0.0.1:8545"
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

### Dev Usage Samples:

- run the node

```bash
anvil
```

- export env variables
```bash
export RPC_URL=http://127.0.0.1:8545
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

- get account balance

```bash
cast balance 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url $RPC_URL
```


- deploy an upgradeable interop token contract

```bash
forge script script/DeployInteropToken.s.sol --broadcast --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

- mint tokens on the deployed contact

```bash
cast send 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 "mint(address,uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 1000 --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

- query token balance
```bash
cast call 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 "balanceOf(address)(uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url $RPC_URL
```

- transfer tokens

```bash
cast send 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 "transfer(address,uint256)" 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 1 --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```