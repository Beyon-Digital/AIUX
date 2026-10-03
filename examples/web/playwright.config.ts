import { defineConfig } from "@playwright/test";

/**
 * Smoke config — builds the example (which first produces bindings/wasm/pkg
 * via aiux-core build:wasm), serves `vite preview`, and drives real Chromium
 * end to end. Run: `pnpm --filter @beyond-digital/aiux-example-web test:e2e`
 * (requires `pnpm dlx playwright install chromium` — not in default test runs).
 */
export default defineConfig({
  testDir: "e2e",
  timeout: 60_000,
  retries: 0,
  use: {
    baseURL: "http://localhost:4173",
    trace: "retain-on-failure",
  },
  webServer: {
    command:
      "pnpm run build && pnpm exec vite preview --port 4173 --strictPort",
    url: "http://localhost:4173",
    timeout: 180_000,
    reuseExistingServer: false,
  },
});
