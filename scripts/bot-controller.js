#!/usr/bin/env node

const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

// Load ABI files
const loadAbi = (contractName) => {
  const abiPath = path.join(__dirname, '..', 'contracts', 'out', contractName + '.sol', contractName + '.json');
  const contractJson = JSON.parse(fs.readFileSync(abiPath, 'utf8'));
  return contractJson.abi;
};

// Contract ABIs
const offchainBotAbi = loadAbi('OffchainBot');
const battleRoyaleAbi = loadAbi('BattleRoyale');

// Configuration
const provider = new ethers.providers.JsonRpcProvider(process.env.RPC_URL);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

// Contract addresses (to be set by user)
const BOT_ADDRESS = process.env.BOT_ADDRESS;
const GAME_ADDRESS = process.env.GAME_ADDRESS;

// Contract instances
const botContract = new ethers.Contract(BOT_ADDRESS, offchainBotAbi, wallet);
const gameContract = new ethers.Contract(GAME_ADDRESS, battleRoyaleAbi, wallet);

// Action types
const ACTION_TYPES = {
  MOVE: 0,
  ATTACK: 1,
  DEFEND: 2
};

// Direction types
const DIRECTIONS = {
  UP: 0,
  DOWN: 1,
  LEFT: 2,
  RIGHT: 3
};

// Main function
async function main() {
  const command = process.argv[2];
  
  if (!command) {
    console.log('Please provide a command: register, set-command, execute, or monitor');
    process.exit(1);
  }
  
  try {
    switch (command) {
      case 'register':
        await registerBot();
        break;
      case 'set-command':
        await setCommand();
        break;
      case 'execute':
        await executeBot();
        break;
      case 'monitor':
        await monitorGame();
        break;
      default:
        console.log('Unknown command. Available commands: register, set-command, execute, monitor');
    }
  } catch (error) {
    console.error('Error:', error);
  }
}

// Register the bot for a game
async function registerBot() {
  console.log(`Registering bot ${BOT_ADDRESS} for game ${GAME_ADDRESS}...`);
  const tx = await botContract.register(GAME_ADDRESS);
  await tx.wait();
  console.log('Bot registered successfully!');
}

// Set a command for the bot
async function setCommand() {
  const actionType = parseInt(process.argv[3] || '0');
  const direction = parseInt(process.argv[4] || '0');
  const targetX = parseInt(process.argv[5] || '0');
  const targetY = parseInt(process.argv[6] || '0');
  
  console.log(`Setting command for bot ${BOT_ADDRESS}...`);
  console.log(`Action Type: ${actionType} (${Object.keys(ACTION_TYPES).find(key => ACTION_TYPES[key] === actionType)})`);
  if (actionType === ACTION_TYPES.MOVE) {
    console.log(`Direction: ${direction} (${Object.keys(DIRECTIONS).find(key => DIRECTIONS[key] === direction)})`);
  } else if (actionType === ACTION_TYPES.ATTACK) {
    console.log(`Target: (${targetX}, ${targetY})`);
  }
  
  const currentRound = await gameContract.currentRound();
  
  const tx = await botContract.setNextCommand(
    GAME_ADDRESS,
    currentRound,
    actionType,
    direction,
    targetX,
    targetY
  );
  await tx.wait();
  console.log('Command set successfully!');
}

// Execute the bot's action
async function executeBot() {
  console.log(`Executing action for bot ${BOT_ADDRESS} in game ${GAME_ADDRESS}...`);
  const tx = await botContract.executeAction(GAME_ADDRESS);
  await tx.wait();
  console.log('Action executed successfully!');
}

// Monitor the game for updates
async function monitorGame() {
  console.log(`Monitoring game ${GAME_ADDRESS}...`);
  
  // Get current round
  const currentRound = await gameContract.currentRound();
  console.log(`Current Round: ${currentRound}`);
  
  // Get game state
  const gameState = await gameContract.gameState();
  const gameStates = ['INACTIVE', 'REGISTRATION', 'ACTIVE', 'COMPLETED'];
  console.log(`Game State: ${gameStates[gameState]}`);
  
  // Get bot's player info
  try {
    const player = await gameContract.players(currentRound, BOT_ADDRESS);
    console.log('Bot Player Info:');
    console.log(`  Position: (${player.x}, ${player.y})`);
    console.log(`  Health: ${player.health}`);
    console.log(`  Is Alive: ${player.isAlive}`);
    console.log(`  Last Action Block: ${player.lastActionBlock}`);
  } catch (error) {
    console.log('Bot is not registered for this game or round');
  }
  
  // Setup event listeners
  console.log('\nListening for events...');
  
  gameContract.on('PlayerMoved', (round, player, fromX, fromY, toX, toY) => {
    if (player.toLowerCase() === BOT_ADDRESS.toLowerCase()) {
      console.log(`[Event] Bot moved from (${fromX}, ${fromY}) to (${toX}, ${toY})`);
    }
  });
  
  gameContract.on('PlayerAttacked', (round, attacker, target, damage, targetRemainingHealth) => {
    if (attacker.toLowerCase() === BOT_ADDRESS.toLowerCase()) {
      console.log(`[Event] Bot attacked ${target}, dealing ${damage} damage. Target health: ${targetRemainingHealth}`);
    } else if (target.toLowerCase() === BOT_ADDRESS.toLowerCase()) {
      console.log(`[Event] Bot was attacked by ${attacker}, taking ${damage} damage. Remaining health: ${targetRemainingHealth}`);
    }
  });
  
  gameContract.on('PlayerDefended', (round, player) => {
    if (player.toLowerCase() === BOT_ADDRESS.toLowerCase()) {
      console.log(`[Event] Bot defended`);
    }
  });
  
  gameContract.on('PlayerEliminated', (round, player) => {
    if (player.toLowerCase() === BOT_ADDRESS.toLowerCase()) {
      console.log(`[Event] Bot was eliminated!`);
    } else {
      console.log(`[Event] Player ${player} was eliminated`);
    }
  });
  
  gameContract.on('GameEnded', (round, winner) => {
    if (winner.toLowerCase() === BOT_ADDRESS.toLowerCase()) {
      console.log(`[Event] Bot won the game!`);
    } else {
      console.log(`[Event] Game ended. Winner: ${winner}`);
    }
  });
  
  // Keep the process running
  console.log('Press Ctrl+C to stop monitoring');
  process.stdin.resume();
}

// Run the main function
main().catch(error => {
  console.error(error);
  process.exit(1);
}); 