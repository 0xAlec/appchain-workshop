# Battle Royale Game

A blockchain-based battle royale game where players control bots to fight until only one remains.

## Overview

This project consists of:

1. Smart contracts for the battle royale game
2. Smart contracts for offchain-controlled bots
3. Scripts for deploying and interacting with the contracts
4. A Node.js script for controlling bots from offchain

## Smart Contracts

### BattleRoyale

The main game contract where players register and compete.

### BattleRoyaleFactory

Factory contract to deploy new battle royale games.

### BattleRoyaleRewards

Contract to handle rewards for game winners.

### OffchainBot

Bot contract that receives commands from offchain instead of calculating them onchain.

### BotFactory

Factory contract to deploy new bots.

## Development

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (for the bot controller script)

### Installation

1. Clone the repository
2. Install dependencies:

```bash
forge install
npm install
```

3. Copy the example environment file:

```bash
cp .env.example .env
```

4. Edit the `.env` file with your own values.

### Deployment

Deploy the contracts using Foundry:

```bash
forge script contracts/script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Bot Controller

The bot controller script allows you to interact with your bot from offchain.

#### Commands

1. Register your bot for a game:

```bash
node scripts/bot-controller.js register
```

2. Set a command for your bot:

```bash
# Move UP
node scripts/bot-controller.js set-command 0 0

# Move DOWN
node scripts/bot-controller.js set-command 0 1

# Move LEFT
node scripts/bot-controller.js set-command 0 2

# Move RIGHT
node scripts/bot-controller.js set-command 0 3

# Attack at position (x, y)
node scripts/bot-controller.js set-command 1 0 5 7

# Defend
node scripts/bot-controller.js set-command 2 0 0 0
```

3. Execute your bot's action:

```bash
node scripts/bot-controller.js execute
```

4. Monitor the game:

```bash
node scripts/bot-controller.js monitor
```

## Game Flow

1. Deploy a new game using the BattleRoyaleFactory
2. Deploy a new bot using the BotFactory
3. Register your bot for the game
4. Wait for the game to start
5. Set commands for your bot from offchain
6. Execute your bot's actions
7. Monitor the game to see what's happening

## UI Integration

The contracts are designed to work with a UI that displays the owner's bot. The UI can:

1. Show the current state of the game
2. Display the bot's position and health
3. Allow the owner to set commands for their bot
4. Execute the bot's actions

A script running on the host can:

1. Get the latest block updates
2. Call the bot for its next action
3. Monitor events from the game

## License

MIT
