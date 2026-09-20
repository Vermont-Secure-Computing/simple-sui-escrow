import React from "react";
import ReactDOM from "react-dom/client";

import {
  WalletProvider,
} from "@suiet/wallet-kit";

import "@suiet/wallet-kit/style.css";

import App from "./App.jsx";
import "./index.css";

const SuiLocalnetChain = {
  id: "sui:localnet",
  name: "Sui Localnet",
  rpcUrl: "http://127.0.0.1:9000",
};

const chains = [
  SuiLocalnetChain,
];

ReactDOM.createRoot(
  document.getElementById("root")
).render(
  <React.StrictMode>
    <WalletProvider
      chains={chains}
      autoConnect={false}
    >
      <App />
    </WalletProvider>
  </React.StrictMode>
);