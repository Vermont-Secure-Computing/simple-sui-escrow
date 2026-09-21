import React from "react";
import ReactDOM from "react-dom/client";

import {
  createDAppKit,
  DAppKitProvider,
} from "@mysten/dapp-kit-react";

import { SuiGrpcClient } from "@mysten/sui/grpc";

import App from "./App.jsx";
import "./index.css";

const GRPC_URLS = {
  devnet: "https://fullnode.devnet.sui.io:443",
};

export const dAppKit = createDAppKit({
  networks: ["devnet"],
  defaultNetwork: "devnet",

  createClient(network) {
    return new SuiGrpcClient({
      network,
      baseUrl: GRPC_URLS[network],
    });
  },

  autoConnect: true,
});

ReactDOM.createRoot(
  document.getElementById("root")
).render(
  <React.StrictMode>
    <DAppKitProvider dAppKit={dAppKit}>
      <App />
    </DAppKitProvider>
  </React.StrictMode>
);
