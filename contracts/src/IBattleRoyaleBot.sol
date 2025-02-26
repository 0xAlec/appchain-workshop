// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BattleRoyale.sol";

/**
 * @title IBattleRoyaleBot
 * @dev Interface for battle royale bots
 */
interface IBattleRoyaleBot {
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
    ) external view returns (
        uint8 actionType,
        uint8 direction,
        uint256 targetX,
        uint256 targetY
    );
    
    /**
     * @dev Execute the next action for the bot
     * @param _game Address of the battle royale game
     */
    function executeAction(address _game) external;
} 