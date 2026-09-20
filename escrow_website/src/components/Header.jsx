import React, { useEffect } from "react";
import {
  ConnectButton,
  useWallet,
} from "@suiet/wallet-kit";

import logo from "../assets/logo.png";
import { client } from "../lib/sui.js";

const wallet = useWallet();

export default function Header() {
  const wallet = useWallet();

  useEffect(() => {
    if (!wallet.account?.address) {
      return;
    }
  
    const checkBalance = async () => {
      try {
        const result = await client.getBalance({
          owner: wallet.account.address,
        });
  
        console.log("=== DIRECT DEVNET BALANCE ===");
        console.log("address:", wallet.account.address);
        console.log("coinType:", result.coinType);
        console.log("totalBalance:", result.totalBalance);
        console.log(
          "SUI:",
          Number(result.totalBalance) / 1_000_000_000
        );
      } catch (error) {
        console.error(
          "Direct Devnet balance failed:",
          error
        );
      }
    };
  
    checkBalance();
  }, [wallet.account?.address]);

  console.log("=== SUIET DEBUG ===");
  console.log("connected:", wallet.connected);
  console.log("address:", wallet.account?.address);
  console.log("account chains:", wallet.account?.chains);
  console.log("wallet chain:", wallet.chain);
  console.log("wallet name:", wallet.name);
  console.log("adapter:", wallet.adapter);

  return (
    <header className="border-b border-white/10 bg-slate-900/80 backdrop-blur">
      <div className="mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-3 sm:gap-4 sm:px-6">

        <div className="flex min-w-0 items-start gap-3">
          <img
            src={logo}
            alt="SSScrow"
            className="h-9 w-auto shrink-0 object-contain sm:h-10"
          />

          <div className="min-w-0 text-left leading-tight">
            <span className="block truncate text-lg font-bold text-white sm:text-2xl">
              ssscrow
            </span>

            <span className="block truncate text-xs text-slate-400 sm:text-sm">
              Simple Sui Escrow
            </span>
          </div>
        </div>

        <div className="shrink-0">
          <ConnectButton />
        </div>

      </div>
    </header>
  );
}