#!/bin/bash

# This script starts a round for an existing BattleRoyale contract and calls executeActions() in a loop until the game ends
# Usage: ./battle-loop.sh <battle_royale_address> [private_key]

# Check if battle royale address is provided
if [ -z "$1" ]; then
  echo "Usage: ./battle-loop.sh <battle_royale_address> [private_key]"
  exit 1
fi

BATTLE_ADDRESS=$1

# Get private key from second argument or from .env file
if [ -n "$2" ]; then
  PRIVATE_KEY=$2
else
  # Try to read from .env file
  if [ -f ".env" ]; then
    PRIVATE_KEY=$(grep PRIVATE_KEY .env | cut -d '=' -f2)
  fi
  
  # If still empty, try to read from contracts/.env
  if [ -z "$PRIVATE_KEY" ] && [ -f "contracts/.env" ]; then
    PRIVATE_KEY=$(grep PRIVATE_KEY contracts/.env | cut -d '=' -f2)
  fi
  
  # If still empty, prompt user
  if [ -z "$PRIVATE_KEY" ]; then
    echo "Private key not found in .env file."
    echo "Please enter your private key (without 0x prefix):"
    read -s PRIVATE_KEY
  fi
fi

# Ensure private key doesn't have 0x prefix for cast
PRIVATE_KEY=$(echo $PRIVATE_KEY | sed 's/^0x//')

# Use RPC_URL environment variable
echo "Using RPC URL: $RPC_URL"

# Check current game state
GAME_STATE=$(cast call $BATTLE_ADDRESS "gameState()" --rpc-url $RPC_URL | sed 's/^0x//')
echo "Current game state: $GAME_STATE"
# 0=INACTIVE, 1=REGISTRATION, 2=ACTIVE, 3=COMPLETED

# Check if we need to create a round
if [ "$GAME_STATE" = "0" ]; then
  echo "Game is inactive. Creating a new round..."
  cast send $BATTLE_ADDRESS "createRound(uint256)" 10 --private-key $PRIVATE_KEY --rpc-url $RPC_URL
  echo "Round created. Please register players and then run this script again."
  exit 0
fi

# Check if we're in registration phase
if [ "$GAME_STATE" = "1" ]; then
  # Get player count
  PLAYER_COUNT=$(cast call $BATTLE_ADDRESS "getAlivePlayerCount()" --rpc-url $RPC_URL)
  echo "Currently $PLAYER_COUNT players registered."
  
  if [ "$PLAYER_COUNT" = "0" ]; then
    echo "No players registered yet. Please register players and then run this script again."
    exit 0
  fi
  
  echo "Starting the game..."
  cast send $BATTLE_ADDRESS "startGame()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL
  echo "Game started!"
fi

# Check if game is already completed
if [ "$GAME_STATE" = "3" ]; then
  WINNER=$(cast call $BATTLE_ADDRESS "winner()" --rpc-url $RPC_URL)
  echo "Game is already completed. Winner: $WINNER"
  exit 0
fi

echo "Executing actions every 1 second until the game ends..."

# Game loop - execute actions until the game ends
GAME_ENDED=false
CONSECUTIVE_ZEROS=0
MAX_CONSECUTIVE_ZEROS=5

while [ "$GAME_ENDED" = false ]; do
  # Get current game state
  GAME_STATE=$(cast call $BATTLE_ADDRESS "gameState()" --rpc-url $RPC_URL | sed 's/^0x//')
  
  # Check if game has ended (state 3 = COMPLETED)
  if [ "$GAME_STATE" = "3" ]; then
    GAME_ENDED=true
    WINNER=$(cast call $BATTLE_ADDRESS "winner()" --rpc-url $RPC_URL)
    echo "Game ended! Winner: $WINNER"
  else
    # Get alive player count before executing actions
    ALIVE_COUNT=$(cast call $BATTLE_ADDRESS "getAlivePlayerCount()" --rpc-url $RPC_URL)
    
    if [ "$ALIVE_COUNT" = "0" ]; then
      CONSECUTIVE_ZEROS=$((CONSECUTIVE_ZEROS + 1))
      echo "Warning: No alive players detected ($CONSECUTIVE_ZEROS/$MAX_CONSECUTIVE_ZEROS)"
      
      if [ $CONSECUTIVE_ZEROS -ge $MAX_CONSECUTIVE_ZEROS ]; then
        echo "No players detected for $MAX_CONSECUTIVE_ZEROS consecutive checks. Exiting."
        exit 1
      fi
    else
      CONSECUTIVE_ZEROS=0
    fi
    
    # Try to execute actions
    echo "Executing actions..."
    cast send $BATTLE_ADDRESS "executeActions()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL
    
    # Get alive player count after executing actions
    ALIVE_COUNT=$(cast call $BATTLE_ADDRESS "getAlivePlayerCount()" --rpc-url $RPC_URL)
    echo "Alive players: $ALIVE_COUNT"
    
    # Wait 1 second before next execution
    sleep 1
  fi
done

echo "Game loop completed!" 