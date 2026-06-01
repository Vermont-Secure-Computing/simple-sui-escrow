function EscrowCard({ escrow }) {

    const fields =
      escrow.data?.content?.fields;
  
    if (!fields) return null;
  
    return (
  
      <div className="rounded-2xl border border-slate-700 bg-slate-950 p-5">
  
        <p>
          <strong>Escrow ID:</strong>
        </p>
  
        <code className="break-all">
          {escrow.data.objectId}
        </code>
  
        <p className="mt-4">
          Buyer:
        </p>
  
        <code className="break-all">
          {fields.buyer}
        </code>
  
        <p className="mt-4">
          Seller:
        </p>
  
        <code className="break-all">
          {fields.seller}
        </code>
  
        <p className="mt-4">
          Status:
        </p>
  
        <code>
          {fields.status}
        </code>
  
      </div>
  
    );
  }
  
  export default EscrowCard;