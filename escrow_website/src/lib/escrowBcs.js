import { bcs } from "@mysten/sui/bcs";

const Balance = bcs.struct("Balance", {
  value: bcs.u64(),
});

export const EscrowBcs = bcs.struct("Escrow", {
  id: bcs.Address,
  creator: bcs.Address,
  party_a: bcs.option(bcs.Address),
  party_b: bcs.option(bcs.Address),

  escrow_type: bcs.u8(),

  reference_amount: bcs.u64(),
  required_deposit_a: bcs.u64(),
  required_deposit_b: bcs.u64(),

  deposited_a: bcs.u64(),
  deposited_b: bcs.u64(),

  vault: Balance,

  proposed_payout_a: bcs.u64(),
  proposed_payout_b: bcs.u64(),
  proposed_donation: bcs.u64(),

  finalization_proposer: bcs.option(bcs.Address),
  finalization_note: bcs.vector(bcs.u8()),

  status: bcs.u8(),

  created_at: bcs.u64(),
  deposit_at: bcs.u64(),
  finalized_at: bcs.u64(),

  note: bcs.vector(bcs.u8()),
});

export function decodeEscrow(content) {
  return EscrowBcs.parse(content);
}
