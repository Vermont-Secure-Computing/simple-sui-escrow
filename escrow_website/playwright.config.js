import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",

  timeout: 60_000,

  expect: {
    timeout: 10_000,
  },

  use: {
    baseURL: "http://localhost:5173",
    headless: false,

    screenshot: "only-on-failure",
    trace: "retain-on-failure",
  },

  webServer: {
    command: "npm run dev",
    url: "http://localhost:5173",
    reuseExistingServer: true,
    timeout: 120_000,
  },
});