import { useEffect, useState } from "react";
import { useEscrowWallet } from "../lib/useEscrowWallet.js";

import { client } from "../lib/sui";
import EscrowCard from "./EscrowCard";

function MyEscrows() {

  const wallet = useEscrowWallet();

  const [escrows, setEscrows] = useState([]);
  const [loading, setLoading] = useState(false);

  async function loadEscrows() {

    if (!wallet.address) return;

    try {

      setLoading(true);

      const result =
        await client.getOwnedObjects({

          owner: wallet.address,

          options: {
            showContent: true,
          },
        });

      const escrows = result.data.filter(
        (item) =>
          item.data?.type?.includes("::escrow::Escrow")
      );

      setEscrows(escrows);

    } finally {

      setLoading(false);

    }
  }

  useEffect(() => {
    loadEscrows();
  }, [wallet.address]);

  return (
    <section className="rounded-2xl border border-slate-700 bg-slate-900 p-6 text-white">

      <div className="flex justify-between">

        <h2 className="text-2xl font-bold">
          My Escrows
        </h2>

        <button
          onClick={loadEscrows}
          className="rounded-xl bg-blue-600 px-4 py-2"
        >
          Refresh
        </button>

      </div>

      {loading && (
        <p className="mt-4">Loading...</p>
      )}

      {!loading && escrows.length === 0 && (
        <p className="mt-4">
          No escrows found.
        </p>
      )}

      <div className="mt-6 grid gap-4">

        {escrows.map((escrow) => (
          <EscrowCard
            key={escrow.data.objectId}
            escrow={escrow}
          />
        ))}

      </div>

    </section>
  );
}

export default MyEscrows;