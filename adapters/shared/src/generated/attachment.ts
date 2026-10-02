// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyondigital/aiux-protocol-types generate
/* eslint-disable */

/**
 * A file/media reference carried by parts or messages.
 */
export interface Attachment {
  /**
   * Stable identifier.
   */
  id?: string | null;
  /**
   * MIME type.
   */
  mimeType?: string | null;
  /**
   * File name.
   */
  name?: string | null;
  /**
   * Size in bytes.
   */
  sizeBytes?: number | null;
  /**
   * Resource URI (host-mediated).
   */
  uri?: string | null;
  [k: string]: unknown | undefined;
}
