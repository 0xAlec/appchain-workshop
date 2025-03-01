import { useConfig, useReadContract } from 'wagmi';
import { useState, useEffect, useCallback } from 'react';
import { battleRoyaleAbi } from '../../contracts/battleRoyaleAbi';
import { readContract } from 'wagmi/actions';
import { contractAddress } from '../constants';

interface Player {
  addr: string;
  x: number;
  y: number;
  health: number;
  lastActionBlock: number;
  isAlive: boolean;
}

interface UseFetchPlayersResult {
  players: Player[];
  alivePlayers: string[];
  isLoading: boolean;
  isError: boolean;
  refetch: () => void;
}

export function useFetchPlayers(
  currentRound: number = 1
): UseFetchPlayersResult {
  const [players, setPlayers] = useState<Player[]>([]);
  const config = useConfig();

  // Get all players in the current round
  const {
    data: playerAddresses,
    isLoading: isLoadingAddresses,
    isError: isErrorAddresses,
    refetch: refetchAddresses,
  } = useReadContract({
    address: contractAddress,
    abi: battleRoyaleAbi,
    functionName: 'getPlayers',
    args: [BigInt(currentRound)],
    chainId: 8453200058,
  });

  // Get alive players
  const {
    data: alivePlayerAddresses,
    isLoading: isLoadingAlive,
    isError: isErrorAlive,
    refetch: refetchAlive,
  } = useReadContract({
    address: contractAddress,
    abi: battleRoyaleAbi,
    functionName: 'getAlivePlayers',
    chainId: 8453200058,
  });

  const fetchPlayerData = useCallback(async () => {
    if (!playerAddresses || playerAddresses.length === 0) {
      setPlayers([]);
      return;
    }

    try {
      // Fetch all player data concurrently
      const playerPromises = playerAddresses.map((address) =>
        readContract(config, {
          address: contractAddress,
          abi: battleRoyaleAbi,
          functionName: 'getPlayer',
          args: [BigInt(currentRound), address],
          chainId: 8453200058,
        })
      );

      // Wait for all promises to resolve
      const playerResults = await Promise.all(playerPromises);

      // Convert bigint values to numbers
      const formattedPlayers = playerResults.map((player) => ({
        addr: player.addr,
        x: Number(player.x),
        y: Number(player.y),
        health: Number(player.health),
        lastActionBlock: Number(player.lastActionBlock),
        isAlive: player.isAlive,
      }));

      setPlayers(formattedPlayers);
    } catch (error) {
      console.error('Error fetching player data:', error);
    }
  }, [playerAddresses, config, currentRound]);

  const refetch = () => {
    refetchAddresses();
    refetchAlive();
    fetchPlayerData();
  };

  useEffect(() => {
    fetchPlayerData();
  }, [fetchPlayerData]);

  return {
    players,
    alivePlayers: (alivePlayerAddresses as string[]) || [],
    isLoading: isLoadingAddresses || isLoadingAlive,
    isError: isErrorAddresses || isErrorAlive,
    refetch,
  };
}
