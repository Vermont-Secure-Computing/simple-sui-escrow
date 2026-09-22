import { useCallback, useEffect, useState } from "react";

import { useEscrowWallet } from "../lib/useEscrowWallet";
import {
  client,
  PACKAGE_ID,
} from "../lib/sui";
import { decodeEscrow } from "../lib/escrowBcs";
import EscrowCard from "./EscrowCard";

function normalizeAddress(address) {
  if (!address) return null;
  return address.toLowerCase();
}

function decodeText(bytes) {
  if (!bytes) return "";

  try {
    return new TextDecoder().decode(
      new Uint8Array(bytes)
    );
  } catch {
    return "";
  }
}


export default function MyEscrows() {
  const wallet = useEscrowWallet();

  const [escrows, setEscrows] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const loadEscrows = useCallback(async () => {
    if (!wallet.address) {
      setEscrows([]);
      return;
    }

    setLoading(true);
    setError("");

    try {
      const escrowIds = new Set();

      let before = null;
      let pageCount = 0;

      while (pageCount < 100) {
        const response =
          await client.listEvents({
            filter: {
              emitModule:
                `${PACKAGE_ID}::escrow`,
            },

            limit: 50,
            order: "descending",

            ...(before
              ? { before }
              : {}),
          });

        for (
          const event of
          response.events ?? []
        ) {
          const json = event.json;

          if (json?.escrow_id) {
            escrowIds.add(
              json.escrow_id
            );
          }
        }

        pageCount += 1;

        if (
          !response.hasNextPage ||
          !response.endCursor
        ) {
          break;
        }

        before =
          response.endCursor;
      }

      if (escrowIds.size === 0) {
        setEscrows([]);
        return;
      }

      const objects = [];

      for (const objectId of escrowIds) {
        try {
          const result =
            await client.getObject({
              objectId,

              include: {
                content: true,
              },
            });

          if (
            !result.object ||
            !result.object.content
          ) {
            continue;
          }

          const fields =
            decodeEscrow(
              result.object.content
            );

            objects.push({
              objectId: result.object.objectId,
              fields,
              cardData: {
                data: {
                  objectId: result.object.objectId,
                  content: {
                    fields,
                  },
                },
              },
            });
        } catch (objectError) {
          console.warn(
            "Unable to load escrow:",
            objectId,
            objectError
          );
        }
      }

      const connected =
        normalizeAddress(
          wallet.address
        );

        const mine = objects
        .filter(({ fields }) => {
          const creator =
            normalizeAddress(fields.creator);
      
          const partyA =
            normalizeAddress(fields.party_a);
      
          const partyB =
            normalizeAddress(fields.party_b);
      
          return (
            creator === connected ||
            partyA === connected ||
            partyB === connected
          );
        })
        .sort((a, b) => {
          return (
            Number(b.fields.created_at) -
            Number(a.fields.created_at)
          );
        });

      setEscrows(mine);
    } catch (err) {
      console.error(
        "Failed to load My Escrows:",
        err
      );

      setError(
        err?.message ||
          "Unable to load escrows."
      );
    } finally {
      setLoading(false);
    }
  }, [wallet.address]);

  useEffect(() => {
    loadEscrows();
  }, [loadEscrows]);

  if (!wallet.connected) {
    return (
      <section className="rounded-2xl border border-white/10 bg-white/5 p-6">
        <h2 className="text-xl font-bold text-white">
          My Escrows
        </h2>

        <p className="mt-2 text-slate-400">
          Connect your wallet to view escrows.
        </p>
      </section>
    );
  }

  return (
    <section className="rounded-2xl border border-white/10 bg-white/5 p-6">

      <div className="flex items-center justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-white">
            My Escrows
          </h2>
        </div>

        <button
          type="button"
          onClick={loadEscrows}
          disabled={loading}
          className="rounded-xl bg-blue-600 px-4 py-2 font-bold text-white disabled:opacity-50"
        >
          {loading
            ? "Loading..."
            : "Refresh"}
        </button>
      </div>

      {error && (
        <div className="mt-6 rounded-xl border border-red-800 bg-red-950/50 p-4 text-red-300">
          {error}
        </div>
      )}

      {loading &&
        escrows.length === 0 && (
          <div className="mt-6 rounded-xl bg-slate-900 p-4 text-slate-400">
            Loading your escrows...
          </div>
        )}

      {!loading &&
      escrows.length === 0 &&
      !error ? (
        <div className="mt-6 rounded-xl bg-slate-900 p-4 text-slate-400">
          No escrows found for this wallet.
        </div>
      ) : (
        <div className="mt-6 grid gap-4">
          {escrows.map((escrow) => (
            <EscrowCard
              key={escrow.objectId}
              escrow={escrow.cardData}
              onRefresh={loadEscrows}
            />
          ))}
        </div>
      )}
    </section>
  );
}