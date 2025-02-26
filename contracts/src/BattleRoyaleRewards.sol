// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BattleRoyale.sol";

/**
 * @title BattleRoyaleRewards
 * @dev Handles rewards for battle royale winners
 */
contract BattleRoyaleRewards {
    BattleRoyale public battleRoyale;
    address public owner;
    
    // Mapping from round to prize amount
    mapping(uint256 => uint256) public roundPrizes;
    
    // Mapping from round to whether the prize has been claimed
    mapping(uint256 => bool) public prizeClaimed;
    
    // Events
    event PrizeAdded(uint256 indexed round, uint256 amount);
    event PrizeClaimed(uint256 indexed round, address indexed winner, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor(address _battleRoyaleAddress) {
        battleRoyale = BattleRoyale(_battleRoyaleAddress);
        owner = msg.sender;
    }
    
    /**
     * @dev Add prize for a specific round
     * @param _round Round number
     */
    function addPrize(uint256 _round) external payable onlyOwner {
        require(msg.value > 0, "Prize amount must be greater than 0");
        require(roundPrizes[_round] == 0, "Prize already added for this round");
        
        roundPrizes[_round] = msg.value;
        
        emit PrizeAdded(_round, msg.value);
    }
    
    /**
     * @dev Claim prize for a specific round
     * @param _round Round number
     */
    function claimPrize(uint256 _round) external {
        require(roundPrizes[_round] > 0, "No prize for this round");
        require(!prizeClaimed[_round], "Prize already claimed");
        
        // Get the game state
        BattleRoyale.GameState gameState = battleRoyale.gameState();
        require(gameState == BattleRoyale.GameState.COMPLETED, "Game not completed");
        
        // Get the winner
        address winner = battleRoyale.winner();
        require(winner == msg.sender, "Only winner can claim prize");
        
        // Mark prize as claimed
        prizeClaimed[_round] = true;
        
        // Transfer prize to winner
        uint256 prizeAmount = roundPrizes[_round];
        (bool success, ) = payable(winner).call{value: prizeAmount}("");
        require(success, "Transfer failed");
        
        emit PrizeClaimed(_round, winner, prizeAmount);
    }
    
    /**
     * @dev Withdraw unclaimed prizes (only for rounds that have been reset)
     * @param _round Round number
     */
    function withdrawUnclaimedPrize(uint256 _round) external onlyOwner {
        require(roundPrizes[_round] > 0, "No prize for this round");
        require(!prizeClaimed[_round], "Prize already claimed");
        
        // Get the current round
        uint256 currentRound = battleRoyale.currentRound();
        require(_round < currentRound, "Cannot withdraw prize for current or future rounds");
        
        // Mark prize as claimed
        prizeClaimed[_round] = true;
        
        // Transfer prize to owner
        uint256 prizeAmount = roundPrizes[_round];
        (bool success, ) = payable(owner).call{value: prizeAmount}("");
        require(success, "Transfer failed");
    }
    
    /**
     * @dev Update battle royale contract address
     * @param _newBattleRoyaleAddress New battle royale contract address
     */
    function updateBattleRoyaleAddress(address _newBattleRoyaleAddress) external onlyOwner {
        require(_newBattleRoyaleAddress != address(0), "Invalid address");
        battleRoyale = BattleRoyale(_newBattleRoyaleAddress);
    }
    
    /**
     * @dev Transfer ownership
     * @param _newOwner New owner address
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        owner = _newOwner;
    }
} 