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
        bool actionSubmittedForBlock;
    }
    
    // Pending action struct
    struct PendingAction {
        address player;
        ActionType actionType;
        Direction direction;
        uint256 targetX;
        uint256 targetY;
    }
    
    // Game configuration
    uint256 public constant MAP_SIZE = 20;
    uint256 public constant INITIAL_HEALTH = 100;
    uint256 public constant ATTACK_DAMAGE = 25;
    uint256 public constant DEFEND_REDUCTION = 10;
    uint256 public constant ATTACK_RANGE = 1;
    uint256 public constant BLOCK_INTERVAL = 1; // 1 block interval for actions
    
    // Game state variables
    address public owner;
    GameState public gameState;
    uint256 public currentRound;
    uint256 public gameStartBlock;
    uint256 public registrationDeadline;
    uint256 public lastExecutedBlock;
    address public winner;
    
    // Player tracking
    mapping(uint256 => mapping(address => Player)) public players; // round -> address -> Player
    mapping(uint256 => address[]) public roundPlayers; // round -> player addresses
    mapping(uint256 => mapping(uint256 => mapping(uint256 => address))) public positionToPlayer; // round -> x -> y -> player address
    
    // Pending actions for the current block
    PendingAction[] public pendingActions;
    
    // Events
    event RoundCreated(uint256 indexed round, uint256 registrationDeadline);
    event PlayerRegistered(uint256 indexed round, address indexed player, uint256 x, uint256 y);
    event GameStarted(uint256 indexed round, uint256 startBlock, uint256 playerCount);
    event PlayerMoved(uint256 indexed round, address indexed player, uint256 fromX, uint256 fromY, uint256 toX, uint256 toY);
    event PlayerAttacked(uint256 indexed round, address indexed attacker, address indexed target, uint256 damage, uint256 targetRemainingHealth);
    event PlayerDefended(uint256 indexed round, address indexed player);
    event PlayerEliminated(uint256 indexed round, address indexed player);
    event GameEnded(uint256 indexed round, address indexed winner);
    event ActionsExecuted(uint256 indexed round, uint256 indexed blockNumber, uint256 actionsCount);
    event ActionSubmitted(uint256 indexed round, address indexed player, uint8 actionType);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
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
            isAlive: true,
            actionSubmittedForBlock: false
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
        lastExecutedBlock = block.number;
        
        emit GameStarted(currentRound, gameStartBlock, roundPlayers[currentRound].length);
    }
    
    /**
     * @dev Submit a move action for the next block execution
     * @param _direction Direction to move (0=UP, 1=DOWN, 2=LEFT, 3=RIGHT)
     */
    function submitMove(Direction _direction) external inState(GameState.ACTIVE) onlyRegistered onlyAlive {
        Player storage player = players[currentRound][msg.sender];
        require(!player.actionSubmittedForBlock, "Action already submitted for this block");
        
        // Add to pending actions
        pendingActions.push(PendingAction({
            player: msg.sender,
            actionType: ActionType.MOVE,
            direction: _direction,
            targetX: 0,
            targetY: 0
        }));
        
        player.actionSubmittedForBlock = true;
        
        emit ActionSubmitted(currentRound, msg.sender, uint8(ActionType.MOVE));
    }
    
    /**
     * @dev Submit an attack action for the next block execution
     * @param _targetX X coordinate of the target
     * @param _targetY Y coordinate of the target
     */
    function submitAttack(uint256 _targetX, uint256 _targetY) external inState(GameState.ACTIVE) onlyRegistered onlyAlive {
        Player storage player = players[currentRound][msg.sender];
        require(!player.actionSubmittedForBlock, "Action already submitted for this block");
        
        // Add to pending actions
        pendingActions.push(PendingAction({
            player: msg.sender,
            actionType: ActionType.ATTACK,
            direction: Direction.UP, // Default, not used for attack
            targetX: _targetX,
            targetY: _targetY
        }));
        
        player.actionSubmittedForBlock = true;
        
        emit ActionSubmitted(currentRound, msg.sender, uint8(ActionType.ATTACK));
    }
    
    /**
     * @dev Submit a defend action for the next block execution
     */
    function submitDefend() external inState(GameState.ACTIVE) onlyRegistered onlyAlive {
        Player storage player = players[currentRound][msg.sender];
        require(!player.actionSubmittedForBlock, "Action already submitted for this block");
        
        // Add to pending actions
        pendingActions.push(PendingAction({
            player: msg.sender,
            actionType: ActionType.DEFEND,
            direction: Direction.UP, // Default, not used for defend
            targetX: 0,
            targetY: 0
        }));
        
        player.actionSubmittedForBlock = true;
        
        emit ActionSubmitted(currentRound, msg.sender, uint8(ActionType.DEFEND));
    }
    
    /**
     * @dev Execute all pending actions for the current block
     */
    function executeActions() external inState(GameState.ACTIVE) {
        require(block.number >= lastExecutedBlock + BLOCK_INTERVAL, "Not time to execute actions yet");
        require(pendingActions.length > 0, "No pending actions to execute");
        
        // Shuffle the pending actions to ensure fairness
        _shufflePendingActions();
        
        // Execute all pending actions
        for (uint256 i = 0; i < pendingActions.length; i++) {
            PendingAction memory action = pendingActions[i];
            
            // Skip if player is no longer alive
            if (!players[currentRound][action.player].isAlive) {
                continue;
            }
            
            if (action.actionType == ActionType.MOVE) {
                _executeMove(action.player, action.direction);
            } else if (action.actionType == ActionType.ATTACK) {
                _executeAttack(action.player, action.targetX, action.targetY);
            } else if (action.actionType == ActionType.DEFEND) {
                _executeDefend(action.player);
            }
        }
        
        // Reset for next block
        uint256 actionsCount = pendingActions.length;
        delete pendingActions;
        lastExecutedBlock = block.number;
        
        // Reset action submitted flags
        for (uint256 i = 0; i < roundPlayers[currentRound].length; i++) {
            address playerAddr = roundPlayers[currentRound][i];
            if (players[currentRound][playerAddr].isAlive) {
                players[currentRound][playerAddr].actionSubmittedForBlock = false;
            }
        }
        
        emit ActionsExecuted(currentRound, block.number, actionsCount);
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
        
        // If target was defending in this block, reduce damage
        if (target.lastActionBlock == block.number && _isDefending(targetAddr)) {
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
            
            // Check if game is over
            _checkGameOver();
        } else {
            target.health -= damage;
        }
        
        emit PlayerAttacked(currentRound, _player, targetAddr, damage, target.health);
    }
    
    /**
     * @dev Execute a defend action
     * @param _player Player address
     */
    function _executeDefend(address _player) internal {
        Player storage player = players[currentRound][_player];
        player.lastActionBlock = block.number;
        
        emit PlayerDefended(currentRound, _player);
    }
    
    /**
     * @dev Check if a player is defending in the current block
     * @param _player Player address
     * @return Whether the player is defending
     */
    function _isDefending(address _player) internal view returns (bool) {
        for (uint256 i = 0; i < pendingActions.length; i++) {
            if (pendingActions[i].player == _player && pendingActions[i].actionType == ActionType.DEFEND) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * @dev Shuffle the pending actions array to ensure fairness
     */
    function _shufflePendingActions() internal {
        uint256 n = pendingActions.length;
        for (uint256 i = 0; i < n; i++) {
            // Generate a random index
            uint256 j = i + uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i))) % (n - i);
            
            // Swap elements
            PendingAction memory temp = pendingActions[i];
            pendingActions[i] = pendingActions[j];
            pendingActions[j] = temp;
        }
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
     * @dev Get the time until the next action execution
     * @return Number of blocks until next execution
     */
    function getTimeUntilNextExecution() external view returns (uint256) {
        if (block.number >= lastExecutedBlock + BLOCK_INTERVAL) {
            return 0;
        }
        return lastExecutedBlock + BLOCK_INTERVAL - block.number;
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