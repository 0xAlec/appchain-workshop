// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BattleRoyale
 * @dev A battle royale game where players fight until only one remains
 */
contract BattleRoyale {
    // Game state enum
    enum GameState { INACTIVE, REGISTRATION, ACTIVE, COMPLETED }
    
    // Action types
    enum ActionType { MOVE, ATTACK, DEFEND }
    
    // Direction for movement
    enum Direction { UP, DOWN, LEFT, RIGHT }
    
    // Player struct
    struct Player {
        address addr;
        uint256 x;
        uint256 y;
        uint256 health;
        uint256 lastActionBlock;
        bool isAlive;
    }
    
    // Game configuration
    uint256 public constant MAP_SIZE = 20;
    uint256 public constant INITIAL_HEALTH = 100;
    uint256 public constant ATTACK_DAMAGE = 25;
    uint256 public constant DEFEND_REDUCTION = 10;
    uint256 public constant ATTACK_RANGE = 1;
    uint256 public constant DAMAGE_ZONE_DAMAGE = 50; // Damage from being in the damage zone (half health)
    uint256 public constant ZONE_SHRINK_INTERVAL = 15; // Zone shrinks every 15 seconds
    
    // Game state variables
    address public owner;
    GameState public gameState;
    uint256 public currentRound;
    uint256 public gameStartBlock;
    uint256 public registrationDeadline;
    uint256 public lastZoneShrinkTime;
    uint256 public currentSafeZoneSize;
    address public winner;
    
    // Player tracking
    mapping(uint256 => mapping(address => Player)) public players; // round -> address -> Player
    mapping(uint256 => address[]) public roundPlayers; // round -> player addresses
    mapping(uint256 => mapping(uint256 => mapping(uint256 => address))) public positionToPlayer; // round -> x -> y -> player address
    
    // Defending players in the current block
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public isDefending; // round -> block -> player -> isDefending
    
    // Events
    event RoundCreated(uint256 indexed round, uint256 registrationDeadline);
    event PlayerRegistered(uint256 indexed round, address indexed player, uint256 x, uint256 y);
    event GameStarted(uint256 indexed round, uint256 startBlock, uint256 playerCount);
    event PlayerMoved(uint256 indexed round, address indexed player, uint256 fromX, uint256 fromY, uint256 toX, uint256 toY);
    event PlayerAttacked(uint256 indexed round, address indexed attacker, address indexed target, uint256 damage, uint256 targetRemainingHealth);
    event PlayerDefended(uint256 indexed round, address indexed player);
    event PlayerEliminated(uint256 indexed round, address indexed player);
    event GameEnded(uint256 indexed round, address indexed winner);
    event ActionExecuted(uint256 indexed round, address indexed player, uint8 actionType);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ZoneShrunk(uint256 indexed round, uint256 newSafeZoneSize);
    event PlayerDamagedByZone(uint256 indexed round, address indexed player, uint256 damage, uint256 remainingHealth);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier inState(GameState _state) {
        require(gameState == _state, "Invalid game state");
        _;
    }
    
    modifier onlyRegistered() {
        require(players[currentRound][msg.sender].addr == msg.sender, "Player not registered");
        _;
    }
    
    modifier onlyAlive() {
        require(players[currentRound][msg.sender].isAlive, "Player is eliminated");
        _;
    }
    
    modifier oneActionPerBlock() {
        require(players[currentRound][msg.sender].lastActionBlock < block.number, "Already performed action in this block");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        gameState = GameState.INACTIVE;
        currentRound = 0;
    }
    
    /**
     * @dev Transfer ownership of the contract
     * @param _newOwner New owner address
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
    
    /**
     * @dev Create a new game round
     * @param _registrationPeriod Number of blocks for registration period
     */
    function createRound(uint256 _registrationPeriod) external onlyOwner inState(GameState.INACTIVE) {
        currentRound++;
        gameState = GameState.REGISTRATION;
        registrationDeadline = block.number + _registrationPeriod;
        
        emit RoundCreated(currentRound, registrationDeadline);
    }
    
    /**
     * @dev Register to play in the current round
     */
    function register() external inState(GameState.REGISTRATION) {
        require(block.number <= registrationDeadline, "Registration period ended");
        require(players[currentRound][msg.sender].addr == address(0), "Already registered");
        
        // Generate random starting position
        (uint256 x, uint256 y) = _getRandomPosition();
        
        // Ensure position is not already taken
        while (positionToPlayer[currentRound][x][y] != address(0)) {
            (x, y) = _getRandomPosition();
        }
        
        // Register player
        players[currentRound][msg.sender] = Player({
            addr: msg.sender,
            x: x,
            y: y,
            health: INITIAL_HEALTH,
            lastActionBlock: 0,
            isAlive: true
        });
        
        roundPlayers[currentRound].push(msg.sender);
        positionToPlayer[currentRound][x][y] = msg.sender;
        
        emit PlayerRegistered(currentRound, msg.sender, x, y);
    }
    
    /**
     * @dev Start the game
     */
    function startGame() external onlyOwner inState(GameState.REGISTRATION) {
        require(roundPlayers[currentRound].length >= 2, "Need at least 2 players");
        
        gameState = GameState.ACTIVE;
        gameStartBlock = block.number;
        lastZoneShrinkTime = block.timestamp;
        currentSafeZoneSize = MAP_SIZE; // Start with the full map as safe
        
        emit GameStarted(currentRound, gameStartBlock, roundPlayers[currentRound].length);
    }
    
    /**
     * @dev Move in a direction
     * @param _direction Direction to move (0=UP, 1=DOWN, 2=LEFT, 3=RIGHT)
     */
    function move(Direction _direction) external inState(GameState.ACTIVE) onlyRegistered onlyAlive oneActionPerBlock {
        // Check if it's time to shrink the zone
        _checkAndShrinkZone();
        
        // Execute move
        _executeMove(msg.sender, _direction);
        
        // Apply damage to player if in damage zone
        _applyZoneDamageToPlayer(msg.sender);
        
        // Check if game is over
        _checkGameOver();
        
        emit ActionExecuted(currentRound, msg.sender, uint8(ActionType.MOVE));
    }
    
    /**
     * @dev Attack a target
     * @param _targetX X coordinate of the target
     * @param _targetY Y coordinate of the target
     */
    function attack(uint256 _targetX, uint256 _targetY) external inState(GameState.ACTIVE) onlyRegistered onlyAlive oneActionPerBlock {
        // Check if it's time to shrink the zone
        _checkAndShrinkZone();
        
        // Execute attack
        _executeAttack(msg.sender, _targetX, _targetY);
        
        // Apply damage to player if in damage zone
        _applyZoneDamageToPlayer(msg.sender);
        
        // Check if game is over
        _checkGameOver();
        
        emit ActionExecuted(currentRound, msg.sender, uint8(ActionType.ATTACK));
    }
    
    /**
     * @dev Defend against attacks
     */
    function defend() external inState(GameState.ACTIVE) onlyRegistered onlyAlive oneActionPerBlock {
        // Check if it's time to shrink the zone
        _checkAndShrinkZone();
        
        // Mark player as defending for this block
        isDefending[currentRound][block.number][msg.sender] = true;
        
        // Update last action block
        players[currentRound][msg.sender].lastActionBlock = block.number;
        
        // Apply damage to player if in damage zone
        _applyZoneDamageToPlayer(msg.sender);
        
        // Check if game is over
        _checkGameOver();
        
        emit PlayerDefended(currentRound, msg.sender);
        emit ActionExecuted(currentRound, msg.sender, uint8(ActionType.DEFEND));
    }
    
    /**
     * @dev Check if it's time to shrink the zone and do so if needed
     */
    function _checkAndShrinkZone() internal {
        if (block.timestamp >= lastZoneShrinkTime + ZONE_SHRINK_INTERVAL && currentSafeZoneSize > 2) {
            currentSafeZoneSize -= 2; // Shrink by 2 units (1 from each side)
            lastZoneShrinkTime = block.timestamp;
            
            emit ZoneShrunk(currentRound, currentSafeZoneSize);
        }
    }
    
    /**
     * @dev Apply damage to a player if they are outside the safe zone
     * @param _player Player address
     */
    function _applyZoneDamageToPlayer(address _player) internal {
        Player storage player = players[currentRound][_player];
        
        if (!player.isAlive) {
            return;
        }
        
        uint256 safeStart = (MAP_SIZE - currentSafeZoneSize) / 2;
        uint256 safeEnd = safeStart + currentSafeZoneSize - 1;
        
        // Check if player is outside the safe zone
        if (player.x < safeStart || player.x > safeEnd || player.y < safeStart || player.y > safeEnd) {
            // Apply damage
            if (player.health <= DAMAGE_ZONE_DAMAGE) {
                player.health = 0;
                player.isAlive = false;
                positionToPlayer[currentRound][player.x][player.y] = address(0);
                
                emit PlayerEliminated(currentRound, _player);
            } else {
                player.health -= DAMAGE_ZONE_DAMAGE;
            }
            
            emit PlayerDamagedByZone(currentRound, _player, DAMAGE_ZONE_DAMAGE, player.health);
        }
    }
    
    /**
     * @dev Execute a move action
     * @param _player Player address
     * @param _direction Direction to move
     */
    function _executeMove(address _player, Direction _direction) internal {
        Player storage player = players[currentRound][_player];
        uint256 newX = player.x;
        uint256 newY = player.y;
        
        // Calculate new position based on direction
        if (_direction == Direction.UP && player.y > 0) {
            newY--;
        } else if (_direction == Direction.DOWN && player.y < MAP_SIZE - 1) {
            newY++;
        } else if (_direction == Direction.LEFT && player.x > 0) {
            newX--;
        } else if (_direction == Direction.RIGHT && player.x < MAP_SIZE - 1) {
            newX++;
        } else {
            return; // Invalid move, silently fail
        }
        
        // Check if new position is empty
        if (positionToPlayer[currentRound][newX][newY] != address(0)) {
            return; // Position occupied, silently fail
        }
        
        // Update position
        positionToPlayer[currentRound][player.x][player.y] = address(0);
        positionToPlayer[currentRound][newX][newY] = _player;
        
        uint256 oldX = player.x;
        uint256 oldY = player.y;
        
        player.x = newX;
        player.y = newY;
        player.lastActionBlock = block.number;
        
        emit PlayerMoved(currentRound, _player, oldX, oldY, newX, newY);
    }
    
    /**
     * @dev Execute an attack action
     * @param _player Player address
     * @param _targetX X coordinate of the target
     * @param _targetY Y coordinate of the target
     */
    function _executeAttack(address _player, uint256 _targetX, uint256 _targetY) internal {
        Player storage attacker = players[currentRound][_player];
        
        // Check if target is in range
        if (!_isInRange(attacker.x, attacker.y, _targetX, _targetY, ATTACK_RANGE)) {
            return; // Target out of range, silently fail
        }
        
        // Check if there is a player at the target position
        address targetAddr = positionToPlayer[currentRound][_targetX][_targetY];
        if (targetAddr == address(0) || targetAddr == _player) {
            return; // No player or self-attack, silently fail
        }
        
        Player storage target = players[currentRound][targetAddr];
        if (!target.isAlive) {
            return; // Target already eliminated, silently fail
        }
        
        // Apply damage
        uint256 damage = ATTACK_DAMAGE;
        
        // If target is defending in this block, reduce damage
        if (isDefending[currentRound][block.number][targetAddr]) {
            damage = damage > DEFEND_REDUCTION ? damage - DEFEND_REDUCTION : 0;
        }
        
        // Update attacker's last action
        attacker.lastActionBlock = block.number;
        
        // Apply damage to target
        if (target.health <= damage) {
            target.health = 0;
            target.isAlive = false;
            positionToPlayer[currentRound][_targetX][_targetY] = address(0);
            
            emit PlayerEliminated(currentRound, targetAddr);
        } else {
            target.health -= damage;
        }
        
        emit PlayerAttacked(currentRound, _player, targetAddr, damage, target.health);
    }
    
    /**
     * @dev Get player information
     * @param _round Round number
     * @param _player Player address
     * @return Player struct
     */
    function getPlayer(uint256 _round, address _player) external view returns (Player memory) {
        return players[_round][_player];
    }
    
    /**
     * @dev Get all players in a round
     * @param _round Round number
     * @return Array of player addresses
     */
    function getPlayers(uint256 _round) external view returns (address[] memory) {
        return roundPlayers[_round];
    }
    
    /**
     * @dev Get player at a specific position
     * @param _round Round number
     * @param _x X coordinate
     * @param _y Y coordinate
     * @return Player address
     */
    function getPlayerAtPosition(uint256 _round, uint256 _x, uint256 _y) external view returns (address) {
        return positionToPlayer[_round][_x][_y];
    }
    
    /**
     * @dev Get the number of alive players
     * @return Number of alive players
     */
    function getAlivePlayerCount() public view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < roundPlayers[currentRound].length; i++) {
            if (players[currentRound][roundPlayers[currentRound][i]].isAlive) {
                count++;
            }
        }
        return count;
    }
    
    /**
     * @dev Get all alive players
     * @return Array of alive player addresses
     */
    function getAlivePlayers() external view returns (address[] memory) {
        uint256 aliveCount = getAlivePlayerCount();
        address[] memory alivePlayers = new address[](aliveCount);
        
        uint256 index = 0;
        for (uint256 i = 0; i < roundPlayers[currentRound].length; i++) {
            address playerAddr = roundPlayers[currentRound][i];
            if (players[currentRound][playerAddr].isAlive) {
                alivePlayers[index] = playerAddr;
                index++;
            }
        }
        
        return alivePlayers;
    }
    
    /**
     * @dev Get the entire game map state
     * @return 2D array of player addresses (address(0) for empty cells)
     */
    function getGameMap() external view returns (address[][] memory) {
        address[][] memory map = new address[][](MAP_SIZE);
        
        for (uint256 x = 0; x < MAP_SIZE; x++) {
            map[x] = new address[](MAP_SIZE);
            for (uint256 y = 0; y < MAP_SIZE; y++) {
                map[x][y] = positionToPlayer[currentRound][x][y];
            }
        }
        
        return map;
    }
    
    /**
     * @dev Get the time until the next zone shrink
     * @return Number of seconds until next zone shrink
     */
    function getTimeUntilNextZoneShrink() external view returns (uint256) {
        if (block.timestamp >= lastZoneShrinkTime + ZONE_SHRINK_INTERVAL || currentSafeZoneSize <= 2) {
            return 0;
        }
        return lastZoneShrinkTime + ZONE_SHRINK_INTERVAL - block.timestamp;
    }
    
    /**
     * @dev Check if a position is in the damage zone
     * @param _x X coordinate
     * @param _y Y coordinate
     * @return Whether the position is in the damage zone
     */
    function isInDamageZone(uint256 _x, uint256 _y) public view returns (bool) {
        uint256 safeStart = (MAP_SIZE - currentSafeZoneSize) / 2;
        uint256 safeEnd = safeStart + currentSafeZoneSize - 1;
        
        return _x < safeStart || _x > safeEnd || _y < safeStart || _y > safeEnd;
    }
    
    /**
     * @dev Get comprehensive game state for frontend
     * @return A tuple containing:
     * - gameState: Current game state (0=INACTIVE, 1=REGISTRATION, 2=ACTIVE, 3=COMPLETED)
     * - currentRound: Current round number
     * - safeZoneSize: Current size of the safe zone
     * - safeZoneStart: Starting coordinate of the safe zone (same for x and y)
     * - timeUntilNextZoneShrink: Seconds until next zone shrink
     * - players: Array of all player data
     * - currentBlock: The current block number
     */
    function getGameState() external view returns (
        uint8,
        uint256,
        uint256,
        uint256,
        uint256,
        Player[] memory,
        uint256
    ) {
        // Calculate safe zone boundaries
        uint256 safeZoneStart = (MAP_SIZE - currentSafeZoneSize) / 2;
        
        // Get time until next zone shrink
        uint256 timeUntilShrink;
        if (block.timestamp >= lastZoneShrinkTime + ZONE_SHRINK_INTERVAL || currentSafeZoneSize <= 2) {
            timeUntilShrink = 0;
        } else {
            timeUntilShrink = lastZoneShrinkTime + ZONE_SHRINK_INTERVAL - block.timestamp;
        }
        
        // Get all players
        Player[] memory allPlayers = new Player[](roundPlayers[currentRound].length);
        for (uint256 i = 0; i < roundPlayers[currentRound].length; i++) {
            address playerAddr = roundPlayers[currentRound][i];
            allPlayers[i] = players[currentRound][playerAddr];
        }
        
        return (
            uint8(gameState),
            currentRound,
            currentSafeZoneSize,
            safeZoneStart,
            timeUntilShrink,
            allPlayers,
            block.number
        );
    }
    
    /**
     * @dev Reset the game state to allow a new round
     */
    function resetGame() external onlyOwner {
        require(gameState == GameState.COMPLETED, "Game not completed");
        gameState = GameState.INACTIVE;
    }
    
    /**
     * @dev Check if the game is over
     */
    function _checkGameOver() internal {
        uint256 aliveCount = getAlivePlayerCount();
        
        if (aliveCount <= 1) {
            // Find the winner
            address lastStanding = address(0);
            
            for (uint256 i = 0; i < roundPlayers[currentRound].length; i++) {
                address playerAddr = roundPlayers[currentRound][i];
                if (players[currentRound][playerAddr].isAlive) {
                    lastStanding = playerAddr;
                    break;
                }
            }
            
            winner = lastStanding;
            gameState = GameState.COMPLETED;
            
            emit GameEnded(currentRound, winner);
        }
    }
    
    /**
     * @dev Generate a random position
     * @return x, y coordinates
     */
    function _getRandomPosition() internal view returns (uint256, uint256) {
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));
        uint256 x = randomNumber % MAP_SIZE;
        uint256 y = (randomNumber / MAP_SIZE) % MAP_SIZE;
        return (x, y);
    }
    
    /**
     * @dev Check if target is in range of attacker
     * @param _x1 Attacker X
     * @param _y1 Attacker Y
     * @param _x2 Target X
     * @param _y2 Target Y
     * @param _range Attack range
     * @return Whether target is in range
     */
    function _isInRange(uint256 _x1, uint256 _y1, uint256 _x2, uint256 _y2, uint256 _range) internal pure returns (bool) {
        uint256 xDiff = _x1 > _x2 ? _x1 - _x2 : _x2 - _x1;
        uint256 yDiff = _y1 > _y2 ? _y1 - _y2 : _y2 - _y1;
        return xDiff + yDiff <= _range;
    }
} 