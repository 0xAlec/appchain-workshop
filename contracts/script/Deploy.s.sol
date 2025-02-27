// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BattleRoyaleFactory.sol";
import "../src/BattleRoyale.sol";

contract DeployScript is Script {
    function run() external {
        // Use a hardcoded private key for testing
        // This is the default anvil private key, do not use in production
        uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the battle royale factory
        BattleRoyaleFactory battleRoyaleFactory = new BattleRoyaleFactory();
        
        // Log the addresses
        console.log("BattleRoyaleFactory deployed at:", address(battleRoyaleFactory));
        
        // Deploy a sample game
        address gameAddress = battleRoyaleFactory.deployGame();
        console.log("Sample game deployed at:", gameAddress);
        
        // Get the rewards contract for the sample game
        address rewardsAddress = battleRoyaleFactory.getRewardsContract(gameAddress);
        console.log("Sample game rewards contract deployed at:", rewardsAddress);
        
        // Create a round with a long registration period (1000 blocks, ~4 hours on Base)
        BattleRoyale game = BattleRoyale(gameAddress);
        game.createRound(1000);
        console.log("Created a round with 1000 blocks for registration");
        console.log("Current round:", game.currentRound());
        console.log("Registration deadline (block):", game.registrationDeadline());
        
        vm.stopBroadcast();
    }
} 