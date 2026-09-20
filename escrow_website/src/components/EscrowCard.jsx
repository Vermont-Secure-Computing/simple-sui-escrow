import { useState } from "react";
import { useWallet } from "@suiet/wallet-kit";
import {
  depositEscrow,
  withdrawBeforeComplete,
  suggestFinalization,
  acceptFinalization,
  rejectFinalization,
} from "../lib/sui";

function mistToSui(value) {
  return Number(value || 0) / 1_000_000_000;
}

function shortAddress(address) {
  if (!address) return "Not assigned yet";

  return `${address.slice(0, 10)}...${address.slice(-8)}`;
}

function EscrowCard({ escrow, onRefresh }) {
  const wallet = useWallet();

  const [depositing, setDepositing] =
    useState(false);

  const [depositResult, setDepositResult] =
    useState(null);

    const [withdrawing, setWithdrawing] =
    useState(false);
  
  const [withdrawResult, setWithdrawResult] =
    useState(null);

    const [finalizing, setFinalizing] =
    useState(false);
  
  const [finalizationResult, setFinalizationResult] =
    useState(null);

    const [responding, setResponding] =
    useState(false);
  
  const [responseResult, setResponseResult] =
    useState(null);

  const fields =
    escrow.data?.content?.fields;

  if (!fields) return null;

  const escrowId = escrow.data.objectId;

  const status = Number(fields.status);

  const partyA = fields.party_a;
  const partyB = fields.party_b;

  const finalizationProposer =
  fields.finalization_proposer;

const proposedPayoutA =
  Number(
    fields.proposed_payout_a || 0
  );

const proposedPayoutB =
  Number(
    fields.proposed_payout_b || 0
  );

const proposedDonation =
  Number(
    fields.proposed_donation || 0
  );

  const requiredA =
    Number(fields.required_deposit_a || 0);

  const requiredB =
    Number(fields.required_deposit_b || 0);

  const depositedA =
    Number(fields.deposited_a || 0);

  const depositedB =
    Number(fields.deposited_b || 0);

  const walletAddress =
    wallet.address?.toLowerCase();

  const isPartyA =
    partyA &&
    walletAddress === partyA.toLowerCase();

  const isPartyB =
    partyB &&
    walletAddress === partyB.toLowerCase();

    const isParty =
    isPartyA || isPartyB;
  
  const isFinalizationProposer =
    finalizationProposer &&
    walletAddress ===
      finalizationProposer.toLowerCase();
  
  const canRespondToFinalization =
    status === 2 &&
    isParty &&
    !isFinalizationProposer;

  let depositAmount = 0;
  let depositLabel = null;

  if (
    status === 0 &&
    isPartyA &&
    depositedA === 0
  ) {
    depositAmount = requiredA;
    depositLabel =
      `Deposit ${mistToSui(requiredA)} SUI as Party A`;
  } else if (
    status === 0 &&
    isPartyB &&
    depositedB === 0
  ) {
    depositAmount = requiredB;
    depositLabel =
      `Deposit ${mistToSui(requiredB)} SUI as Party B`;
  } else if (
    status === 0 &&
    !partyB &&
    wallet.connected &&
    !isPartyA
  ) {
    depositAmount = requiredB;
    depositLabel =
      `Join & Deposit ${mistToSui(requiredB)} SUI as Party B`;
  }

  const handleDeposit = async () => {
    try {
      setDepositing(true);
      setDepositResult(null);

      console.log(
        "Depositing to escrow:",
        escrowId
      );

      console.log(
        "Deposit amount:",
        depositAmount
      );

      const result =
        await depositEscrow({
          wallet,
          escrowId,
          amount: depositAmount,
        });

      setDepositResult(result.digest);

      console.log(
        "Deposit successful:",
        result.digest
      );

      if (onRefresh) {
        await new Promise(
          (resolve) => setTimeout(resolve, 500)
        );
      
        await onRefresh();
      }
    } catch (error) {
      console.error(error);
      alert(error.message);
    } finally {
      setDepositing(false);
    }
  };

  const handleSuggestFinalization = async () => {
    try {
      setFinalizing(true);
      setFinalizationResult(null);
  
      // Normal successful payment settlement:
      // Party A gets their 0.002 SUI bond back.
      // Party B gets 0.010 payment + 0.002 bond.
      const payoutA = 2_000_000;
      const payoutB = 12_000_000;
      const proposedDonation = 0;
  
      console.log(
        "Suggesting finalization for:",
        escrowId
      );
  
      const result =
        await suggestFinalization({
          wallet,
          escrowId,
          payoutA,
          payoutB,
          proposedDonation,
          note: "Payment completed",
        });
  
      setFinalizationResult(
        result.digest
      );
  
      console.log(
        "Finalization suggested:",
        result.digest
      );
  
      if (onRefresh) {
        await new Promise(
          (resolve) => setTimeout(resolve, 500)
        );
  
        await onRefresh();
      }
    } catch (error) {
      console.error(error);
      alert(error.message);
    } finally {
      setFinalizing(false);
    }
  };

  const handleWithdraw = async () => {
    try {
      setWithdrawing(true);
      setWithdrawResult(null);
  
      console.log(
        "Withdrawing before complete:",
        escrowId
      );
  
      const result =
        await withdrawBeforeComplete({
          wallet,
          escrowId,
        });
  
      setWithdrawResult(result.digest);
  
      console.log(
        "Escrow cancelled / deposit withdrawn:",
        result.digest
      );
  
      if (onRefresh) {
        await new Promise(
          (resolve) =>
            setTimeout(resolve, 500)
        );
  
        await onRefresh();
      }
    } catch (error) {
      console.error(error);
      alert(error.message);
    } finally {
      setWithdrawing(false);
    }
  };

  const handleAcceptFinalization =
  async () => {
    try {
      setResponding(true);
      setResponseResult(null);

      console.log(
        "Accepting finalization:",
        escrowId
      );

      const result =
        await acceptFinalization({
          wallet,
          escrowId,
        });

      setResponseResult({
        type: "accepted",
        digest: result.digest,
      });

      console.log(
        "Finalization accepted:",
        result.digest
      );

      if (onRefresh) {
        await new Promise(
          (resolve) =>
            setTimeout(resolve, 500)
        );

        await onRefresh();
      }
    } catch (error) {
      console.error(error);
      alert(error.message);
    } finally {
      setResponding(false);
    }
  };

const handleRejectFinalization =
  async () => {
    try {
      setResponding(true);
      setResponseResult(null);

      console.log(
        "Rejecting finalization:",
        escrowId
      );

      const result =
        await rejectFinalization({
          wallet,
          escrowId,
        });

      setResponseResult({
        type: "rejected",
        digest: result.digest,
      });

      console.log(
        "Finalization rejected:",
        result.digest
      );

      if (onRefresh) {
        await new Promise(
          (resolve) =>
            setTimeout(resolve, 500)
        );

        await onRefresh();
      }
    } catch (error) {
      console.error(error);
      alert(error.message);
    } finally {
      setResponding(false);
    }
  };

  return (
    <div className="rounded-2xl border border-slate-700 bg-slate-950 p-5">

      <p>
        <strong>Escrow ID:</strong>
      </p>

      <code className="break-all">
        {escrowId}
      </code>

      <p className="mt-4">
        Party A
      </p>

      <code
        className="break-all"
        title={partyA || ""}
      >
        {shortAddress(partyA)}
      </code>

      <p className="mt-4">
        Party B
      </p>

      <code
        className="break-all"
        title={partyB || ""}
      >
        {shortAddress(partyB)}
      </code>

      <p className="mt-4">
        Status
      </p>

      <code>
        {status === 0
          ? "CREATED"
          : status === 1
          ? "DEPOSITS COMPLETE"
          : status === 2
          ? "FINALIZATION SUGGESTED"
          : status === 3
          ? "COMPLETED"
          : status === 4
          ? "CANCELLED"
          : `UNKNOWN (${status})`}
      </code>

      <div className="mt-5 grid gap-3 sm:grid-cols-2">

        <div className="rounded-xl bg-slate-900 p-3">
          <p className="text-sm text-slate-400">
            Party A Deposit
          </p>

          <p className="font-bold">
            {mistToSui(depositedA)} /{" "}
            {mistToSui(requiredA)} SUI
          </p>
        </div>

        <div className="rounded-xl bg-slate-900 p-3">
          <p className="text-sm text-slate-400">
            Party B Deposit
          </p>

          <p className="font-bold">
            {mistToSui(depositedB)} /{" "}
            {mistToSui(requiredB)} SUI
          </p>
        </div>

      </div>

      {depositLabel && (
        <button
          onClick={handleDeposit}
          disabled={depositing}
          className="mt-5 rounded-xl bg-green-600 px-5 py-3 font-bold text-white disabled:opacity-50"
        >
          {depositing
            ? "Depositing..."
            : depositLabel}
        </button>
      )}

      {depositResult && (
        <div className="mt-4 rounded-xl border border-green-500/30 bg-green-500/10 p-3">
          <p className="font-bold text-green-300">
            Deposit Successful
          </p>

          <code className="mt-2 block break-all text-sm">
            {depositResult}
          </code>
        </div>
      )}

{status === 0 &&
  (
    (isPartyA && depositedA > 0) ||
    (isPartyB && depositedB > 0)
  ) && (
    <button
      onClick={handleWithdraw}
      disabled={withdrawing}
      className="mt-5 rounded-xl bg-red-600 px-5 py-3 font-bold text-white disabled:opacity-50"
    >
      {withdrawing
        ? "Withdrawing..."
        : "Withdraw & Cancel Escrow"}
    </button>
  )}

{withdrawResult && (
  <div className="mt-4 rounded-xl border border-red-500/30 bg-red-500/10 p-3">
    <p className="font-bold text-red-300">
      Escrow Cancelled
    </p>

    <code className="mt-2 block break-all text-sm">
      {withdrawResult}
    </code>
  </div>
)}

{status === 1 &&
  (isPartyA || isPartyB) && (
    <button
      onClick={handleSuggestFinalization}
      disabled={finalizing}
      className="mt-5 rounded-xl bg-blue-600 px-5 py-3 font-bold text-white disabled:opacity-50"
    >
      {finalizing
        ? "Suggesting Finalization..."
        : "Suggest Finalization"}
    </button>
  )}

{finalizationResult && (
  <div className="mt-4 rounded-xl border border-blue-500/30 bg-blue-500/10 p-3">
    <p className="font-bold text-blue-300">
      Finalization Suggested
    </p>

    <code className="mt-2 block break-all text-sm">
      {finalizationResult}
    </code>
  </div>
)}

{status === 2 && (
  <div className="mt-5 rounded-xl border border-blue-500/30 bg-blue-500/10 p-4">
    <p className="font-bold text-blue-300">
      Finalization Proposal
    </p>

    <div className="mt-3 space-y-1 text-sm">
      <p>
        Party A payout:{" "}
        <strong>
          {mistToSui(proposedPayoutA)} SUI
        </strong>
      </p>

      <p>
        Party B payout:{" "}
        <strong>
          {mistToSui(proposedPayoutB)} SUI
        </strong>
      </p>

      <p>
        Donation:{" "}
        <strong>
          {mistToSui(proposedDonation)} SUI
        </strong>
      </p>

      <p>
        Proposed by:{" "}
        <code>
          {shortAddress(
            finalizationProposer
          )}
        </code>
      </p>
    </div>

    {isFinalizationProposer && (
      <p className="mt-4 text-sm text-slate-300">
        Waiting for the other party to
        accept or reject this proposal.
      </p>
    )}

    {canRespondToFinalization && (
      <div className="mt-4 flex flex-wrap gap-3">
        <button
          onClick={
            handleAcceptFinalization
          }
          disabled={responding}
          className="rounded-xl bg-green-600 px-5 py-3 font-bold text-white disabled:opacity-50"
        >
          {responding
            ? "Processing..."
            : "Accept Finalization"}
        </button>

        <button
          onClick={
            handleRejectFinalization
          }
          disabled={responding}
          className="rounded-xl bg-red-600 px-5 py-3 font-bold text-white disabled:opacity-50"
        >
          {responding
            ? "Processing..."
            : "Reject Finalization"}
        </button>
      </div>
    )}
  </div>
)}

{responseResult && (
  <div className="mt-4 rounded-xl border border-green-500/30 bg-green-500/10 p-3">
    <p className="font-bold text-green-300">
      {responseResult.type ===
      "accepted"
        ? "Finalization Accepted"
        : "Finalization Rejected"}
    </p>

    <code className="mt-2 block break-all text-sm">
      {responseResult.digest}
    </code>
  </div>
)}

    </div>
  );
}

export default EscrowCard;