# DYAD

![dyad](https://pbs.twimg.com/profile_images/1715367809843175424/LCqtLCJn_400x400.jpg)

## Contracts

```ml
core
├─ DNft — "A dNFT gives you the right to mint DYAD"
├─ Dyad — "Stablecoin backed by ETH"
├─ VaultManager
├─ Vault 
├─ Licenser 

periphery
├─ Payments
```

## Usage

You will need a copy of [Foundry](https://github.com/foundry-rs/foundry) installed before proceeding. See the [installation guide](https://github.com/foundry-rs/foundry#installation) for details.

To build the contracts:

```sh
git clone https://github.com/DyadStablecoin/contracts-v3.git
cd contracts-v3
forge install
```

### Run Tests

In order to run unit tests, run:

```sh
forge test
```
