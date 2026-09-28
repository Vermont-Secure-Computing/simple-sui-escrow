import { useState } from "react";
import { createPortal } from "react-dom";
import {
  useCurrentAccount,
  useCurrentWallet,
  useDAppKit,
  useWallets,
} from "@mysten/dapp-kit-react";

const WALLET_CATALOG = [
  {
    id: "slush",
    name: "Slush",
    aliases: ["slush", "sui wallet"],
    installUrl: "https://slush.app/",
  },
  {
    id: "suiet",
    name: "Suiet",
    aliases: ["suiet"],
    installUrl: "https://suiet.app/",
  },
  {
    id: "surf",
    name: "Surf Wallet",
    aliases: ["surf", "surf wallet"],
    installUrl: "https://surf.tech/",
  },
  {
    id: "nightly",
    name: "Nightly",
    aliases: ["nightly", "nightly wallet"],
    installUrl: "https://nightly.app/",
  },
  {
    id: "okx",
    name: "OKX Wallet",
    aliases: ["okx", "okx wallet"],
    installUrl: "https://web3.okx.com/download",
  },
  {
    id: "bitget",
    name: "Bitget Wallet",
    aliases: ["bitget", "bitget wallet"],
    installUrl: "https://web3.bitget.com/",
  },
];

function normalizeName(name = "") {
  return name.toLowerCase().trim();
}

function findDetectedWallet(catalogWallet, detectedWallets) {
  return detectedWallets.find((wallet) => {
    const detectedName = normalizeName(wallet.name);

    return catalogWallet.aliases.some((alias) => {
      const normalizedAlias = normalizeName(alias);

      return (
        detectedName === normalizedAlias ||
        detectedName.includes(normalizedAlias)
      );
    });
  });
}

function shortAddress(address) {
  if (!address) return "";

  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export default function WalletButton() {
  const dAppKit = useDAppKit();
  const wallets = useWallets();
  const account = useCurrentAccount();
  const currentWallet = useCurrentWallet();

  const [showModal, setShowModal] = useState(false);
  const [showAccountMenu, setShowAccountMenu] = useState(false);
  const [connecting, setConnecting] = useState(null);
  const [error, setError] = useState("");
  const [copied, setCopied] = useState(false);

  const connectWallet = async (wallet) => {
    try {
      setError("");
      setConnecting(wallet.name);

      await dAppKit.connectWallet({
        wallet,
      });

      setShowModal(false);
    } catch (err) {
      console.error("Wallet connection failed:", err);

      setError(err?.message || "Unable to connect wallet. Please try again.");
    } finally {
      setConnecting(null);
    }
  };

  const disconnectWallet = async () => {
    try {
      await dAppKit.disconnectWallet();

      setShowAccountMenu(false);
    } catch (err) {
      console.error("Wallet disconnect failed:", err);
    }
  };

  const copyAddress = async () => {
    if (!account?.address) return;

    try {
      await navigator.clipboard.writeText(account.address);

      setCopied(true);

      setTimeout(() => {
        setCopied(false);
      }, 1500);
    } catch (err) {
      console.error("Unable to copy address:", err);
    }
  };

  const installWallet = (url) => {
    window.open(url, "_blank", "noopener,noreferrer");
  };

  /*
   * Wallets in our recommended catalog.
   * Each one may or may not currently be installed.
   */
  const catalogWallets = WALLET_CATALOG.map((catalogWallet) => ({
    ...catalogWallet,

    detectedWallet: findDetectedWallet(catalogWallet, wallets),
  }));

  /*
   * Include detected wallets that aren't already
   * part of our catalog, e.g. Glass or future wallets.
   */
  const extraDetectedWallets = wallets.filter((wallet) => {
    return !WALLET_CATALOG.some((catalogWallet) =>
      findDetectedWallet(catalogWallet, [wallet])
    );
  });

  /*
   * CONNECTED STATE
   */
  if (account) {
    return (
      <div className="relative">
        <button
          type="button"
          onClick={() => setShowAccountMenu(!showAccountMenu)}
          className="
            flex items-center gap-2
            rounded-full
            border border-cyan-500/20
            bg-black
            px-4 py-2
            text-sm font-medium text-white
            transition
            hover:border-cyan-400/40
            hover:bg-cyan-500/10
          "
        >
          {currentWallet?.icon && (
            <img
              src={currentWallet.icon}
              alt=""
              className="h-5 w-5 rounded-md"
            />
          )}

          <span className="hidden sm:inline">
            {shortAddress(account.address)}
          </span>

          <span className="sm:hidden">Wallet</span>

          <span className="text-slate-400">▾</span>
        </button>

        {showAccountMenu && (
          <>
            <button
              type="button"
              aria-label="Close wallet menu"
              className="fixed inset-0 z-40 cursor-default"
              onClick={() => setShowAccountMenu(false)}
            />

            <div
              className="
                absolute right-0 top-full z-50
                mt-2 w-64
                overflow-hidden
                rounded-2xl
                border border-white/10
                bg-slate-950
                shadow-2xl
              "
            >
              <div className="border-b border-white/10 p-4">
                <div className="flex items-center gap-3">
                  {currentWallet?.icon && (
                    <img
                      src={currentWallet.icon}
                      alt=""
                      className="h-9 w-9 rounded-xl"
                    />
                  )}

                  <div className="min-w-0">
                    <div className="truncate text-sm font-semibold text-white">
                      {currentWallet?.name || "Sui Wallet"}
                    </div>

                    <div className="mt-0.5 text-xs text-slate-400">Devnet</div>
                  </div>
                </div>

                <div
                  className="
                    mt-3 rounded-xl
                    bg-white/5
                    px-3 py-2
                    font-mono
                    text-xs text-slate-300
                  "
                >
                  {shortAddress(account.address)}
                </div>
              </div>

              <div className="p-2">
                <button
                  type="button"
                  onClick={copyAddress}
                  className="
                    w-full rounded-xl
                    px-3 py-2.5
                    text-left text-sm
                    text-slate-300
                    transition
                    hover:bg-white/5
                    hover:text-white
                  "
                >
                  {copied ? "✓ Address copied" : "Copy address"}
                </button>

                <button
                  type="button"
                  onClick={disconnectWallet}
                  className="
                    w-full rounded-xl
                    px-3 py-2.5
                    text-left text-sm
                    text-red-400
                    transition
                    hover:bg-red-500/10
                  "
                >
                  Disconnect
                </button>
              </div>
            </div>
          </>
        )}
      </div>
    );
  }

  /*
   * DISCONNECTED STATE
   */
  return (
    <>
      <button
        type="button"
        onClick={() => {
          setError("");
          setShowModal(true);
        }}
        className="
          rounded-full
          border border-cyan-500/20
          bg-black
          px-5 py-2
          text-sm font-medium text-white
          transition
          hover:border-cyan-400/40
          hover:bg-cyan-500/10
        "
      >
        Connect Wallet
      </button>

      {showModal &&
        createPortal(
          <div
            className="
        fixed inset-0
        z-[999999]
        flex
        items-center
        justify-center
        overflow-y-auto
        bg-black/75
        p-4
        backdrop-blur-sm
      "
            onClick={() => setShowModal(false)}
          >
            <div
              className="
          relative
          flex
          w-full
          max-w-md
          max-h-[calc(100dvh-2rem)]
          flex-col
          overflow-hidden
          rounded-3xl
          border border-white/10
          bg-slate-950
          shadow-2xl
        "
              onClick={(event) => event.stopPropagation()}
            >
              {/* HEADER */}

              <div
                className="
            flex
            shrink-0
            items-start
            justify-between
            border-b border-white/10
            p-5
          "
              >
                <div>
                  <h2 className="text-xl font-bold text-white">
                    Connect Wallet
                  </h2>

                  <p className="mt-1 text-sm text-slate-400">
                    Choose a wallet to connect to ssscrow
                  </p>
                </div>

                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="
              flex h-9 w-9
              shrink-0
              items-center
              justify-center
              rounded-full
              text-xl
              text-slate-400
              transition
              hover:bg-white/10
              hover:text-white
            "
                >
                  ×
                </button>
              </div>

              {/* WALLET LIST */}

              <div
                className="
            min-h-0
            flex-1
            overflow-y-auto
            overscroll-contain
            p-3
          "
              >
                {catalogWallets.map((wallet) => {
                  const detected = wallet.detectedWallet;

                  const isConnecting = connecting === detected?.name;

                  return (
                    <button
                      key={wallet.id}
                      type="button"
                      disabled={connecting !== null && !isConnecting}
                      onClick={() => {
                        if (detected) {
                          connectWallet(detected);
                        } else {
                          installWallet(wallet.installUrl);
                        }
                      }}
                      className="
                  group
                  flex w-full
                  items-center
                  justify-between
                  rounded-2xl
                  border
                  border-transparent
                  px-3 py-3
                  text-left
                  transition
                  hover:border-cyan-500/20
                  hover:bg-cyan-500/5
                  disabled:cursor-not-allowed
                  disabled:opacity-50
                "
                    >
                      <div className="flex min-w-0 items-center gap-3">
                        {detected?.icon ? (
                          <img
                            src={detected.icon}
                            alt=""
                            className="
                        h-10 w-10
                        shrink-0
                        rounded-xl
                      "
                          />
                        ) : (
                          <div
                            className="
                        flex h-10 w-10
                        shrink-0
                        items-center
                        justify-center
                        rounded-xl
                        border border-white/10
                        bg-white/5
                        text-sm
                        font-bold
                        text-slate-300
                      "
                          >
                            {wallet.name.charAt(0).toUpperCase()}
                          </div>
                        )}

                        <div className="min-w-0">
                          <div className="truncate font-medium text-white">
                            {wallet.name}
                          </div>

                          <div className="mt-0.5 text-xs text-slate-500">
                            {detected ? "Installed" : "Not installed"}
                          </div>
                        </div>
                      </div>

                      <span
                        className={
                          detected
                            ? "text-sm font-medium text-cyan-400"
                            : "text-sm font-medium text-slate-400 group-hover:text-cyan-400"
                        }
                      >
                        {isConnecting
                          ? "Connecting..."
                          : detected
                          ? "Connect"
                          : "Install ↗"}
                      </span>
                    </button>
                  );
                })}

                {/* OTHER DETECTED WALLETS */}

                {extraDetectedWallets.length > 0 && (
                  <>
                    <div className="mx-3 my-3 border-t border-white/10" />

                    <div
                      className="
                  px-3 pb-2 pt-1
                  text-xs
                  font-medium
                  uppercase
                  tracking-wider
                  text-slate-500
                "
                    >
                      Other detected wallets
                    </div>

                    {extraDetectedWallets.map((wallet) => (
                      <button
                        key={wallet.name}
                        type="button"
                        disabled={connecting !== null}
                        onClick={() => connectWallet(wallet)}
                        className="
                      flex w-full
                      items-center
                      justify-between
                      rounded-2xl
                      border border-transparent
                      px-3 py-3
                      text-left
                      transition
                      hover:border-cyan-500/20
                      hover:bg-cyan-500/5
                      disabled:opacity-50
                    "
                      >
                        <div className="flex items-center gap-3">
                          {wallet.icon ? (
                            <img
                              src={wallet.icon}
                              alt=""
                              className="h-10 w-10 rounded-xl"
                            />
                          ) : (
                            <div
                              className="
                            flex h-10 w-10
                            items-center
                            justify-center
                            rounded-xl
                            bg-white/5
                            font-bold
                            text-white
                          "
                            >
                              {wallet.name.charAt(0).toUpperCase()}
                            </div>
                          )}

                          <div>
                            <div className="font-medium text-white">
                              {wallet.name}
                            </div>

                            <div className="text-xs text-slate-500">
                              Installed
                            </div>
                          </div>
                        </div>

                        <span className="text-sm font-medium text-cyan-400">
                          {connecting === wallet.name
                            ? "Connecting..."
                            : "Connect"}
                        </span>
                      </button>
                    ))}
                  </>
                )}

                {error && (
                  <div
                    className="
                mx-3 mt-3
                rounded-xl
                border border-red-500/20
                bg-red-500/10
                p-3
                text-sm text-red-300
              "
                  >
                    {error}
                  </div>
                )}
              </div>

              {/* FOOTER */}

              <div
                className="
            shrink-0
            border-t border-white/10
            px-5 py-4
            text-center
            text-xs text-slate-500
          "
              >
                Never share your recovery phrase with ssscrow or any website.
              </div>
            </div>
          </div>,
          document.body
        )}
    </>
  );
}
