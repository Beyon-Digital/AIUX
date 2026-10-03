// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyond-digital/aiux-protocol-types generate
/* eslint-disable */

/**
 * Recoverable, explicitly-typed failures crossing the session boundary.
 *
 * Out-of-order and unknown-required-semantics cases map to these variants; nothing may silently corrupt state (ADR 0001, plan §4/§21).
 */
export type ProtocolError =
  | {
      detail: string;
      kind: "invalidEvent";
      [k: string]: unknown | undefined;
    }
  | {
      expected: number;
      kind: "sequenceGap";
      received: number;
      [k: string]: unknown | undefined;
    }
  | {
      detail: string;
      kind: "unsupported";
      [k: string]: unknown | undefined;
    }
  | {
      detail: string;
      kind: "corruptState";
      [k: string]: unknown | undefined;
    };
