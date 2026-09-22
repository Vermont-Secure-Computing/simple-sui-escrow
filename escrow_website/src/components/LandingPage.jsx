import React from "react";
import { Link } from "react-router-dom";
import { FontAwesomeIcon } from "@fortawesome/react-fontawesome";
import {
  faShieldHalved,
  faHandshake,
  faLock,
  faWallet,
  faArrowRight,
  faCircleCheck,
  faUserShield,
  faBolt,
  faScaleBalanced,
  faCoins,
} from "@fortawesome/free-solid-svg-icons";

import Header from "./Header";

export function LandingPage() {
  return (
    <div className="min-h-screen bg-slate-950 text-white">
      <Header />

      <main>
        {/* HERO */}
        <section className="mx-auto max-w-6xl px-6 py-20 sm:py-28">
          <div className="mx-auto max-w-4xl text-center">
            <div className="mb-6 inline-flex items-center gap-2 rounded-full border border-cyan-500/20 bg-cyan-500/10 px-4 py-2 text-sm text-cyan-300">
              <FontAwesomeIcon icon={faShieldHalved} />
              Decentralized escrow on Sui
            </div>

            <h1 className="text-4xl font-black tracking-tight sm:text-6xl">
              Trustless Escrow for
              <span className="block text-cyan-400">
                Safe & Fair Transactions
              </span>
            </h1>

            <p className="mx-auto mt-6 max-w-2xl text-lg leading-8 text-slate-400">
              Secure agreements between buyers and sellers
              using Sui smart contracts. Funds remain locked
              until both parties agree on the final settlement.
            </p>

            <div className="mt-10 flex flex-wrap justify-center gap-4">
              <Link
                to="/escrow"
                className="rounded-xl bg-cyan-500 px-7 py-3 font-bold text-slate-950 transition hover:bg-cyan-400"
              >
                Open App
                <FontAwesomeIcon
                  icon={faArrowRight}
                  className="ml-2"
                />
              </Link>

              <a
                href="#how-it-works"
                className="rounded-xl border border-slate-700 bg-slate-900 px-7 py-3 font-bold text-white transition hover:border-slate-600 hover:bg-slate-800"
              >
                How It Works
              </a>
            </div>
          </div>
        </section>

        {/* BUYER / SELLER */}
        <section className="mx-auto max-w-6xl px-6 pb-20">
          <div className="grid gap-6 md:grid-cols-2">
            <div className="rounded-3xl border border-white/10 bg-white/5 p-8">
              <div className="mb-5 flex h-12 w-12 items-center justify-center rounded-xl bg-blue-500/10 text-blue-400">
                <FontAwesomeIcon
                  icon={faUserShield}
                  size="lg"
                />
              </div>

              <h2 className="text-2xl font-bold">
                For Buyers
              </h2>

              <p className="mt-3 leading-7 text-slate-400">
                Lock payment and a refundable security
                deposit in the escrow. Funds are released
                only after the transaction reaches an
                agreed settlement.
              </p>
            </div>

            <div className="rounded-3xl border border-white/10 bg-white/5 p-8">
              <div className="mb-5 flex h-12 w-12 items-center justify-center rounded-xl bg-green-500/10 text-green-400">
                <FontAwesomeIcon
                  icon={faHandshake}
                  size="lg"
                />
              </div>

              <h2 className="text-2xl font-bold">
                For Sellers
              </h2>

              <p className="mt-3 leading-7 text-slate-400">
                Participate in an escrow where the agreed
                payment and deposits are enforced by the
                smart contract instead of a centralized
                intermediary.
              </p>
            </div>
          </div>
        </section>

        {/* HOW IT WORKS */}
        <section
          id="how-it-works"
          className="border-y border-white/10 bg-slate-900/40"
        >
          <div className="mx-auto max-w-6xl px-6 py-20">
            <div className="text-center">
              <p className="text-sm font-bold uppercase tracking-widest text-cyan-400">
                Simple Process
              </p>

              <h2 className="mt-3 text-3xl font-black sm:text-4xl">
                How It Works
              </h2>

              <p className="mx-auto mt-4 max-w-2xl text-slate-400">
                Create an agreement, fund the escrow, then
                settle it when both parties are satisfied.
              </p>
            </div>

            <div className="mt-12 grid gap-5 md:grid-cols-2 lg:grid-cols-3">
              <Step
                number="1"
                icon={faWallet}
                title="Connect Wallet"
              >
                Connect a compatible Sui wallet to create
                or participate in an escrow.
              </Step>

              <Step
                number="2"
                icon={faHandshake}
                title="Create Agreement"
              >
                Define the parties, transaction amount,
                deposits, and agreement details.
              </Step>

              <Step
                number="3"
                icon={faLock}
                title="Fund Escrow"
              >
                Each party deposits the required SUI into
                the shared escrow object.
              </Step>

              <Step
                number="4"
                icon={faCircleCheck}
                title="Complete Transaction"
              >
                The buyer and seller complete their
                off-chain transaction or service.
              </Step>

              <Step
                number="5"
                icon={faScaleBalanced}
                title="Propose Settlement"
              >
                Either party can suggest how the locked
                funds should be distributed.
              </Step>

              <Step
                number="6"
                icon={faCoins}
                title="Release Funds"
              >
                The other party accepts the proposal and
                the smart contract distributes the funds.
              </Step>
            </div>
          </div>
        </section>

        {/* INCENTIVIZED HONESTY */}
        <section className="mx-auto max-w-6xl px-6 py-20">
          <div className="rounded-3xl border border-cyan-500/20 bg-gradient-to-br from-cyan-500/10 to-blue-500/5 p-8 sm:p-12">
            <div className="grid gap-10 lg:grid-cols-2 lg:items-center">
              <div>
                <p className="text-sm font-bold uppercase tracking-widest text-cyan-400">
                  Incentivized Honesty
                </p>

                <h2 className="mt-3 text-3xl font-black">
                  Both parties have something at stake.
                </h2>

                <p className="mt-5 leading-7 text-slate-300">
                  Escrow deposits give both sides an
                  economic reason to complete the
                  transaction fairly. The contract keeps
                  custody of the funds while the agreement
                  is active.
                </p>
              </div>

              <div className="grid gap-4">
                <FeatureLine
                  icon={faLock}
                  title="Funds locked on-chain"
                />

                <FeatureLine
                  icon={faHandshake}
                  title="Mutual settlement"
                />

                <FeatureLine
                  icon={faShieldHalved}
                  title="Smart-contract enforced"
                />
              </div>
            </div>
          </div>
        </section>

        {/* FEATURES */}
        <section className="border-t border-white/10 bg-slate-900/30">
          <div className="mx-auto max-w-6xl px-6 py-20">
            <div className="grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
              <Feature
                icon={faBolt}
                title="Fast"
                text="Built using the Sui network for fast transaction execution."
              />

              <Feature
                icon={faShieldHalved}
                title="Secure"
                text="Funds are controlled by the escrow smart contract."
              />

              <Feature
                icon={faHandshake}
                title="Peer-to-Peer"
                text="Create agreements directly between two parties."
              />

              <Feature
                icon={faScaleBalanced}
                title="Transparent"
                text="Escrow state and settlement terms are recorded on-chain."
              />
            </div>
          </div>
        </section>

        {/* CTA */}
        <section className="mx-auto max-w-6xl px-6 py-20 text-center">
          <h2 className="text-3xl font-black sm:text-4xl">
            Ready to create an escrow?
          </h2>

          <p className="mx-auto mt-4 max-w-xl text-slate-400">
            Create a Sui escrow and manage the full
            agreement lifecycle directly from your wallet.
          </p>

          <Link
            to="/escrow"
            className="mt-8 inline-block rounded-xl bg-cyan-500 px-8 py-3 font-bold text-slate-950 transition hover:bg-cyan-400"
          >
            Open Escrow App
            <FontAwesomeIcon
              icon={faArrowRight}
              className="ml-2"
            />
          </Link>
        </section>
      </main>

      <footer className="border-t border-white/10">
        <div className="mx-auto flex max-w-6xl flex-col gap-3 px-6 py-8 text-sm text-slate-500 sm:flex-row sm:items-center sm:justify-between">
          <p>
            ssscrow — Simple Sui Escrow
          </p>

          <div className="flex gap-5">
            <span>Built on Sui</span>
            <span>Fast</span>
            <span>Secure</span>
            <span>Decentralized</span>
          </div>
        </div>
      </footer>
    </div>
  );
}

function Step({
  number,
  icon,
  title,
  children,
}) {
  return (
    <div className="rounded-2xl border border-white/10 bg-slate-950 p-6">
      <div className="flex items-center justify-between">
        <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-cyan-500/10 text-cyan-400">
          <FontAwesomeIcon icon={icon} />
        </div>

        <span className="text-3xl font-black text-slate-800">
          {number}
        </span>
      </div>

      <h3 className="mt-5 text-lg font-bold">
        {title}
      </h3>

      <p className="mt-2 leading-6 text-slate-400">
        {children}
      </p>
    </div>
  );
}

function FeatureLine({ icon, title }) {
  return (
    <div className="flex items-center gap-4 rounded-2xl border border-white/10 bg-slate-950/60 p-4">
      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-cyan-500/10 text-cyan-400">
        <FontAwesomeIcon icon={icon} />
      </div>

      <p className="font-bold">
        {title}
      </p>
    </div>
  );
}

function Feature({ icon, title, text }) {
  return (
    <div>
      <div className="mb-4 flex h-11 w-11 items-center justify-center rounded-xl bg-cyan-500/10 text-cyan-400">
        <FontAwesomeIcon icon={icon} />
      </div>

      <h3 className="font-bold">
        {title}
      </h3>

      <p className="mt-2 text-sm leading-6 text-slate-400">
        {text}
      </p>
    </div>
  );
}