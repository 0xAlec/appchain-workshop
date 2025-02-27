// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BattleRoyale.sol";
import "../src/BattleRoyaleFactory.sol";

contract GameLoopScript is Script {
    function run() external {
        // Use a hardcoded private key for testing
        // This is the default anvil private key, do not use in production
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        
        // Step 1: Deploy the battle royale factory
        vm.startBroadcast(deployerPrivateKey);
        BattleRoyaleFactory battleRoyaleFactory = new BattleRoyaleFactory();
        console.log("BattleRoyaleFactory deployed at:", address(battleRoyaleFactory));
        
        // Step 2: Create a new game
        address gameAddress = battleRoyaleFactory.deployGame();
        console.log("Game deployed at:", gameAddress);
        BattleRoyale game = BattleRoyale(gameAddress);
        
        // Step 3: Create a new round with 10 blocks for registration
        game.createRound(10);
        console.log("Round created with 10 blocks for registration");
        
        // Step 4: Start the game (in a real scenario, you'd wait for players to register)
        game.startGame();
        console.log("Game started");
        
        // Step 5: Game loop - execute actions until the game ends
        bool gameEnded = false;
        
        while (!gameEnded) {
            // Sleep for 1 second (simulate time passing)
            vm.warp(block.timestamp + 1);
            vm.roll(block.number + 1);
            
            // Execute all pending actions if enough time has passed
            if (block.number >= game.lastExecutedBlock() + game.BLOCK_INTERVAL()) {
                try game.executeActions() {
                    console.log("Actions executed at block %d", block.number);
                    
                    // Check if game has ended
                    if (game.gameState() == BattleRoyale.GameState.COMPLETED) {
                        gameEnded = true;
                        console.log("Game ended! Winner: %s", game.winner());
                    }
                    else {
                        // Log alive player count
                        console.log("Alive players: %d", game.getAlivePlayerCount());
                    }
                } catch {
                    console.log("No actions to execute");
                }
            }
        }
        
        vm.stopBroadcast();
    }
    
    // Function to create a new round for an existing game
    function createRound(address gameAddress) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        BattleRoyale game = BattleRoyale(gameAddress);
        game.createRound(10); // 10 blocks for registration
        
        console.log("Round created with 10 blocks for registration");
        console.log("Current round:", game.currentRound());
        console.log("Registration deadline (block):", game.registrationDeadline());
        
        vm.stopBroadcast();
    }
    
    // Function to start the game
    function startGame(address gameAddress) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        BattleRoyale game = BattleRoyale(gameAddress);
        game.startGame();
        
        console.log("Game started");
        console.log("Game state:", uint(game.gameState()));
        console.log("Game start block:", game.gameStartBlock());
        
        vm.stopBroadcast();
    }
    
    // Function to execute actions and check game state
    function executeAndCheckGameState(address gameAddress) external returns (bool) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        BattleRoyale game = BattleRoyale(gameAddress);
        bool gameEnded = false;
        
        // Execute all pending actions if enough time has passed
        if (block.number >= game.lastExecutedBlock() + game.BLOCK_INTERVAL()) {
            try game.executeActions() {
                console.log("Actions executed at block %d", block.number);
                
                // Check if game has ended
                if (game.gameState() == BattleRoyale.GameState.COMPLETED) {
                    gameEnded = true;
                    console.log("Game ended! Winner: %s", game.winner());
                }
                else {
                    // Log alive player count
                    console.log("Alive players: %d", game.getAlivePlayerCount());
                }
            } catch {
                console.log("No actions to execute");
            }
        } else {
            console.log("Not time to execute actions yet. Waiting for block %d (current: %d)", 
                game.lastExecutedBlock() + game.BLOCK_INTERVAL(), 
                block.number);
        }
        
        vm.stopBroadcast();
        return gameEnded;
    }
} 