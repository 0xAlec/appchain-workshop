'use client';

import { useReadContract, useAccount } from 'wagmi';
import { useState, useEffect } from 'react';
import client from './client';
import { battleRoyaleAbi } from '../contracts/battleRoyaleAbi';
import { useFetchPlayers } from './hooks/useFetchPlayers';
const contractAddress = '0x61c36a8d610163660E21a8b7359e1Cac0C9133e1';

export default function App() {
  // State to store the game map
  const [gameMap, setGameMap] = useState<string[][]>([]);
  const { players, alivePlayers } = useFetchPlayers();
  // Add state for player colors
  const [playerColors, setPlayerColors] = useState<Record<string, string>>({});
  
  // Add these new states
  const [gameState, setGameState] = useState<number>(0); // 0=INACTIVE, 1=REGISTRATION, 2=ACTIVE, 3=COMPLETED
  const { address } = useAccount();
  const [isRegistered, setIsRegistered] = useState(false);
  
  // Read the game map
  const { data, isLoading, isError, refetch } = useReadContract({
    address: contractAddress,
    abi: battleRoyaleAbi,
    functionName: 'getGameMap',
    chainId: 8453200058,
  });
  
  // Read the game state
  const { data: gameStateData } = useReadContract({
    address: contractAddress,
    abi: battleRoyaleAbi,
    functionName: 'gameState',
    chainId: 8453200058,
  });
  
  // Update the state when data is loaded
  useEffect(() => {
    if (data) {
      setGameMap(data as string[][]);
    }
  }, [data]);
  
  // Refresh the map every block
  useEffect(() => {
    const intervalId = setInterval(() => {
      refetch();
    }, 1000);
    
    // Clean up the interval when component unmounts
    return () => clearInterval(intervalId);
  }, [refetch]);

  // Update game state when data is loaded
  useEffect(() => {
    if (gameStateData !== undefined) {
      setGameState(Number(gameStateData));
    }
  }, [gameStateData]);
  
  // Check if the current user is registered
  useEffect(() => {
    if (!address || !players.length) return;
    
    const userIsRegistered = players.some(player => 
      player.addr.toLowerCase() === address.toLowerCase()
    );
    setIsRegistered(userIsRegistered);
  }, [address, players]);

  // Generate deterministic colors for players based on their addresses
  useEffect(() => {
    const colorOptions = [
      'bg-red-500', 'bg-blue-500', 'bg-green-500', 'bg-yellow-500', 
      'bg-purple-500', 'bg-pink-500', 'bg-indigo-500', 'bg-teal-500',
      'bg-orange-500', 'bg-cyan-500', 'bg-lime-500', 'bg-amber-500'
    ];
    
    // Only add new players to the color mapping
    const newColors = { ...playerColors };
    let updated = false;
    
    players.forEach(player => {
      if (!newColors[player.addr]) {
        // Use a simple hash of the address to determine color index
        const addressSum = player.addr
          .toLowerCase()
          .split('')
          .reduce((sum, char) => sum + char.charCodeAt(0), 0);
        
        const colorIndex = addressSum % colorOptions.length;
        newColors[player.addr] = colorOptions[colorIndex];
        updated = true;
      }
    });
    
    if (updated) {
      setPlayerColors(newColors);
    }
  }, [players, playerColors]);

  // Render loading state
  if (isLoading) {
    return (
      <div className="flex flex-col min-h-screen font-sans dark:bg-background dark:text-white bg-white text-black">
        <main className="flex-grow flex items-center justify-center">
          Loading game map...
        </main>
      </div>
    );
  }
  
  // Render error state
  if (isError) {
    return (
      <div className="flex flex-col min-h-screen font-sans dark:bg-background dark:text-white bg-white text-black">
        <main className="flex-grow flex items-center justify-center">
          Error loading game map
        </main>
      </div>
    );
  }
  
  return (
    <div className="flex flex-col min-h-screen font-sans dark:bg-background dark:text-white bg-white text-black">
      <main className="flex-grow flex flex-row items-start justify-center p-4">
        <div className="flex flex-col items-center">
          <h1 className="text-2xl font-bold mb-4">Battle Royale Game Map</h1>
          
          {gameMap.length > 0 ? (
            <div className="grid gap-1" style={{ 
              display: 'grid', 
              gridTemplateColumns: `repeat(${gameMap[0].length}, minmax(0, 1fr))` 
            }}>
              {gameMap.map((row, x) => (
                row.map((cell, y) => (
                  <div 
                    key={`${x}-${y}`} 
                    className={`w-8 h-8 border ${cell !== '0x0000000000000000000000000000000000000000' ? playerColors[cell] : 'bg-gray-200'}`}
                    title={cell !== '0x0000000000000000000000000000000000000000' ? `Player: ${cell}` : 'Empty'}
                  />
                ))
              ))}
            </div>
          ) : (
            <p>No game map data available</p>
          )}
        </div>
        
        {/* Player information sidebar */}
        <div className="ml-24 w-80 bg-gray-100 dark:bg-gray-800 p-4 rounded-lg shadow-md">
          <h2 className="text-xl font-bold mb-3">Players</h2>
          
          {players.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                <thead>
                  <tr>
                    <th className="px-2 py-2 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Color</th>
                    <th className="px-2 py-2 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Address</th>
                    <th className="px-2 py-2 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">Status</th>
                    <th className="px-2 py-2 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">HP</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
                  {players.map((player, index) => (
                    <tr key={index} className={alivePlayers.includes(player.addr) ? "" : "text-gray-400 dark:text-gray-500"}>
                      <td className="px-2 py-2 text-xs">
                        <div className={`w-4 h-4 rounded-full ${playerColors[player.addr] || 'bg-gray-500'}`}></div>
                      </td>
                      <td className="px-2 py-2 text-xs whitespace-nowrap overflow-hidden text-ellipsis" style={{ maxWidth: "180px" }}>
                        {player.addr.slice(0, 5)}...{player.addr.slice(-4)}
                      </td>
                      <td className="px-2 py-2 text-xs">
                        {alivePlayers.includes(player.addr) ? (
                          <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200">
                            Alive
                          </span>
                        ) : (
                          <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200">
                            Dead
                          </span>
                        )}
                      </td>
                      <td className="px-2 py-2 text-xs">
                        {alivePlayers.includes(player.addr) ? player.health : '0'}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <p className="text-sm text-gray-500 dark:text-gray-400">No players registered yet</p>
          )}
          
          {/* Game state and registration section - moved here */}
          <div className="mt-6 pt-4 border-t border-gray-200 dark:border-gray-700">
            <h3 className="text-lg font-semibold mb-3">Game Information</h3>
            
            {/* Game state indicator */}
            <div className="mb-4 text-sm">
              <span className="font-medium">Game State: </span>
              <span className={`inline-flex items-center px-2 py-1 rounded text-xs font-medium
                ${gameState === 0 ? 'bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-200' : 
                  gameState === 1 ? 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200' :
                  gameState === 2 ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200' :
                  'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200'}`}>
                {gameState === 0 ? 'Inactive' : 
                 gameState === 1 ? 'Registration Open' : 
                 gameState === 2 ? 'Game Active' : 'Game Completed'}
              </span>
            </div>
            <div className="text-sm mb-2">
            <span className="font-medium">Total Players:</span> {players.length}
            </div>
            <div className="text-sm mb-4">
              <span className="font-medium">Alive Players:</span> {alivePlayers.length}
            </div>
            
            <button 
              onClick={async () => {
                await client.writeContract({
                  address: contractAddress,
                  abi: battleRoyaleAbi,
                  functionName: 'register',
                });
              }}
              disabled={gameState !== 1 || isRegistered}
              className={`w-full px-4 py-2 font-medium rounded-lg shadow-md transition duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50
                ${gameState !== 1 || isRegistered 
                  ? 'bg-gray-400 cursor-not-allowed' 
                  : 'bg-blue-600 hover:bg-blue-700 text-white transform hover:scale-105'}`}
            >
              {isRegistered 
                ? 'Already Registered' 
                : gameState === 1 
                  ? 'Register' 
                  : gameState === 0 
                    ? 'Registration Not Open' 
                    : 'Registration Closed'}
            </button>
          </div>
        </div>
      </main>
    </div>
  );
}
