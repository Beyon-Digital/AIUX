import { fileURLToPath } from "node:url";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

const coreSrc = fileURLToPath(
  new URL("../../bindings/wasm/js/src/index.ts", import.meta.url),
);
const webSrc = fileURLToPath(
  new URL("../../renderers/web/src/index.ts", import.meta.url),
);
const webStyles = fileURLToPath(
  new URL("../../renderers/web/src/styles.css", import.meta.url),
);

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: [
      // Anchored exact matches — string finds prefix-match, which would
      // rewrite `@beyondigital/aiux-core/wasm` subpath imports as well.
      // styles.css is aliased to src/ because the package export points at
      // dist/, which may not be built in dev.
      { find: "@beyondigital/aiux-web/styles.css", replacement: webStyles },
      { find: /^@beyondigital\/aiux-web$/, replacement: webSrc },
      { find: /^@beyondigital\/aiux-core$/, replacement: coreSrc },
    ],
  },
  optimizeDeps: {
    // The wasm-bindgen glue and fixture JSON are imported dynamically/excluded
    // from prebundling so dev always sees the freshest pkg/ artifacts.
    exclude: ["@beyondigital/aiux-core"],
  },
});
