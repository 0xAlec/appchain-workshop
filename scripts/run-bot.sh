#!/bin/bash

# This script submits random actions for a player in the BattleRoyale game every 1 second
# Usage: ./run-bot.sh <battle_royale_address> [private_key]

# Check if battle royale address is provided
if [ -z "$1" ]; then
  echo "Usage: ./run-bot.sh <battle_royale_address> [private_key]"
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

# Get the player's address from the private key
PLAYER_ADDRESS=$(cast wallet address --private-key $PRIVATE_KEY)
echo "Bot player address: $PLAYER_ADDRESS"

# Check current game state
GAME_STATE=$(cast call $BATTLE_ADDRESS "gameState()" --rpc-url $RPC_URL | sed 's/^0x//')
echo "Current game state: $GAME_STATE"
# 0=INACTIVE, 1=REGISTRATION, 2=ACTIVE, 3=COMPLETED

# Convert hex state to decimal for easier comparison
GAME_STATE_DEC=$((16#$GAME_STATE))
echo "Game state (decimal): $GAME_STATE_DEC"

# Check if we need to register
if [ "$GAME_STATE_DEC" = "1" ]; then
  # Check if player is already registered
  PLAYER_INFO=$(cast call $BATTLE_ADDRESS "getPlayer(uint256,address)" $(cast call $BATTLE_ADDRESS "currentRound()" --rpc-url $RPC_URL) $PLAYER_ADDRESS --rpc-url $RPC_URL)
  
  # Check if player address in the returned data is zero address
  if [[ $PLAYER_INFO == *"0000000000000000000000000000000000000000"* ]]; then
    echo "Player not registered. Registering now..."
    cast send $BATTLE_ADDRESS "register()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL
    echo "Player registered!"
  else
    echo "Player already registered."
  fi
  
  echo "Waiting for game to start..."
  exit 0
fi

# Check if game is not active
if [ "$GAME_STATE_DEC" != "2" ]; then
  echo "Game is not active. Current state: $GAME_STATE_DEC"
  echo "Please start the game first or wait for it to be in active state."
  exit 0
fi

# Check if player is registered for the current round
CURRENT_ROUND=$(cast call $BATTLE_ADDRESS "currentRound()" --rpc-url $RPC_URL)
echo "Current round: $CURRENT_ROUND"

# Register if not already registered
echo "Checking if player is registered..."
PLAYER_HEALTH=$(cast call $BATTLE_ADDRESS "players(uint256,address)" $CURRENT_ROUND $PLAYER_ADDRESS --rpc-url $RPC_URL | grep -o "uint256 health: [0-9]*" | awk '{print $3}')

if [ -z "$PLAYER_HEALTH" ] || [ "$PLAYER_HEALTH" = "0" ]; then
  echo "Player not registered or has 0 health. Trying to register..."
  cast send $BATTLE_ADDRESS "register()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL || {
    echo "Failed to register. Game might be in active state already."
  }
else
  echo "Player is registered with health: $PLAYER_HEALTH"
fi

echo "Starting bot to submit random actions every 1 second..."

# Bot loop - submit random actions until the game ends
BOT_RUNNING=true
CONSECUTIVE_ERRORS=0
MAX_CONSECUTIVE_ERRORS=5

while [ "$BOT_RUNNING" = true ]; do
  # Get current game state
  GAME_STATE=$(cast call $BATTLE_ADDRESS "gameState()" --rpc-url $RPC_URL | sed 's/^0x//')
  GAME_STATE_DEC=$((16#$GAME_STATE))
  
  # Check if game has ended (state 3 = COMPLETED)
  if [ "$GAME_STATE_DEC" = "3" ]; then
    BOT_RUNNING=false
    WINNER=$(cast call $BATTLE_ADDRESS "winner()" --rpc-url $RPC_URL)
    echo "Game ended! Winner: $WINNER"
    if [ "$WINNER" = "$PLAYER_ADDRESS" ]; then
      echo "Congratulations! Your bot won the game!"
    fi
    exit 0
  fi
  
  # Check if game is still active
  if [ "$GAME_STATE_DEC" != "2" ]; then
    echo "Game is no longer active. Current state: $GAME_STATE_DEC"
    exit 0
  fi
  
  # Check if player is still alive by checking health
  PLAYER_HEALTH=$(cast call $BATTLE_ADDRESS "players(uint256,address)" $CURRENT_ROUND $PLAYER_ADDRESS --rpc-url $RPC_URL | grep -o "uint256 health: [0-9]*" | awk '{print $3}')
  PLAYER_ALIVE=$(cast call $BATTLE_ADDRESS "players(uint256,address)" $CURRENT_ROUND $PLAYER_ADDRESS --rpc-url $RPC_URL | grep -o "bool isAlive: [a-z]*" | awk '{print $3}')
  
  echo "Player health: $PLAYER_HEALTH, isAlive: $PLAYER_ALIVE"
  
  if [ "$PLAYER_ALIVE" = "false" ] || [ -z "$PLAYER_ALIVE" ] || [ "$PLAYER_HEALTH" = "0" ] || [ -z "$PLAYER_HEALTH" ]; then
    echo "Player has been eliminated or not registered!"
    exit 0
  fi
  
  # Get player position
  PLAYER_X=$(cast call $BATTLE_ADDRESS "players(uint256,address)" $CURRENT_ROUND $PLAYER_ADDRESS --rpc-url $RPC_URL | grep -o "uint256 x: [0-9]*" | awk '{print $3}')
  PLAYER_Y=$(cast call $BATTLE_ADDRESS "players(uint256,address)" $CURRENT_ROUND $PLAYER_ADDRESS --rpc-url $RPC_URL | grep -o "uint256 y: [0-9]*" | awk '{print $3}')
  
  if [ -z "$PLAYER_X" ] || [ -z "$PLAYER_Y" ]; then
    echo "Could not determine player position. Player might not be registered."
    exit 0
  fi
  
  echo "Player position: ($PLAYER_X, $PLAYER_Y)"
  
  # Check if player has already submitted an action for this block
  ACTION_SUBMITTED=$(cast call $BATTLE_ADDRESS "players(uint256,address)" $CURRENT_ROUND $PLAYER_ADDRESS --rpc-url $RPC_URL | grep -o "bool actionSubmittedForBlock: [a-z]*" | awk '{print $3}')
  
  if [ "$ACTION_SUBMITTED" = "true" ]; then
    echo "Action already submitted for this block. Waiting for next block..."
    sleep 1
    continue
  fi
  
  # Generate a random action (0=MOVE, 1=ATTACK, 2=DEFEND)
  ACTION_TYPE=$((RANDOM % 3))
  
  if [ "$ACTION_TYPE" = "0" ]; then
    # Move action - random direction (0=UP, 1=DOWN, 2=LEFT, 3=RIGHT)
    DIRECTION=$((RANDOM % 4))
    echo "Submitting MOVE action (direction: $DIRECTION)..."
    
    # Try to submit the action
    cast send $BATTLE_ADDRESS "submitMove(uint8)" $DIRECTION --private-key $PRIVATE_KEY --rpc-url $RPC_URL && {
      echo "Move action submitted successfully!"
      CONSECUTIVE_ERRORS=0
    } || {
      echo "Failed to submit move action."
      CONSECUTIVE_ERRORS=$((CONSECUTIVE_ERRORS + 1))
    }
    
  elif [ "$ACTION_TYPE" = "1" ]; then
    # Attack action - random position near the player
    # Generate random offset (-1, 0, or 1) for X and Y
    X_OFFSET=$(( (RANDOM % 3) - 1 ))
    Y_OFFSET=$(( (RANDOM % 3) - 1 ))
    
    # Calculate target position
    TARGET_X=$((PLAYER_X + X_OFFSET))
    TARGET_Y=$((PLAYER_Y + Y_OFFSET))
    
    # Ensure target is within map bounds (0 to MAP_SIZE-1)
    MAP_SIZE=$(cast call $BATTLE_ADDRESS "MAP_SIZE()" --rpc-url $RPC_URL)
    
    if [ "$TARGET_X" -lt 0 ]; then
      TARGET_X=0
    elif [ "$TARGET_X" -ge "$MAP_SIZE" ]; then
      TARGET_X=$((MAP_SIZE - 1))
    fi
    
    if [ "$TARGET_Y" -lt 0 ]; then
      TARGET_Y=0
    elif [ "$TARGET_Y" -ge "$MAP_SIZE" ]; then
      TARGET_Y=$((MAP_SIZE - 1))
    fi
    
    echo "Submitting ATTACK action (target: $TARGET_X, $TARGET_Y)..."
    
    # Try to submit the action
    cast send $BATTLE_ADDRESS "submitAttack(uint256,uint256)" $TARGET_X $TARGET_Y --private-key $PRIVATE_KEY --rpc-url $RPC_URL && {
      echo "Attack action submitted successfully!"
      CONSECUTIVE_ERRORS=0
    } || {
      echo "Failed to submit attack action."
      CONSECUTIVE_ERRORS=$((CONSECUTIVE_ERRORS + 1))
    }
    
  else
    # Defend action
    echo "Submitting DEFEND action..."
    
    # Try to submit the action
    cast send $BATTLE_ADDRESS "submitDefend()" --private-key $PRIVATE_KEY --rpc-url $RPC_URL && {
      echo "Defend action submitted successfully!"
      CONSECUTIVE_ERRORS=0
    } || {
      echo "Failed to submit defend action."
      CONSECUTIVE_ERRORS=$((CONSECUTIVE_ERRORS + 1))
    }
  fi
  
  # Check if we've had too many consecutive errors
  if [ $CONSECUTIVE_ERRORS -ge $MAX_CONSECUTIVE_ERRORS ]; then
    echo "Too many consecutive errors ($CONSECUTIVE_ERRORS). Exiting."
    exit 1
  fi
  
  # Wait 1 second before next action
  sleep 1
done

echo "Bot stopped!" 