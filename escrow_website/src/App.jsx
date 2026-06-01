import "./App.css";

import { ConnectButton } from "@suiet/wallet-kit";

import CreateEscrow from "./components/CreateEscrow";
import LookupEscrow from "./components/LookupEscrow";
import MyEscrows from "./components/MyEscrows";

function App() {

  return (

    <div className="min-h-screen bg-slate-950 p-10">

      <div className="mb-6">
        <ConnectButton />
      </div>

      <div className="grid gap-6">

        <CreateEscrow />

        <LookupEscrow />

        <MyEscrows />

      </div>

    </div>
  );
}

export default App;