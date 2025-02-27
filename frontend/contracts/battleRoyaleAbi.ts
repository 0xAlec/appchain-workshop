export const battleRoyaleAbi = [
  {
    inputs: [],
    name: 'getGameMap',
    outputs: [
      {
        internalType: 'address[][]',
        name: '',
        type: 'address[][]',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'register',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: '_round',
        type: 'uint256',
      },
    ],
    name: 'getPlayers',
    outputs: [
      {
        internalType: 'address[]',
        name: '',
        type: 'address[]',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'getAlivePlayers',
    outputs: [
      {
        internalType: 'address[]',
        name: '',
        type: 'address[]',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: '_round',
        type: 'uint256',
      },
      {
        internalType: 'address',
        name: '_player',
        type: 'address',
      },
    ],
    name: 'getPlayer',
    outputs: [
      {
        components: [
          { internalType: 'address', name: 'addr', type: 'address' },
          { internalType: 'uint256', name: 'x', type: 'uint256' },
          { internalType: 'uint256', name: 'y', type: 'uint256' },
          { internalType: 'uint256', name: 'health', type: 'uint256' },
          { internalType: 'uint256', name: 'lastActionBlock', type: 'uint256' },
          { internalType: 'bool', name: 'isAlive', type: 'bool' },
          {
            internalType: 'bool',
            name: 'actionSubmittedForBlock',
            type: 'bool',
          },
        ],
        internalType: 'struct BattleRoyale.Player',
        name: '',
        type: 'tuple',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'gameState',
    outputs: [
      {
        internalType: 'enum BattleRoyale.GameState',
        name: '',
        type: 'uint8',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'currentRound',
    outputs: [
      {
        internalType: 'uint256',
        name: '',
        type: 'uint256',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint8',
        name: 'direction',
        type: 'uint8',
      },
    ],
    name: 'submitMove',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: 'targetX',
        type: 'uint256',
      },
      {
        internalType: 'uint256',
        name: 'targetY',
        type: 'uint256',
      },
    ],
    name: 'submitAttack',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'submitDefend',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const;
