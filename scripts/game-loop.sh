#!/bin/bash

# This script starts a game and calls executeActions() in a loop until the game ends
# Usage: ./game-loop.sh <game_address>

# Check if game address is provided
if [ -z "$1" ]; then
  echo "Usage: ./game-loop.sh <game_address>"
  exit 1
fi

GAME_ADDRESS=$1
PRIVATE_KEY=$(grep PRIVATE_KEY .env | cut -d '=' -f2)

# Change to the contracts directory
cd contracts

# Create a new round with 10 blocks for registration
echo "Creating a new round..."
forge script script/GameLoop.s.sol:GameLoopScript --sig "createRound(address)" $GAME_ADDRESS --private-key $PRIVATE_KEY --broadcast

# Wait for registration period (in a real scenario, you'd wait for players to register)
echo "Waiting for registration period (10 seconds)..."
sleep 10

# Start the game
echo "Starting the game..."
forge script script/GameLoop.s.sol:GameLoopScript --sig "startGame(address)" $GAME_ADDRESS --private-key $PRIVATE_KEY --broadcast

echo "Game started! Executing actions every 1 second until the game ends..."

# Game loop - execute actions until the game ends
GAME_ENDED=false
while [ "$GAME_ENDED" = false ]; do
  # Execute actions
  RESULT=$(forge script script/GameLoop.s.sol:GameLoopScript --sig "executeAndCheckGameState(address)" $GAME_ADDRESS --private-key $PRIVATE_KEY --broadcast)
  
  # Check if game has ended
  if echo "$RESULT" | grep -q "Game ended"; then
    GAME_ENDED=true
    WINNER=$(echo "$RESULT" | grep "Winner:" | awk '{print $2}')
    echo "Game ended! Winner: $WINNER"
  else
    ALIVE_COUNT=$(echo "$RESULT" | grep "Alive players:" | awk '{print $3}')
    echo "Alive players: $ALIVE_COUNT"
    
    # Wait 1 second before next execution
    sleep 1
  fi
done

echo "Game loop completed!" 