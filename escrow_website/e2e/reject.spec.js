import { test as base, expect, chromium } from "@playwright/test";
import path from "node:path";
import dotenv from "dotenv";

dotenv.config({
    path: ".env.e2e",
  });
  
  const E2E_PRIVATE_KEY =
    process.env.E2E_SUI_PRIVATE_KEY;
  
  const E2E_ADDRESS =
    process.env.E2E_SUI_ADDRESS;

    const E2E_PARTY_B_PRIVATE_KEY =
    process.env.E2E_PARTY_B_PRIVATE_KEY;
  
  const E2E_PARTY_B_ADDRESS =
    process.env.E2E_PARTY_B_ADDRESS;
  
  if (!E2E_PRIVATE_KEY) {
    throw new Error(
      "E2E_SUI_PRIVATE_KEY missing from .env.e2e"
    );
  }
  
  if (!E2E_ADDRESS) {
    throw new Error(
      "E2E_SUI_ADDRESS missing from .env.e2e"
    );
  }

  if (!E2E_PARTY_B_PRIVATE_KEY) {
    throw new Error(
      "E2E_PARTY_B_PRIVATE_KEY missing from .env.e2e"
    );
  }
  
  if (!E2E_PARTY_B_ADDRESS) {
    throw new Error(
      "E2E_PARTY_B_ADDRESS missing from .env.e2e"
    );
  }

const extensionPath = path.resolve(
  "../sui-test-wallet/dist"
);

const userDataDir = path.resolve(
    "./e2e/wallet-profile-localnet"
  );

async function sendAutomation(page, message) {
    return page.evaluate(async (request) => {
      return new Promise((resolve) => {
        const handler = (event) => {
          if (
            event.source !== window ||
            event.data?.type !==
              "SUI_TEST_WALLET_AUTOMATION_RESPONSE" ||
            event.data?.id !== request.id
          ) {
            return;
          }
  
          window.removeEventListener(
            "message",
            handler
          );
  
          resolve(
            event.data.response ?? {
              error: event.data.error,
            }
          );
        };
  
        window.addEventListener(
          "message",
          handler
        );
  
        window.postMessage(
          request,
          "*"
        );
      });
    }, message);
  }

base("Sui test wallet is detected by frontend", async () => {
  console.log("\n============================================================");
  console.log("Sui Escrow Wallet E2E");
  console.log("============================================================");

  console.log("Extension:", extensionPath);

  // ==========================================================
  // 1. START CHROMIUM WITH SUI TEST WALLET
  // ==========================================================

  const context = await chromium.launchPersistentContext(
    userDataDir,
    {
      headless: false,

      args: [
        `--disable-extensions-except=${extensionPath}`,
        `--load-extension=${extensionPath}`,
      ],
    }
  );

  try {
    // ========================================================
    // 2. CHECK EXTENSION
    // ========================================================

    let serviceWorker = context.serviceWorkers()[0];

    if (!serviceWorker) {
      serviceWorker = await context.waitForEvent(
        "serviceworker"
      );
    }

    console.log(
      "✓ PASS: Wallet extension loaded"
    );

    console.log(
      "Extension URL:",
      serviceWorker.url()
    );

    // ========================================================
    // 3. OPEN ESCROW WEBSITE
    // ========================================================

    const pages = context.pages();

    const page =
  pages.length > 0
    ? pages[0]
    : await context.newPage();

    page.on("console", (msg) => {
        console.log(`[BROWSER ${msg.type()}] ${msg.text()}`);
      });
      
      page.on("pageerror", (error) => {
        console.log(`[BROWSER ERROR] ${error.message}`);
      });

    

    await page.goto(
      "http://localhost:5173/escrow"
    );

    await expect(
      page.getByRole("heading", {
        name: /create escrow/i,
      })
    ).toBeVisible();

    console.log(
      "✓ PASS: Escrow frontend opened"
    );

    // ========================================================
// IMPORT DEDICATED E2E ACCOUNT
// ========================================================

const importResult = await sendAutomation(
    page,
    {
      type: "SUI_TEST_WALLET_AUTOMATION",
      action: "IMPORT_KEY",
      id: "import-e2e-key",
      bech32Key: E2E_PRIVATE_KEY,
      alias: "Escrow E2E",
    }
  );
  
  console.log(
    "Import result:",
    importResult
  );
  
  if (importResult?.error) {
    throw new Error(
      `Wallet import failed: ${importResult.error}`
    );
  }
  
  console.log(
    "✓ PASS: E2E account imported"
  );

  // ========================================================
// IMPORT PARTY B E2E ACCOUNT
// ========================================================
console.log(
    "Party B env debug:",
    {
      exists: !!E2E_PARTY_B_PRIVATE_KEY,
      type: typeof E2E_PARTY_B_PRIVATE_KEY,
      prefix:
        E2E_PARTY_B_PRIVATE_KEY?.startsWith(
          "suiprivkey1"
        ),
      length:
        E2E_PARTY_B_PRIVATE_KEY?.length,
      address:
        E2E_PARTY_B_ADDRESS,
    }
  );

  const importPartyBResult =
  await sendAutomation(
    page,
    {
      type: "SUI_TEST_WALLET_AUTOMATION",
      action: "IMPORT_KEY",
      id: "import-e2e-party-b",
      bech32Key:
        E2E_PARTY_B_PRIVATE_KEY,
      alias: "E2E Party B",
    }
  );

console.log(
"Party B import result:",
importPartyBResult
);

expect(
importPartyBResult.success
).toBe(true);

expect(
importPartyBResult.address
).toBe(
E2E_PARTY_B_ADDRESS
);

console.log(
"✓ PASS: Party B E2E account imported"
);

console.log(
"✓ Party B address:",
E2E_PARTY_B_ADDRESS
);

// ========================================================
// SWITCH ACTIVE ACCOUNT BACK TO PARTY A
// ========================================================

// ========================================================
// DEBUG ACTIVE ACCOUNT SWITCH
// ========================================================

const stateBeforeSwitch =
  await sendAutomation(
    page,
    {
      type: "SUI_TEST_WALLET_AUTOMATION",
      action: "GET_STATE",
      id: "state-before-switch",
    }
  );

console.log(
  "State before switch:",
  stateBeforeSwitch
);

const switchToPartyA =
  await sendAutomation(
    page,
    {
      type: "SUI_TEST_WALLET_AUTOMATION",
      action: "SET_ACTIVE_ACCOUNT",
      id: "switch-to-party-a",
      address: E2E_ADDRESS,
    }
  );

console.log(
  "Switch result:",
  switchToPartyA
);

const stateAfterSwitch =
  await sendAutomation(
    page,
    {
      type: "SUI_TEST_WALLET_AUTOMATION",
      action: "GET_STATE",
      id: "state-after-switch",
    }
  );

console.log(
  "State after switch:",
  stateAfterSwitch
);
  
  // ========================================================
  // SWITCH TEST WALLET TO DEVNET
  // ========================================================
  
  const networkResult = await sendAutomation(page, {
    type: "SUI_TEST_WALLET_AUTOMATION",
    id: `network-${Date.now()}`,
    action: "SET_NETWORK",
    payload: {
      network: "localnet",
    },
  });
  
  console.log("Network result:", networkResult);
  expect(networkResult.success).toBe(true);

  
  console.log("✓ PASS: Wallet network set to Localnet");
  
  console.log(
    "✓ E2E address:",
    E2E_ADDRESS
  );
  
  await page.waitForTimeout(1000);

    // ========================================================
    // 4. CONNECT WALLET IF NEEDED
    // ========================================================

    const connectButton = page.getByRole(
      "button",
      {
        name: /connect/i,
      }
    );

    const connectVisible = await connectButton
      .isVisible()
      .catch(() => false);

    if (connectVisible) {
      console.log(
        "✓ PASS: Connect Wallet button visible"
      );

      await connectButton.click();

      console.log(
        "✓ PASS: Wallet selector opened"
      );

      const testWallet = page.getByText(
        "Sui Test Wallet",
        {
          exact: true,
        }
      );

      await expect(
        testWallet
      ).toBeVisible();

      console.log(
        "✓ PASS: Sui Test Wallet detected"
      );

      await testWallet.click();

      console.log(
        "✓ PASS: Sui Test Wallet selected"
      );

      // Wait for wallet selector to disappear.
      await expect(
        page.getByText(
          "Popular",
          {
            exact: true,
          }
        )
      ).not.toBeVisible({
        timeout: 10_000,
      });

      console.log(
        "✓ PASS: Wallet selector closed"
      );
    } else {
      console.log(
        "✓ PASS: Wallet already connected from persistent profile"
      );
    }

    // Give React / wallet-kit time to update.
    await page.waitForTimeout(1000);

    // ========================================================
    // 5. SELECT BUYER
    // ========================================================

    const buyingButton = page.getByRole(
      "button",
      {
        name: /i.?m buying/i,
      }
    );

    await expect(
      buyingButton
    ).toBeVisible();

    await buyingButton.click();

    console.log(
      "✓ PASS: I'm Buying selected"
    );

    // ========================================================
    // 6. VERIFY WALLET CONNECTION
    // ========================================================

    const createButton = page.getByRole(
      "button",
      {
        name: /^create escrow$/i,
      }
    );

    await expect(
      createButton
    ).toBeVisible();

    await expect(
      createButton
    ).toBeEnabled({
      timeout: 10_000,
    });

    console.log(
      "✓ PASS: Wallet connected"
    );

    // ========================================================
// DEBUG WALLET STANDARD ACCOUNT
// ========================================================

const walletDebug = await page.evaluate(async () => {
    const discovered = [];
  
    window.dispatchEvent(
      new CustomEvent(
        "wallet-standard:app-ready",
        {
          detail: {
            register(wallet) {
              discovered.push(wallet);
            },
          },
        }
      )
    );
  
    await new Promise((resolve) =>
      setTimeout(resolve, 100)
    );
  
    const wallet = discovered.find(
      (candidate) =>
        candidate?.name === "Sui Test Wallet"
    );
  
    if (!wallet) {
      return {
        error: "Sui Test Wallet not discovered",
        discovered: discovered.map(
          (w) => w?.name
        ),
      };
    }
  
    const result =
      await wallet.features[
        "standard:connect"
      ].connect();
  
    const account = result.accounts?.[0];
  
    return {
      walletName: wallet.name,
      walletChains: [...wallet.chains],
      accountAddress: account?.address,
      accountChains: account?.chains
        ? [...account.chains]
        : [],
      accountFeatures: account?.features
        ? [...account.features]
        : [],
    };
  });
  
  console.log();
  console.log(
    "Wallet Standard debug:"
  );
  
  console.log(
    JSON.stringify(
      walletDebug,
      null,
      2
    )
  );


  console.log(
    "✓ PASS: Create Escrow button enabled"
  );
  
  // ========================================================
  // 7. CREATE REAL ESCROW ON LOCALNET
  // ========================================================
  
  console.log();
  console.log(
    "=== Creating real Localnet escrow ==="
  );
  
  // Price
  await page
    .getByPlaceholder("0.25")
    .fill("0.01");
  
  // Your refundable deposit
  await page
    .getByPlaceholder("0.05")
    .first()
    .fill("0.002");
  
  // Other party refundable deposit
  await page
    .getByPlaceholder("0.05")
    .nth(1)
    .fill("0.002");
  
  // Agreement note
  await page
    .getByPlaceholder(
      "Example: Website design project escrow"
    )
    .fill(
      "Playwright frontend E2E test"
    );
  
  // Check calculated deposits
  await expect(
    page.getByText(
      "0.0120 SUI required"
    )
  ).toBeVisible();
  
  await expect(
    page.getByText(
      "0.0020 SUI required"
    )
  ).toBeVisible();
  
  console.log(
    "✓ PASS: Escrow form filled"
  );
  
  // ========================================================
// SUBMIT REAL TRANSACTION
// ========================================================

console.log(
    "Clicking Create Escrow..."
  );
  
  await createButton.click();
  
  console.log(
    "✓ PASS: Create Escrow clicked"
  );
  
  // ========================================================
// AUTO-APPROVE WALLET TRANSACTION
// ========================================================

console.log(
    "Waiting for Sui Test Wallet approval..."
  );
  
  // Find the extension approval page.
  let approvalPage = null;
  
  for (let attempt = 0; attempt < 20; attempt++) {
    const openPages = context.pages();
  
    approvalPage = openPages.find(
      (p) =>
        p.url().includes(
          "popup.html?approval="
        )
    );
  
    if (approvalPage) {
      break;
    }
  
    await page.waitForTimeout(250);
  }
  
  if (!approvalPage) {
    throw new Error(
      "Sui Test Wallet approval page did not appear."
    );
  }
  
  console.log(
    "✓ PASS: Transaction approval opened"
  );
  
  console.log(
    "Approval URL:",
    approvalPage.url()
  );
  
  // Wait until popup UI is ready.
  await approvalPage.waitForLoadState(
    "domcontentloaded"
  );
  
  console.log();
  console.log(
    "Approval page:"
  );
  
  console.log(
    await approvalPage.locator("body").innerText()
  );
  
  // Find Approve button.
  const approveButton =
    approvalPage.getByRole(
      "button",
      {
        name: /approve/i,
      }
    );
  
  await expect(
    approveButton
  ).toBeVisible({
    timeout: 10_000,
  });
  
  await expect(
    approveButton
  ).toBeEnabled();
  
  console.log(
    "✓ PASS: Approve button found"
  );
  
  // The wallet popup closes itself immediately after approval.
// Use DOM click so Playwright does not wait for the popup
// to remain alive after the click.

await approveButton.dispatchEvent("click").catch(
    (error) => {
      if (
        !String(error).includes(
          "Target page, context or browser has been closed"
        )
      ) {
        throw error;
      }
    }
  );
  
  console.log(
    "✓ PASS: Transaction approval triggered"
  );
  
  console.log();
  console.log(
    "=== Extension workers ==="
  );
  
  for (const worker of context.serviceWorkers()) {
    console.log(
      "WORKER:",
      worker.url()
    );
  }
  
  // Keep browser open briefly so we can inspect
  // the transaction approval UI.
  await page.waitForTimeout(5000);
  
  // Wait for successful contract execution
  await expect(
    page.getByText(
      "Escrow Created",
      {
        exact: true,
      }
    )
  ).toBeVisible({
    timeout: 30_000,
  });
  
  console.log(
    "✓ PASS: Escrow transaction succeeded"
  );
  
  // ========================================================
  // 8. READ CREATED ESCROW ID + DIGEST
  // ========================================================
  
  const successBox = page
    .getByText(
      "Escrow Created",
      {
        exact: true,
      }
    )
    .locator("..");
  
  const resultCodes =
    successBox.locator("code");
  
  await expect(
    resultCodes
  ).toHaveCount(2);
  
  const escrowObjectId =
    (
      await resultCodes
        .nth(0)
        .textContent()
    )?.trim();
  
  const transactionDigest =
    (
      await resultCodes
        .nth(1)
        .textContent()
    )?.trim();
  
  expect(escrowObjectId).toBeTruthy();
  expect(transactionDigest).toBeTruthy();
  
  console.log(
    "Escrow Object ID:",
    escrowObjectId
  );
  
  console.log(
    "Transaction digest:",
    transactionDigest
  );
  
  console.log(
    "✓ PASS: Escrow ID and transaction digest returned"
  );

  // ========================================================
// PARTY A DEPOSIT
// ========================================================

console.log(
    "\n=== Party A Deposit ==="
  );
  
  // Make sure extension signer is Party A.
  const switchPartyAForDeposit =
    await sendAutomation(
      page,
      {
        type: "SUI_TEST_WALLET_AUTOMATION",
        action: "SET_ACTIVE_ACCOUNT",
        id: "party-a-before-deposit",
        address: E2E_ADDRESS,
      }
    );
  
  console.log(
    "Party A switch result:",
    switchPartyAForDeposit
  );
  
  if (switchPartyAForDeposit?.error) {
    throw new Error(
      `Failed to switch to Party A: ${switchPartyAForDeposit.error}`
    );
  }
  
  const stateBeforeDeposit =
    await sendAutomation(
      page,
      {
        type: "SUI_TEST_WALLET_AUTOMATION",
        action: "GET_STATE",
        id: "state-before-party-a-deposit",
      }
    );
  
  console.log(
    "Active account before deposit:",
    stateBeforeDeposit.active
  );
  
  if (
    stateBeforeDeposit.active !== E2E_ADDRESS
  ) {
    throw new Error(
      "Party A is not the active signing account"
    );
  }
  
  // Put newly-created escrow ID into Lookup Escrow.
  const lookupInput = page.getByPlaceholder(
    "Escrow Object ID"
  );
  
  await lookupInput.fill(escrowObjectId);
  
  await page
    .getByRole("button", {
      name: "Search",
    })
    .click();
  
  await expect(
    page.getByText("CREATED", {
      exact: true,
    })
  ).toBeVisible();
  
  console.log(
    "✓ PASS: Newly created escrow loaded"
  );
  
  // Verify initial deposit state.
  await expect(
    page.getByText("0 / 0.012 SUI", {
      exact: true,
    })
  ).toBeVisible();
  
  console.log(
    "✓ PASS: Party A deposit starts at 0 / 0.012 SUI"
  );
  
  const partyADepositButton =
    page.getByRole("button", {
      name: "Deposit 0.012 SUI as Party A",
    });
  
  await expect(
    partyADepositButton
  ).toBeVisible();
  
  console.log(
    "✓ PASS: Party A deposit button visible"
  );
  
  // Click the REAL frontend Deposit button.
  await partyADepositButton.click();
  
  console.log(
    "✓ PASS: Party A deposit clicked"
  );
  
  // ========================================================
  // APPROVE PARTY A DEPOSIT
  // ========================================================
  
  console.log(
    "Waiting for Party A deposit approval..."
  );
  
  const depositApprovalPage =
    await context.waitForEvent(
      "page",
      {
        timeout: 15_000,
      }
    );
  
  await depositApprovalPage.waitForLoadState(
    "domcontentloaded"
  );
  
  console.log(
    "✓ PASS: Party A deposit approval opened"
  );
  
  const depositApprovalText =
    await depositApprovalPage
      .locator("body")
      .innerText();
  
  console.log(
    "\nParty A deposit approval:\n" +
      depositApprovalText
  );
  
  const depositApproveButton =
  depositApprovalPage.locator(
    'button:has-text("APPROVE")'
  );

console.log(
  "Deposit approve buttons found:",
  await depositApproveButton.count()
);

await expect(
  depositApproveButton.first()
).toBeVisible();

console.log(
  "✓ PASS: Party A deposit approve button found"
);
  
  console.log(
    "✓ PASS: Party A deposit approve button found"
  );
  
  await depositApproveButton
  .first()
  .dispatchEvent("click")
    .catch((error) => {
      if (
        !String(error).includes(
          "Target page, context or browser has been closed"
        )
      ) {
        throw error;
      }
    });
  
  console.log(
    "✓ PASS: Party A deposit approval triggered"
  );
  
  // Wait for frontend transaction completion.
  await expect(
    page.getByText(
      "Deposit Successful",
      {
        exact: true,
      }
    )
  ).toBeVisible({
    timeout: 30_000,
  });
  
  console.log(
    "✓ PASS: Party A deposit transaction succeeded"
  );
  
  // LookupEscrow refreshes after success.
  // Contract should now report deposited_a = 0.012 SUI.
  await expect(
    page.getByText(
      "0.012 / 0.012 SUI",
      {
        exact: true,
      }
    )
  ).toBeVisible({
    timeout: 15_000,
  });
  
  console.log(
    "✓ PASS: Party A deposited 0.012 SUI"
  );

  // ========================================================
// SWITCH TO PARTY B
// ========================================================

console.log(
    "\n=== Switching to Party B ==="
  );
  
  const switchPartyB =
    await sendAutomation(
      page,
      {
        type: "SUI_TEST_WALLET_AUTOMATION",
        action: "SET_ACTIVE_ACCOUNT",
        id: "switch-to-party-b",
        address: E2E_PARTY_B_ADDRESS,
      }
    );
  
  console.log(
    "Party B switch result:",
    switchPartyB
  );
  
  const stateAfterPartyBSwitch =
    await sendAutomation(
      page,
      {
        type: "SUI_TEST_WALLET_AUTOMATION",
        action: "GET_STATE",
        id: "state-after-party-b-switch",
      }
    );
  
  console.log(
    "Extension state after Party B switch:",
    stateAfterPartyBSwitch
  );
  
  // Suiet 0.5.1 does not automatically change its
// selected account when Wallet Standard emits accountChange.
// Reconnect so connect() returns Party B as accounts[0].

console.log(
    "Reconnecting frontend wallet as Party B..."
  );
  
  const connectedWalletButton =
    page.getByText(
      /0x8e095.*341c/i
    ).first();
  
  await expect(
    connectedWalletButton
  ).toBeVisible();
  
  await connectedWalletButton.click();
  
  await page.waitForTimeout(500);
  
  const disconnectButton =
  page.getByRole(
    "button",
    { name: "Disconnect" }
  );

await expect(
  disconnectButton
).toBeVisible();

console.log(
  "✓ PASS: Disconnect button visible"
);

await disconnectButton.click();

console.log(
  "✓ PASS: Party A frontend wallet disconnected"
);

await page.waitForTimeout(500);

const reconnectButton =
  page.getByRole(
    "button",
    { name: "Connect Button" }
  );

await expect(
  reconnectButton
).toBeVisible();

console.log(
  "✓ PASS: Connect button visible after disconnect"
);

await reconnectButton.click();

console.log(
  "✓ PASS: Wallet selector reopened"
);

const suiTestWalletOption =
  page.getByText(
    "Sui Test Wallet",
    { exact: true }
  );

await expect(
  suiTestWalletOption
).toBeVisible();

await suiTestWalletOption.click();

console.log(
  "✓ PASS: Sui Test Wallet reselected"
);

await page.waitForTimeout(1000);

console.log(
  "\n=== UI after Party B reconnect ==="
);

console.log(
  await page.locator("body").innerText()
);

  

// ========================================================
// PARTY B DEPOSIT
// ========================================================

console.log(
    "\n=== Party B Deposit ==="
  );
  
  const partyBDepositButton =
    page.getByRole(
      "button",
      {
        name: /Join & Deposit 0\.002 SUI as Party B/i,
      }
    );
  
  await expect(
    partyBDepositButton
  ).toBeVisible();
  
  console.log(
    "✓ PASS: Party B join/deposit button visible"
  );
  
  const partyBApprovalPromise =
    context.waitForEvent("page");
  
  await partyBDepositButton.click();
  
  console.log(
    "✓ PASS: Party B deposit clicked"
  );
  
  const partyBApprovalPage =
    await partyBApprovalPromise;
  
  await partyBApprovalPage.waitForLoadState();
  
  console.log(
    "✓ PASS: Party B deposit approval opened"
  );
  
  const partyBApproveButton =
    partyBApprovalPage.locator(
      'button:has-text("APPROVE")'
    );
  
  await expect(
    partyBApproveButton.first()
  ).toBeVisible();
  
  console.log(
    "✓ PASS: Party B deposit approve button found"
  );
  
  await partyBApproveButton
    .first()
    .dispatchEvent("click")
    .catch((error) => {
      if (
        !String(error).includes(
          "Target page, context or browser has been closed"
        )
      ) {
        throw error;
      }
    });
  
  console.log(
    "✓ PASS: Party B deposit approval triggered"
  );
  
  // Wait for refreshed escrow state.
  await expect(
    page.getByText(
      "0.002 / 0.002 SUI",
      { exact: true }
    )
  ).toBeVisible({
    timeout: 15000,
  });
  
  console.log(
    "✓ PASS: Party B deposited 0.002 SUI"
  );

  // ========================================================
// VERIFY DEPOSITS COMPLETE
// ========================================================

console.log(
    "\n=== Verify Deposits Complete ==="
  );
  
  await expect(
    page.getByText(
      "DEPOSITS COMPLETE",
      { exact: true }
    )
  ).toBeVisible();
  
  console.log(
    "✓ PASS: Escrow status is DEPOSITS COMPLETE"
  );
  
  await expect(
    page.getByText(
      /0x32993bcb.*bdb9a15b/i
    )
  ).toBeVisible();
  
  console.log(
    "✓ PASS: Party B assigned correctly"
  );
  
  await expect(
    page.getByText(
      "0.012 / 0.012 SUI",
      { exact: true }
    )
  ).toBeVisible();
  
  await expect(
    page.getByText(
      "0.002 / 0.002 SUI",
      { exact: true }
    )
  ).toBeVisible();
  
  console.log(
    "✓ PASS: Both required deposits are complete"
  );

  // ========================================================
// SUGGEST FINALIZATION - PARTY B
// ========================================================

console.log(
    "\n=== Party B Suggest Finalization ==="
  );
  
  const suggestButton =
    page.getByRole(
      "button",
      { name: "Suggest Finalization" }
    );
  
  await expect(
    suggestButton
  ).toBeVisible();
  
  console.log(
    "✓ PASS: Suggest Finalization button visible"
  );
  
  const suggestApprovalPromise =
    context.waitForEvent("page");
  
  await suggestButton.click();
  
  console.log(
    "✓ PASS: Suggest Finalization clicked"
  );
  
  const suggestApprovalPage =
    await suggestApprovalPromise;
  
  await suggestApprovalPage.waitForLoadState();
  
  const suggestApproveButton =
    suggestApprovalPage.locator(
      'button:has-text("APPROVE")'
    );
  
  await expect(
    suggestApproveButton.first()
  ).toBeVisible();
  
  console.log(
    "✓ PASS: Finalization approval opened"
  );
  
  await suggestApproveButton
    .first()
    .dispatchEvent("click")
    .catch((error) => {
      if (
        !String(error).includes(
          "Target page, context or browser has been closed"
        )
      ) {
        throw error;
      }
    });
  
  console.log(
    "✓ PASS: Finalization approval triggered"
  );
  
  await expect(
    page.getByText(
      "FINALIZATION SUGGESTED",
      { exact: true }
    )
  ).toBeVisible({
    timeout: 15000,
  });
  
  console.log(
    "✓ PASS: Status is FINALIZATION SUGGESTED"
  );
  
  await page.waitForTimeout(500);
  
  console.log(
    "\n=== Finalization proposal UI ==="
  );
  
  console.log(
    await page.locator("body").innerText()
  );

    // ========================================================
  // SWITCH BACK TO PARTY A FOR REJECT
  // ========================================================

  console.log(
    "\n=== Switching to Party A for Reject ==="
  );

  const switchPartyAForReject =
    await sendAutomation(
      page,
      {
        type: "SUI_TEST_WALLET_AUTOMATION",
        action: "SET_ACTIVE_ACCOUNT",
        id: "switch-party-a-for-reject",
        address: E2E_ADDRESS,
      }
    );

  expect(
    switchPartyAForReject.success
  ).toBe(true);

  console.log(
    "✓ PASS: Extension switched to Party A"
  );

  // Suiet needs disconnect/reconnect to use
  // the newly active account.

  const partyBWalletButton =
    page.getByText(
      /0x32993.*a15b/i
    ).first();

  await expect(
    partyBWalletButton
  ).toBeVisible();

  await partyBWalletButton.click();

  const disconnectForReject =
    page.getByRole(
      "button",
      { name: "Disconnect" }
    );

  await expect(
    disconnectForReject
  ).toBeVisible();

  await disconnectForReject.click();

  console.log(
    "✓ PASS: Party B frontend wallet disconnected"
  );

  await page.waitForTimeout(500);

  const connectForReject =
    page.getByRole(
      "button",
      { name: "Connect Button" }
    );

  await expect(
    connectForReject
  ).toBeVisible();

  await connectForReject.click();

  const walletForReject =
    page.getByText(
      "Sui Test Wallet",
      { exact: true }
    );

  await expect(
    walletForReject
  ).toBeVisible();

  await walletForReject.click();

  await page.waitForTimeout(1000);

  console.log(
    "✓ PASS: Frontend reconnected as Party A"
  );

  // ========================================================
  // REJECT FINALIZATION - PARTY A
  // ========================================================

  console.log(
    "\n=== Party A Reject Finalization ==="
  );

  const rejectButton =
    page.getByRole(
      "button",
      {
        name: "Reject Finalization",
      }
    );

  await expect(
    rejectButton
  ).toBeVisible();

  console.log(
    "✓ PASS: Reject Finalization button visible"
  );

  const rejectApprovalPromise =
    context.waitForEvent("page");

  await rejectButton.click();

  console.log(
    "✓ PASS: Reject Finalization clicked"
  );

  const rejectApprovalPage =
    await rejectApprovalPromise;

  await rejectApprovalPage.waitForLoadState();

  console.log(
    "✓ PASS: Reject approval opened"
  );

  const rejectApproveButton =
    rejectApprovalPage.locator(
      'button:has-text("APPROVE")'
    );

  await expect(
    rejectApproveButton.first()
  ).toBeVisible();

  await rejectApproveButton
    .first()
    .dispatchEvent("click")
    .catch((error) => {
      if (
        !String(error).includes(
          "Target page, context or browser has been closed"
        )
      ) {
        throw error;
      }
    });

  console.log(
    "✓ PASS: Reject approval triggered"
  );

  // ========================================================
  // VERIFY REJECTED PROPOSAL
  // ========================================================

  await expect(
    page.getByText(
      "DEPOSITS COMPLETE",
      { exact: true }
    )
  ).toBeVisible({
    timeout: 15000,
  });

  console.log(
    "✓ PASS: Escrow returned to DEPOSITS COMPLETE"
  );

  await expect(
    page.getByText(
      "Finalization Proposal",
      { exact: true }
    )
  ).not.toBeVisible();

  console.log(
    "✓ PASS: Finalization proposal cleared"
  );

  await expect(
    page.getByRole(
      "button",
      {
        name: "Suggest Finalization",
      }
    )
  ).toBeVisible();

  console.log(
    "✓ PASS: Finalization can be proposed again"
  );

  console.log(
    "\n============================================================"
  );

  console.log(
    "REJECT FINALIZATION LIFECYCLE: PASS"
  );

  console.log(
    "Create → Deposit A → Deposit B → Suggest → Reject → Deposits Complete"
  );

  console.log(
    "============================================================"
  );

  console.log(
    "\n============================================================"
  );
  
  // ========================================================
  // 9. PRINT CONNECTED UI
  // ========================================================
  
  const bodyText =
    await page.locator("body").innerText();
  
  console.log();
  console.log("Connected page:");
  console.log(bodyText);

    // ========================================================
    // RESULT
    // ========================================================

    console.log();
    console.log("============================================================");
    console.log("Wallet Connection Test: PASS");
    console.log("============================================================");

    await page.waitForTimeout(3000);

  } finally {
    await context.close();
  }
});