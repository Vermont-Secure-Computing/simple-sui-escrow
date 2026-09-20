import { SuiClient } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";

// ============================================================
// NETWORK / CONTRACT
// ============================================================

export const NETWORK = "localnet";

export const RPC_URL = "http://127.0.0.1:9000";

export const client = new SuiClient({
  url: RPC_URL,
});

export const PACKAGE_ID =
  "0x24f913383295f9598079d392794a5554c9bee9023db04260d8836f576d5f8cb5";

export const CLOCK_OBJECT_ID = "0x6";

// Escrow types
export const ESCROW_TYPE_PAYMENT = 0;
export const ESCROW_TYPE_BET = 1;
export const ESCROW_TYPE_MUTUAL_BOND = 2;
export const ESCROW_TYPE_CUSTOM = 3;

// ============================================================
// HELPERS
// ============================================================

function addressOption(tx, address) {
  if (!address || address === "0x0") {
    return tx.pure.option("address", null);
  }

  return tx.pure.option("address", address);
}

function textToBytes(text) {
  return Array.from(
    new TextEncoder().encode(text || "")
  );
}

export async function depositEscrow({
  wallet,
  escrowId,
  amount,
}) {
  if (!wallet?.connected || !wallet?.address) {
    throw new Error(
      "Please connect your wallet first."
    );
  }

  if (!escrowId) {
    throw new Error(
      "Escrow Object ID is required."
    );
  }

  if (!amount || Number(amount) <= 0) {
    throw new Error(
      "Deposit amount must be greater than zero."
    );
  }

  const tx = new Transaction();

  tx.setSender(wallet.address);

  const [depositCoin] = tx.splitCoins(
    tx.gas,
    [
      tx.pure.u64(amount),
    ]
  );

  tx.moveCall({
    target: `${PACKAGE_ID}::escrow::deposit`,
    arguments: [
      tx.object(escrowId),
      depositCoin,
      tx.object(CLOCK_OBJECT_ID),
    ],
  });

  const result =
    await wallet.signAndExecuteTransaction({
      transaction: tx,
    });

  if (!result?.digest) {
    throw new Error(
      "Wallet did not return a transaction digest."
    );
  }

  const txResult =
    await client.waitForTransaction({
      digest: result.digest,
      options: {
        showEffects: true,
        showObjectChanges: true,
        showEvents: true,
      },
    });

  if (
    txResult.effects?.status?.status !==
    "success"
  ) {
    throw new Error(
      txResult.effects?.status?.error ||
        "Deposit transaction failed."
    );
  }

  return {
    digest: result.digest,
    transaction: txResult,
  };
}

// ============================================================
// WITHDRAW / CANCEL BEFORE COMPLETE
// ============================================================

export async function withdrawBeforeComplete({
  wallet,
  escrowId,
}) {
  if (!escrowId) {
    throw new Error(
      "Escrow Object ID is required."
    );
  }

  const tx = new Transaction();

  tx.moveCall({
    target:
      `${PACKAGE_ID}::escrow::withdraw_before_complete`,
    arguments: [
      tx.object(escrowId),
    ],
  });

  return executeEscrowTransaction({
    wallet,
    tx,
    errorMessage:
      "Withdraw transaction failed.",
  });
}

// ============================================================
// FINALIZATION
// ============================================================

async function executeEscrowTransaction({
  wallet,
  tx,
  errorMessage,
}) {
  if (!wallet?.connected || !wallet?.address) {
    throw new Error(
      "Please connect your wallet first."
    );
  }

  tx.setSender(wallet.address);

  const result =
    await wallet.signAndExecuteTransaction({
      transaction: tx,
    });

  if (!result?.digest) {
    throw new Error(
      "Wallet did not return a transaction digest."
    );
  }

  const txResult =
    await client.waitForTransaction({
      digest: result.digest,
      options: {
        showEffects: true,
        showObjectChanges: true,
        showEvents: true,
      },
    });

  if (
    txResult.effects?.status?.status !==
    "success"
  ) {
    throw new Error(
      txResult.effects?.status?.error ||
        errorMessage
    );
  }

  return {
    digest: result.digest,
    transaction: txResult,
  };
}

// ============================================================
// SUGGEST FINALIZATION
// ============================================================

export async function suggestFinalization({
  wallet,
  escrowId,
  payoutA,
  payoutB,
  proposedDonation = 0,
  note = "",
}) {
  if (!wallet?.connected || !wallet?.address) {
    throw new Error(
      "Please connect your wallet first."
    );
  }

  if (!escrowId) {
    throw new Error(
      "Escrow Object ID is required."
    );
  }

  const tx = new Transaction();

  tx.moveCall({
    target:
      `${PACKAGE_ID}::escrow::suggest_finalization`,

    arguments: [
      tx.object(escrowId),

      tx.pure.u64(payoutA),

      tx.pure.u64(payoutB),

      tx.pure.u64(proposedDonation),

      tx.pure.vector(
        "u8",
        textToBytes(note)
      ),
    ],
  });

  console.log(
    "Suggesting finalization:",
    escrowId
  );

  console.log(
    "Payout A:",
    payoutA
  );

  console.log(
    "Payout B:",
    payoutB
  );

  console.log(
    "Donation:",
    proposedDonation
  );

  return executeEscrowTransaction({
    wallet,
    tx,
    errorMessage:
      "Suggest finalization transaction failed.",
  });
}

// ============================================================
// ACCEPT FINALIZATION
// ============================================================

export async function acceptFinalization({
  wallet,
  escrowId,
}) {
  if (!escrowId) {
    throw new Error(
      "Escrow Object ID is required."
    );
  }

  const tx = new Transaction();

  tx.moveCall({
    target:
      `${PACKAGE_ID}::escrow::accept_finalization`,

    arguments: [
      tx.object(escrowId),
      tx.object(CLOCK_OBJECT_ID),
    ],
  });

  console.log(
    "Accepting finalization:",
    escrowId
  );

  return executeEscrowTransaction({
    wallet,
    tx,
    errorMessage:
      "Accept finalization transaction failed.",
  });
}

// ============================================================
// REJECT FINALIZATION
// ============================================================

export async function rejectFinalization({
  wallet,
  escrowId,
}) {
  if (!escrowId) {
    throw new Error(
      "Escrow Object ID is required."
    );
  }

  const tx = new Transaction();

  tx.moveCall({
    target:
      `${PACKAGE_ID}::escrow::reject_finalization`,

    arguments: [
      tx.object(escrowId),
    ],
  });

  console.log(
    "Rejecting finalization:",
    escrowId
  );

  return executeEscrowTransaction({
    wallet,
    tx,
    errorMessage:
      "Reject finalization transaction failed.",
  });
}

// ============================================================
// CREATE ESCROW
// ============================================================

export async function createEscrow({
  wallet,
  escrowType,
  partyA,
  partyB,
  referenceAmount,
  requiredDepositA,
  requiredDepositB,
  note,
}) {
  if (!wallet?.connected || !wallet?.address) {
    throw new Error("Please connect your wallet first.");
  }

  const tx = new Transaction();

  tx.setSender(wallet.address);

  tx.moveCall({
    target: `${PACKAGE_ID}::escrow::create_escrow`,

    arguments: [
      // escrow_type: u8
      tx.pure.u8(escrowType),

      // party_a: Option<address>
      addressOption(tx, partyA),

      // party_b: Option<address>
      addressOption(tx, partyB),

      // reference_amount: u64
      tx.pure.u64(referenceAmount),

      // required_deposit_a: u64
      tx.pure.u64(requiredDepositA),

      // required_deposit_b: u64
      tx.pure.u64(requiredDepositB),

      // note: vector<u8>
      tx.pure.vector(
        "u8",
        textToBytes(note)
      ),

      // clock: &Clock
      tx.object(CLOCK_OBJECT_ID),
    ],
  });

  console.log("Creating escrow...");
  console.log("Party A:", partyA || "Unassigned");
  console.log("Party B:", partyB || "Unassigned");
  console.log("Reference:", referenceAmount);
  console.log("Required A:", requiredDepositA);
  console.log("Required B:", requiredDepositB);

  // Wallet popup / approval happens here.
  const result = await wallet.signAndExecuteTransaction({
    transaction: tx,
  });

  console.log("Wallet transaction result:", result);

  if (!result?.digest) {
    throw new Error("Wallet did not return a transaction digest.");
  }

  // Fetch the full transaction from Devnet.
  const txResult = await client.waitForTransaction({
    digest: result.digest,
    options: {
      showEffects: true,
      showObjectChanges: true,
      showEvents: true,
    },
  });

  console.log("Confirmed transaction:", txResult);

  if (txResult.effects?.status?.status !== "success") {
    throw new Error(
      txResult.effects?.status?.error ||
        "Create escrow transaction failed."
    );
  }

  // Find the newly created shared Escrow object.
  const createdEscrow = txResult.objectChanges?.find(
    (change) =>
      change.type === "created" &&
      change.objectType ===
        `${PACKAGE_ID}::escrow::Escrow`
  );

  if (!createdEscrow?.objectId) {
    console.error(
      "Object changes:",
      txResult.objectChanges
    );

    throw new Error(
      "Transaction succeeded, but Escrow Object ID was not found."
    );
  }

  console.log(
    "Created Escrow:",
    createdEscrow.objectId
  );

  return {
    digest: result.digest,
    escrowObjectId: createdEscrow.objectId,
  };
  
}