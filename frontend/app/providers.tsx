'use client';

import { base, baseSepolia } from 'wagmi/chains';
import { OnchainKitProvider } from '@coinbase/onchainkit';
import type { ReactNode } from 'react';
import { createConfig, WagmiProvider } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { http } from 'viem';
import { SANDBOX_CHAIN } from './chain';

const wagmiConfig = createConfig({
  chains: [baseSepolia, SANDBOX_CHAIN], 
  transports: {
    [baseSepolia.id]: http(),
    [SANDBOX_CHAIN.id]: http(), 
  }
});

const queryClient = new QueryClient();

export function Providers(props: { children: ReactNode }) {
  return (
    <OnchainKitProvider
      apiKey={process.env.NEXT_PUBLIC_ONCHAINKIT_API_KEY}
          chain={base}
          config={{ appearance: { 
            mode: 'auto',
        }
      }}
    >
      <WagmiProvider config={wagmiConfig}>
        <QueryClientProvider client={queryClient}>
          {props.children}
        </QueryClientProvider>
      </WagmiProvider>
    </OnchainKitProvider>
  );
}

