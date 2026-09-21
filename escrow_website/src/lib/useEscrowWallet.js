import {
  useCurrentAccount,
  useDAppKit,
} from "@mysten/dapp-kit-react";

export function useEscrowWallet() {
  const account = useCurrentAccount();
  const dAppKit = useDAppKit();

  const address = account?.address ?? null;

  return {
    account,
    address,
    connected: Boolean(address),

    async signAndExecuteTransaction({ transaction }) {
      console.log(
        "=== WALLET BEFORE SIGN ===",
        {
          address: account?.address,
          chains: account?.chains,
          features: account?.features,
        }
      );

      const result =
        await dAppKit.signAndExecuteTransaction({
          transaction,
        });

      console.log(
        "=== DAPP KIT TRANSACTION RESULT ===",
        result
      );

      if (result.FailedTransaction) {
        const message =
          result.FailedTransaction.status?.error?.message ??
          "Transaction failed.";

        throw new Error(message);
      }

      if (!result.Transaction?.digest) {
        throw new Error(
          "Transaction completed but no digest was returned."
        );
      }

      // Compatibility with our existing sui.js,
      // which expects result.digest
      return {
        ...result.Transaction,
        digest: result.Transaction.digest,
        rawResult: result,
      };
    },
  };
}
