// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyondigital/aiux-protocol-types generate
/* eslint-disable */

/**
 * A source citation.
 */
export interface Citation {
  /**
   * Stable identifier.
   */
  id?: string | null;
  /**
   * Quoted snippet.
   */
  snippet?: string | null;
  /**
   * Origin identifier (index, tool, document store, ...).
   */
  source?: string | null;
  /**
   * Source title.
   */
  title?: string | null;
  /**
   * Source URI.
   */
  uri?: string | null;
  [k: string]: unknown | undefined;
}
