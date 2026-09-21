import { useState } from "react";
import { client } from "../lib/sui";
import EscrowCard from "./EscrowCard";
import { decodeEscrow } from "../lib/escrowBcs.js";

function LookupEscrow() {

  const [escrowId, setEscrowId] = useState("");
  const [escrow, setEscrow] = useState(null);
  const [loading, setLoading] = useState(false);

  const handleLookup = async (
    id = escrowId
  ) => {
    try {
      setLoading(true);
  
      const lookupId =
        typeof id === "string"
          ? id.trim()
          : escrowId.trim();
  
          const result =
          await client.getObject({
            objectId: lookupId,
            include: {
              content: true,
              previousTransaction: true,
            },
          });
        
          console.log(
            "=== GRPC ESCROW OBJECT ===",
            result
          );
          
          const decoded = decodeEscrow(
            result.object.content
          );
          
          console.log(
            "=== DECODED ESCROW ===",
            decoded
          );
          
          setEscrow({
            data: {
              objectId: result.object.objectId,
              content: {
                fields: decoded,
              },
              owner: result.object.owner,
              type: result.object.type,
              version: result.object.version,
              digest: result.object.digest,
            },
          });
    } catch (err) {
      console.error(err);
      alert("Escrow not found");
    } finally {
      setLoading(false);
    }
  };

  return (
    <section className="rounded-2xl border border-slate-700 bg-slate-900 p-6 text-white">

      <h2 className="text-2xl font-bold">
        Look Up Escrow
      </h2>

      <div className="mt-5 flex gap-3">

        <input
          value={escrowId}
          onChange={(e) => setEscrowId(e.target.value)}
          placeholder="Escrow Object ID"
          className="flex-1 rounded-xl border border-slate-700 bg-slate-950 px-4 py-3"
        />

        <button
          onClick={handleLookup}
          className="rounded-xl bg-blue-600 px-5 py-3 font-bold"
        >
          Search
        </button>

      </div>

      {escrow && (
        <div className="mt-6">
          <EscrowCard
            escrow={escrow}
            onRefresh={() =>
              handleLookup(escrow.data.objectId)
            }
          />
        </div>
      )}

    </section>
  );
}

export default LookupEscrow;