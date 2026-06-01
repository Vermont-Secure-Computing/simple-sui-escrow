import { SuiClient, getFullnodeUrl } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";

export const client = new SuiClient({
  url: getFullnodeUrl("testnet"),
});

export const PACKAGE_ID =
  "0xee69e16ec90cc202f64e92156c264d088d867ff780b535a21037877561b1a241";

  export async function createEscrow(
    wallet,
    buyer,
    seller,
    price,
    buyerBond,
    sellerBond,
    note
  ) {
    const tx = new Transaction();
  
    tx.moveCall({
      target: `${PACKAGE_ID}::escrow::create_escrow`,
      arguments: [
        tx.pure.address(buyer),
        tx.pure.address(seller),
        tx.pure.u64(price),
        tx.pure.u64(buyerBond),
        tx.pure.u64(sellerBond),
        tx.pure.vector(
          "u8",
          Array.from(new TextEncoder().encode(note))
        ),
      ],
    });
  
    const result =
      await wallet.signAndExecuteTransaction({
        transaction: tx,
        options: {
          showObjectChanges: true,
        },
      });

      console.log("RESULT");
      console.log(result);

      console.log("OBJECT CHANGES");
      console.log(result.objectChanges);

      const txResult = await client.getTransactionBlock({
        digest: result.digest,
        options: {
          showObjectChanges: true,
        },
      });
      
      console.log(txResult);
      console.log(txResult.objectChanges);
  
    const createdEscrow =
      txResult.objectChanges?.find(
        (obj) =>
          obj.type === "created" &&
          obj.objectType.includes("::escrow::Escrow")
      );
  
    return {
      digest: result.digest,
      escrowObjectId:
        createdEscrow?.objectId,
    };
  }