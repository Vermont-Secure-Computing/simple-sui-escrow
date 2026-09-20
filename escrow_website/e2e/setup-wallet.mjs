import { chromium } from "@playwright/test";
import path from "node:path";

const userDataDir = path.resolve(
  "./e2e/wallet-profile"
);

console.log("Starting Playwright wallet browser...");
console.log("Profile:", userDataDir);
console.log();
console.log("Install/setup Suiet in this browser.");
console.log("When finished, close the browser.");

const context = await chromium.launchPersistentContext(
  userDataDir,
  {
    headless: false,
    channel: "chromium",

    viewport: {
      width: 1400,
      height: 900,
    },
  }
);

const pages = context.pages();

const page =
  pages.length > 0
    ? pages[0]
    : await context.newPage();

await page.goto("https://suiet.app/");

console.log();
console.log("Browser ready.");
console.log("Set up Suiet, then close the browser manually.");

// Keep script alive until browser is closed.
await new Promise((resolve) => {
  context.on("close", resolve);
});