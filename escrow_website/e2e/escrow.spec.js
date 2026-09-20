import { test, expect } from "@playwright/test";

test.describe("Sui Escrow Frontend", () => {
  test("buyer can fill create escrow form", async ({ page }) => {
    console.log("\n============================================================");
    console.log("Sui Escrow Frontend E2E");
    console.log("============================================================");

    // ========================================================
    // 1. OPEN APP
    // ========================================================

    await page.goto("/escrow");

    await expect(
      page.getByRole("heading", {
        name: /create escrow/i,
      })
    ).toBeVisible();

    console.log("✓ PASS: Create Escrow page opened");

    // ========================================================
    // 2. SELECT BUYER
    // ========================================================

    const buyingButton = page.getByRole("button", {
      name: /i.?m buying/i,
    });

    await expect(buyingButton).toBeVisible();
    await buyingButton.click();

    console.log("✓ PASS: I'm Buying selected");

    // ========================================================
    // 3. LOCATE FORM INPUTS
    // ========================================================

    const priceInput =
      page.getByPlaceholder("0.25");

    const yourDepositInput =
      page.getByPlaceholder("0.05").nth(0);

    const otherDepositInput =
      page.getByPlaceholder("0.05").nth(1);

    const noteInput =
      page.getByPlaceholder(
        "Example: Website design project escrow"
      );

    await expect(priceInput).toBeVisible();
    await expect(yourDepositInput).toBeVisible();
    await expect(otherDepositInput).toBeVisible();
    await expect(noteInput).toBeVisible();

    console.log("✓ PASS: Create form visible");

    // ========================================================
    // 4. FILL FORM
    // ========================================================

    await priceInput.fill("0.01");
    await yourDepositInput.fill("0.002");
    await otherDepositInput.fill("0.002");

    await noteInput.fill(
      "Playwright frontend E2E test"
    );

    console.log("✓ PASS: Form filled");

    // ========================================================
    // 5. VERIFY INPUT VALUES
    // ========================================================

    await expect(priceInput).toHaveValue("0.01");
    await expect(yourDepositInput).toHaveValue("0.002");
    await expect(otherDepositInput).toHaveValue("0.002");

    console.log("✓ PASS: Input values correct");

    // ========================================================
    // 6. VERIFY BUYER / PARTY A CALCULATION
    // ========================================================

    await expect(
      page.getByText("0.0120 SUI required", {
        exact: false,
      })
    ).toBeVisible();

    console.log(
      "✓ PASS: Party A required deposit = 0.0120 SUI"
    );

    // ========================================================
    // 7. VERIFY SELLER / PARTY B CALCULATION
    // ========================================================

    await expect(
      page.getByText("0.0020 SUI required", {
        exact: false,
      })
    ).toBeVisible();

    console.log(
      "✓ PASS: Party B required deposit = 0.0020 SUI"
    );

    // ========================================================
    // 8. VERIFY NOTE
    // ========================================================

    await expect(noteInput).toHaveValue(
      "Playwright frontend E2E test"
    );

    console.log("✓ PASS: Agreement note correct");

    // ========================================================
    // 9. CREATE BUTTON
    // ========================================================

    const createButton = page.getByRole("button", {
      name: /^create escrow$/i,
    });

    await expect(createButton).toBeVisible();

    console.log("✓ PASS: Create Escrow button visible");

    // No wallet connected yet.
    await expect(createButton).toBeDisabled();

    console.log(
      "✓ PASS: Create Escrow disabled without wallet"
    );

    // ========================================================
    // RESULT
    // ========================================================

    console.log();
    console.log("============================================================");
    console.log("Create Escrow UI Test: PASS");
    console.log("============================================================");
  });
});