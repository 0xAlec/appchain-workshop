import { createPublicClient, createWalletClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { SANDBOX_CHAIN } from './chain';

const pk = process.env.NEXT_PUBLIC_PRIVATE_KEY as `0x${string}`;
const account = privateKeyToAccount(pk);

const client = createWalletClient({
  account,
  chain: SANDBOX_CHAIN,
  transport: http(),
});

const publicClient = createPublicClient({
  chain: SANDBOX_CHAIN,
  transport: http(),
});

export default client;
export { account, publicClient };
