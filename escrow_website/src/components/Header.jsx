import React from "react";
import { Link, useLocation } from "react-router-dom";
import { ConnectButton } from "@mysten/dapp-kit-react/ui";

export default function Header() {
  const location = useLocation();

  const isEscrowPage = location.pathname.startsWith("/escrow");

  return (
    <header
      className={
        isEscrowPage
          ? "border-b border-white/10 bg-slate-900/80 backdrop-blur"
          : "border-b border-slate-700"
      }
    >
      <div
        className={
          isEscrowPage
            ? "mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-3 sm:gap-4 sm:px-6"
            : "mx-auto flex max-w-6xl items-center justify-between gap-3 px-4 py-6 sm:px-6"
        }
      >
        <Link
          to="/"
          className="flex min-w-0 items-center gap-3 rounded-xl transition hover:opacity-80"
        >
          <div className="min-w-0 text-left leading-tight">
            <span className="block truncate text-lg font-bold text-white sm:text-2xl">
              ssscrow
            </span>

            <span className="block truncate text-xs text-slate-400 sm:text-sm">
              Simple Sui Escrow
            </span>
          </div>
        </Link>

        {isEscrowPage ? (
          <div className="shrink-0">
            <ConnectButton />
          </div>
        ) : (
          <Link
            to="/escrow"
            className="rounded-full border border-cyan-500/20 bg-black px-5 py-2 text-sm font-medium text-white transition hover:border-cyan-400/40 hover:bg-cyan-500/10"
          >
            Open App
          </Link>
        )}
      </div>
    </header>
  );
}