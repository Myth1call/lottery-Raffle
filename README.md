# Lottery (Raffle)

A Solidity raffle contract where players pay an entrance fee, and after a time interval **Chainlink Automation** (`checkUpkeep` / `performUpkeep`) requests randomness via **Chainlink VRF v2.5**, selects a winner, and transfers the prize to the winner's address.

- **Default network in scripts:** Sepolia  
- **Stack:** [Foundry](https://book.getfoundry.sh/), Chainlink contracts (via `lib/chainlink`)

## Requirements

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge`, `cast`, `anvil`)

## Installation

```bash
git clone https://github.com/Myth1call/lottery-Raffle
cd lottery
git submodule update --init --recursive
```

Or install dependencies via `Makefile`:

```bash
make install
```

Build:

```bash
make build
# or
forge build
```

## Environment Variables

Copy the example and fill values:

```bash
cp .env.example .env
```

| Variable | Purpose |
|----------|---------|
| `SEPOLIA_RPC_URL` | Sepolia RPC endpoint (Alchemy, Infura, etc.) |
| `ETHERSCAN_API_KEY` | Etherscan API key for contract verification |

For deployment via `Makefile`, the project uses **`--account my-sepolia`** (Foundry keystore). Import key:

```bash
cast wallet import my-sepolia --private-key "$PRIVATE_KEY"
```

Alternative: run `forge script` manually with `--private-key` (never commit your key).

## Network Configuration (`HelperConfig`)

File: `script/HelperConfig.s.sol`.

- **Sepolia:** set `subscriptionId` and `account` (VRF subscription owner and script wallet address).  
  If `subscriptionId == 0`, `DeployRaffle` will attempt to create and fund a subscription (requires a valid `account` and LINK on Sepolia).
- **Local (Anvil, chain id 31337):** mock VRF and test LINK are deployed automatically; no separate setup required.

Sepolia LINK address is already set in config (official test LINK).

## Tests

```bash
make test
# or
forge test
```

It is recommended to run tests **without** `--fork-url`: unit tests are designed for local mock VRF.  
With a Sepolia fork, some scenarios (manual `fulfillRandomWords`, exact contract balance assertions) may behave differently.

```bash
forge test -vvv
```

## Deploy to Sepolia

Make sure `subscriptionId` / `account` are set in `HelperConfig` (or use `subscriptionId = 0` and valid `account` for auto-creation), `.env` includes `SEPOLIA_RPC_URL` and `ETHERSCAN_API_KEY`, and keystore contains `my-sepolia`.

```bash
make deploy-sepolia
```

Manual equivalent is in `Makefile` (`forge script script/DeployRaffle.s.sol:DeployRaffle ...`).

## Interaction Scripts

| Script | Contract in `Interactions.s.sol` | Purpose |
|--------|-----------------------------------|---------|
| `CreateSubscription` | `CreateSubscription` | Create VRF subscription |
| `FundSubscription` | `FundSubscription` | Fund subscription (on Sepolia via LINK `transferAndCall`) |
| `AddConsumer` | `AddConsumer` | Add consumer (`Raffle` contract) to subscription |

Run example:

```bash
forge script script/Interactions.s.sol:CreateSubscription --rpc-url "$SEPOLIA_RPC_URL" --account my-sepolia --broadcast -vvvv
```

## Project Structure

```text
src/           - Raffle contract
script/        - deployment, HelperConfig, Interactions
test/unit/     - unit tests
test/mocks/    - mocks (e.g., LinkToken)
lib/           - forge-std, chainlink, solmate, foundry-devops
```

## CI

`.github/workflows/test.yml` runs `forge fmt --check`, `forge build`, and `forge test`.

## License

See SPDX headers in source files (MIT).
