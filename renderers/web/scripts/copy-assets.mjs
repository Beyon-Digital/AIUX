// Copy non-TS build assets (the stylesheet) into dist/.
import { copyFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const dist = join(here, "..", "dist");
mkdirSync(dist, { recursive: true });
copyFileSync(join(here, "..", "src", "styles.css"), join(dist, "styles.css"));
console.log("aiux-web: styles.css → dist/");
