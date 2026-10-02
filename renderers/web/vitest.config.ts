import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

const coreSrc = fileURLToPath(
  new URL("../../bindings/wasm/js/src/index.ts", import.meta.url),
);

export default defineConfig({
  resolve: {
    alias: {
      // Resolve the workspace package to source so tests run without a prior
      // `aiux-core` dist build (mirrors tsconfig paths).
      "@beyondigital/aiux-core": coreSrc,
    },
  },
  test: {
    environment: "jsdom",
    include: ["test/**/*.test.{ts,tsx}"],
    setupFiles: ["test/setup.ts"],
  },
});
