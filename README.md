# DYAD

![dyad](https://pbs.twimg.com/profile_images/1715367809843175424/LCqtLCJn_400x400.jpg)

## Contracts

```ml
core
├─ DNft — "A dNFT gives you the right to mint DYAD"
├─ Dyad — "Stablecoin backed by ETH"
├─ VaultManager - "Manage Vaults for DNfts"
├─ VaultManagerV2 - "VaultManager with flash loan protection"
├─ Vault - "Holds different collateral types"
├─ Licenser - "License VaultManagers or Vaults"
├─ KerosineManager - "Add/Remove Vaults to the Kerosene Calculation"

staking
├─ Kerosine - "Kerosene ERC20"
├─ KerosineDenominator
├─ Staking - "Simple staking contract"

periphery
├─ Payments
```

## Docs

- [Kerosene](https://dyadstable.notion.site/KEROSENE-Equations-Final-8655c83e0b7d44f883b9a99f499866c3)

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
