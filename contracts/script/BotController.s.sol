// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/OffchainBot.sol";
import "../src/BattleRoyale.sol";

contract BotControllerScript is Script {
    function setBotCommand(
        address botAddress,
        address gameAddress,
        uint8 actionType,
        uint8 direction,
        uint256 targetX,
        uint256 targetY
    ) external {
        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(ownerPrivateKey);
        
        // Get the current round from the game
        BattleRoyale game = BattleRoyale(gameAddress);
        uint256 currentRound = game.currentRound();
        
        // Set the command for the bot
        OffchainBot bot = OffchainBot(payable(botAddress));
        bot.setNextCommand(gameAddress, currentRound, actionType, direction, targetX, targetY);
        
        console.log("Command set for bot:", botAddress);
        console.log("Game:", gameAddress);
        console.log("Round:", currentRound);
        console.log("Action Type:", actionType);
        console.log("Direction:", direction);
        console.log("Target X:", targetX);
        console.log("Target Y:", targetY);
        
        vm.stopBroadcast();
    }
    
    function executeBot(address botAddress, address gameAddress) external {
        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(ownerPrivateKey);
        
        // Execute the bot's action
        OffchainBot bot = OffchainBot(payable(botAddress));
        bot.executeAction(gameAddress);
        
        console.log("Bot action executed for bot:", botAddress);
        console.log("Game:", gameAddress);
        
        vm.stopBroadcast();
    }
    
    function registerBot(address botAddress, address gameAddress) external {
        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(ownerPrivateKey);
        
        // Register the bot for the game
        OffchainBot bot = OffchainBot(payable(botAddress));
        bot.register(gameAddress);
        
        console.log("Bot registered for game:", gameAddress);
        console.log("Bot address:", botAddress);
        
        vm.stopBroadcast();
    }
} 