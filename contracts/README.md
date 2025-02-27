## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

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

# Battle Royale Game - Interaction Guide

This README provides instructions on how to interact with the Battle Royale game contracts using the `cast` command-line tool from Foundry.

## Deployed Contract Addresses

From the latest deployment:

- **BattleRoyaleFactory**: 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707
- **BotFactory**: 0x0165878A594ca255338adfa4d48449f69242Eb8F
- **Sample Game**: 0x61c36a8d610163660E21a8b7359e1Cac0C9133e1
- **Sample Game Rewards**: 0x23dB4a08f2272df049a4932a4Cc3A6Dc1002B33E
- **Sample Bot**: 0x3B02fF1e626Ed7a8fd6eC5299e2C54e1421B626B

## RPC Endpoint

All commands use the Base Appchain Testnet RPC:

```
https://sandbox-rpc-testnet.appchain.base.org
```

## Game Management Commands

### Create a New Round

```bash
cast send 0x61c36a8d610163660E21a8b7359e1Cac0C9133e1 "createRound(uint256)" 1000 --rpc-url https://sandbox-rpc-testnet.appchain.base.org --private-key YOUR_PRIVATE_KEY
```

Replace `YOUR_PRIVATE_KEY` with the private key of the game owner. The parameter `1000` represents the registration period in blocks.

### Register a Player

```bash
cast send 0x61c36a8d610163660E21a8b7359e1Cac0C9133e1 "register()" --rpc-url https://sandbox-rpc-testnet.appchain.base.org --private-key YOUR_PRIVATE_KEY
```

### Start the Game

After at least 2 players have registered:

```bash
cast send 0x61c36a8d610163660E21a8b7359e1Cac0C9133e1 "startGame()" --rpc-url https://sandbox-rpc-testnet.appchain.base.org --private-key YOUR_PRIVATE_KEY
```

### Execute Pending Actions

```bash
cast send 0x61c36a8d610163660E21a8b7359e1Cac0C9133e1 "executeActions()" --rpc-url https://sandbox-rpc-testnet.appchain.base.org --private-key $PRIVATE_KEY
```

### Reset Game (After Completion)

```bash
cast send 0x61c36a8d610163660E21a8b7359e1Cac0C9133e1 "resetGame()" --rpc-url https://sandbox-rpc-testnet.appchain.base.org --private-key YOUR_PRIVATE_KEY
```

## Player Action Commands

### Submit Move Action

```bash
cast send 0x61c36a8d610163660E21a8b7359e1Cac0C9133e1 "submitMove(uint8)" DIRECTION --rpc-url https://sandbox-rpc-testnet.appchain.base.org --private-key $PRIVATE_KEY
```

Where `DIRECTION` is:
- 0: UP
- 1: DOWN
- 2: LEFT
- 3: RIGHT

### Submit Attack Action

```bash
cast send 0x61c36a8d610163660E21a8b7359e1Cac0C9133e1 "submitAttack(uint256,uint256)" TARGET_X TARGET_Y --rpc-url https://sandbox-rpc-testnet.appchain.base.org --private-key YOUR_PRIVATE_KEY
```

### Submit Defend Action

```bash
cast send 0x61c36a8d610163660E21a8b7359e1Cac0C9133e1 "submitDefend()" --rpc-url https://sandbox-rpc-testnet.appchain.base.org --private-key YOUR_PRIVATE_KEY
```

## Bot Management Commands

### Deploy a New Bot

```bash
cast send 0x0165878A594ca255338adfa4d48449f69242Eb8F "deployBot()" --rpc-url https://sandbox-rpc-testnet.appchain.base.org --private-key YOUR_PRIVATE_KEY
```

### Register a Bot for a Game

```bash
cast send BOT_ADDRESS "register(address)" GAME_ADDRESS --rpc-url https://sandbox-rpc-testnet.appchain.base.org --private-key YOUR_PRIVATE_KEY
```

### Set Bot Command

```bash
cast send BOT_ADDRESS "setNextCommand(address,uint256,uint8,uint8,uint256,uint256)" GAME_ADDRESS ROUND ACTION_TYPE DIRECTION TARGET_X TARGET_Y --rpc-url https://sandbox-rpc-testnet.appchain.base.org --private-key YOUR_PRIVATE_KEY
```

Where `ACTION_TYPE` is:
- 0: MOVE
- 1: ATTACK
- 2: DEFEND

### Execute Bot Action

```bash
cast send BOT_ADDRESS "executeAction(address)" GAME_ADDRESS --rpc-url https://sandbox-rpc-testnet.appchain.base.org --private-key YOUR_PRIVATE_KEY
```

## Query Commands

### Check Current Round

```bash
cast call 0x61c36a8d610163660E21a8b7359e1Cac0C9133e1 "currentRound()" --rpc-url https://sandbox-rpc-testnet.appchain.base.org
```

### Check Game State

```bash
cast call 0x61c36a8d610163660E21a8b7359e1Cac0C9133e1 "gameState()" --rpc-url https://sandbox-rpc-testnet.appchain.base.org
```

Game states:
- 0: INACTIVE
- 1: REGISTRATION
- 2: ACTIVE
- 3: COMPLETED

### Get Player Information

```bash
cast call 0x61c36a8d610163660E21a8b7359e1Cac0C9133e1 "getPlayer(uint256,address)" ROUND PLAYER_ADDRESS --rpc-url https://sandbox-rpc-testnet.appchain.base.org
```

### Get All Players in a Round

```bash
cast call 0x61c36a8d610163660E21a8b7359e1Cac0C9133e1 "getPlayers(uint256)" ROUND --rpc-url https://sandbox-rpc-testnet.appchain.base.org
```

### Get Alive Players

```bash
cast call 0x61c36a8d610163660E21a8b7359e1Cac0C9133e1 "getAlivePlayers()" --rpc-url https://sandbox-rpc-testnet.appchain.base.org
```

### Get Player at Position

```bash
cast call 0x61c36a8d610163660E21a8b7359e1Cac0C9133e1 "getPlayerAtPosition(uint256,uint256,uint256)" ROUND X Y --rpc-url https://sandbox-rpc-testnet.appchain.base.org
```

### Get Registration Deadline

```bash
cast call 0x61c36a8d610163660E21a8b7359e1Cac0C9133e1 "registrationDeadline()" --rpc-url https://sandbox-rpc-testnet.appchain.base.org
```

### Get Winner

```bash
cast call 0x61c36a8d610163660E21a8b7359e1Cac0C9133e1 "winner()" --rpc-url https://sandbox-rpc-testnet.appchain.base.org
```

## Factory Commands

### Deploy a New Game

```bash
cast send 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707 "deployGame()" --rpc-url https://sandbox-rpc-testnet.appchain.base.org --private-key YOUR_PRIVATE_KEY
```

### Get All Deployed Games

```bash
cast call 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707 "getDeployedGames()" --rpc-url https://sandbox-rpc-testnet.appchain.base.org
```

### Get Rewards Contract for a Game

```bash
cast call 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707 "getRewardsContract(address)" GAME_ADDRESS --rpc-url https://sandbox-rpc-testnet.appchain.base.org
```

## Notes

- Replace `YOUR_PRIVATE_KEY` with your actual private key
- For testing, you can use the default anvil private key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
- Replace `BOT_ADDRESS`, `GAME_ADDRESS`, `ROUND`, `PLAYER_ADDRESS`, `X`, `Y`, etc. with actual values
- The game requires at least 2 players to start
