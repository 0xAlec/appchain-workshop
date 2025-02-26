// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BattleRoyale.sol";
import "./IBattleRoyaleBot.sol";

/**
 * @title OffchainBot
 * @dev A bot implementation that receives commands from offchain
 */
contract OffchainBot is IBattleRoyaleBot {
    address public owner;
    
    // Offchain command storage
    struct Command {
        uint8 actionType;
        uint8 direction;
        uint256 targetX;
        uint256 targetY;
        bool isSet;
    }
    
    // Store commands for each game and round
    mapping(address => mapping(uint256 => Command)) public commands;
    
    // Events
    event CommandSet(address indexed game, uint256 indexed round, uint8 actionType, uint8 direction, uint256 targetX, uint256 targetY);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Set the next command for a specific game and round
     * @param _game Address of the battle royale game
     * @param _round Current round number
     * @param _actionType The type of action (0=MOVE, 1=ATTACK, 2=DEFEND)
     * @param _direction Direction to move (0=UP, 1=DOWN, 2=LEFT, 3=RIGHT)
     * @param _targetX X coordinate of the target for attack
     * @param _targetY Y coordinate of the target for attack
     */
    function setNextCommand(
        address _game,
        uint256 _round,
        uint8 _actionType,
        uint8 _direction,
        uint256 _targetX,
        uint256 _targetY
    ) external onlyOwner {
        commands[_game][_round] = Command({
            actionType: _actionType,
            direction: _direction,
            targetX: _targetX,
            targetY: _targetY,
            isSet: true
        });
        
        emit CommandSet(_game, _round, _actionType, _direction, _targetX, _targetY);
    }
    
    /**
     * @dev Get the next action for the bot
     * @param _game Address of the battle royale game
     * @param _round Current round number
     * @return actionType The type of action (0=MOVE, 1=ATTACK, 2=DEFEND)
     * @return direction Direction to move (0=UP, 1=DOWN, 2=LEFT, 3=RIGHT)
     * @return targetX X coordinate of the target for attack
     * @return targetY Y coordinate of the target for attack
     */
    function getNextAction(
        address _game,
        uint256 _round
    ) external view override returns (
        uint8 actionType,
        uint8 direction,
        uint256 targetX,
        uint256 targetY
    ) {
        Command memory cmd = commands[_game][_round];
        
        // If no command is set, default to defend
        if (!cmd.isSet) {
            return (2, 0, 0, 0); // Default to DEFEND
        }
        
        return (cmd.actionType, cmd.direction, cmd.targetX, cmd.targetY);
    }
    
    /**
     * @dev Execute the next action for the bot
     * @param _game Address of the battle royale game
     */
    function executeAction(address _game) external override {
        BattleRoyale game = BattleRoyale(_game);
        uint256 round = game.currentRound();
        
        // Get the next action
        (uint8 actionType, uint8 direction, uint256 targetX, uint256 targetY) = this.getNextAction(_game, round);
        
        // Execute the action
        if (actionType == 0) { // MOVE
            game.submitMove(BattleRoyale.Direction(direction));
        } else if (actionType == 1) { // ATTACK
            game.submitAttack(targetX, targetY);
        } else if (actionType == 2) { // DEFEND
            game.submitDefend();
        }
    }
    
    /**
     * @dev Register the bot for a game
     * @param _game Address of the battle royale game
     */
    function register(address _game) external onlyOwner {
        BattleRoyale game = BattleRoyale(_game);
        game.register();
    }
    
    /**
     * @dev Get the current game state for offchain processing
     * @param _game Address of the battle royale game
     * @return round Current round number
     * @return mapSize Size of the game map
     * @return blockInterval Number of blocks between action executions
     * @return timeUntilNextExecution Time until the next action execution
     * @return gameMap 2D array representing the game map
     * @return alivePlayers Array of alive player addresses
     * @return myX Bot's X coordinate
     * @return myY Bot's Y coordinate
     * @return myHealth Bot's current health
     */
    function getGameState(address _game) external view returns (
        uint256 round,
        uint256 mapSize,
        uint256 blockInterval,
        uint256 timeUntilNextExecution,
        address[][] memory gameMap,
        address[] memory alivePlayers,
        uint256 myX,
        uint256 myY,
        uint256 myHealth
    ) {
        BattleRoyale game = BattleRoyale(_game);
        
        round = game.currentRound();
        mapSize = game.MAP_SIZE();
        blockInterval = game.BLOCK_INTERVAL();
        timeUntilNextExecution = game.getTimeUntilNextExecution();
        
        // Get the game map
        gameMap = game.getGameMap();
        
        // Get alive players
        alivePlayers = game.getAlivePlayers();
        
        // Get my position and health
        BattleRoyale.Player memory player = game.getPlayer(round, address(this));
        myX = player.x;
        myY = player.y;
        myHealth = player.health;
        
        return (round, mapSize, blockInterval, timeUntilNextExecution, gameMap, alivePlayers, myX, myY, myHealth);
    }
    
    /**
     * @dev Withdraw any ETH sent to this contract
     */
    function withdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    /**
     * @dev Transfer ownership
     * @param _newOwner New owner address
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        owner = _newOwner;
    }
    
    /**
     * @dev Allow the contract to receive ETH
     */
    receive() external payable {}
} 