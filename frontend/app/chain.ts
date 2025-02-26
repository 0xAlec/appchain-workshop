import { defineChain } from 'viem';

export const SANDBOX_CHAIN = defineChain({
  id: 8453200058,
  name: 'Sandbox Network',
  nativeCurrency: {
    name: 'Ethereum',
    symbol: 'ETH',
    decimals: 18,
  },
  rpcUrls: {
    default: {
      http: ['https://sandbox-rpc-testnet.appchain.base.org'],
    },
  },
});
