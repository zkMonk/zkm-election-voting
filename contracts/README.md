## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

The easiest way to install Foundry is to follow the instructions for installing [foundryup](https://book.getfoundry.sh/getting-started/installation#using-foundryup) and then installing Foundery using foundryup.

## Usage
First install the forge standard libraries submodule, as the build won't work without them:

```
cd ../zkm-hackathon
it submodule init
git submodule update

```

### Build

```shell
$ forge build
```

### Test

The following command will locally verify the validity of the snark proof.

```shell
$ forge test 
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

To sepolia

```shell
$ forge script script/verifier.s.sol:VerifierScript --rpc-url https://eth-sepolia.g.alchemy.com/v2/RH793ZL_pQkZb7KttcWcTlOjPrN0BjOW --private-key df4bc5647fdb9600ceb4943d4adff3749956a8512e5707716357b13d5ee687d9
```

To anvil

```
forge script script/verifier.s.sol:VerifierScript --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast

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
