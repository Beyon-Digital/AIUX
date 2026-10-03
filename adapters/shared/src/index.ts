/**
 * AIUX Protocol v1 types — generated from `protocol/schemas/v1`.
 * Nothing here is hand-maintained except the tiny helpers below; regenerate
 * via `pnpm --filter @beyond-digital/aiux-protocol-types generate`.
 */
export * from "./generated";

import type { AiuxEvent } from "./generated";

/**
 * A canonical event envelope with a concretely typed payload —
 * `AiuxEventForAnyValue` (exported as `AiuxEvent`) carries
 * `payload: {[k:string]: unknown}` because the untyped schema is the
 * dispatch-time shape. Intersection (not `Omit`) so the generated index
 * signature stays intact.
 */
export type AiuxEventOf<P extends object = Record<string, unknown>> =
  AiuxEvent & { payload: P };
