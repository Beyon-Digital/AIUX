// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyond-digital/aiux-protocol-types generate
/* eslint-disable */

/**
 * A typed part within a message (all 13 protocol part kinds; plan §3). Serialized internally tagged: `{"type": "text", "text": "..."}`.
 */
export type Part =
  | {
      /**
       * Stable part identifier within its message.
       */
      id: string;
      /**
       * Text content; `text.delta` events append here.
       */
      text: string;
      type: "text";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Stable part identifier within its message.
       */
      id: string;
      /**
       * Markdown source; `text.delta` events append here.
       */
      markdown: string;
      type: "markdown";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Code source.
       */
      code: string;
      /**
       * Stable part identifier within its message.
       */
      id: string;
      /**
       * Language hint.
       */
      language?: string | null;
      type: "code";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Image attachment.
       */
      attachment: Attachment;
      /**
       * Stable part identifier within its message.
       */
      id: string;
      type: "image";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Attachment reference.
       */
      attachment: Attachment;
      /**
       * Stable part identifier within its message.
       */
      id: string;
      type: "attachment";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Citation.
       */
      citation: Citation;
      /**
       * Stable part identifier within its message.
       */
      id: string;
      type: "citation";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Stable part identifier within its message.
       */
      id: string;
      /**
       * Referenced tool id.
       */
      toolId: string;
      type: "tool";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Referenced approval id.
       */
      approvalId: string;
      /**
       * Stable part identifier within its message.
       */
      id: string;
      type: "approval";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Referenced artifact id.
       */
      artifactId: string;
      /**
       * Stable part identifier within its message.
       */
      id: string;
      type: "artifact";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Stable part identifier within its message.
       */
      id: string;
      /**
       * Severity level.
       */
      level?: StatusLevel | null;
      /**
       * Status text.
       */
      text: string;
      type: "status";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Stable part identifier within its message.
       */
      id: string;
      /**
       * Progress value.
       */
      progress: Progress;
      type: "progress";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Stable part identifier within its message.
       */
      id: string;
      /**
       * Referenced surface id.
       */
      surfaceId: string;
      type: "surface";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * The error.
       */
      error: AiuxError;
      /**
       * Stable part identifier within its message.
       */
      id: string;
      type: "error";
      [k: string]: unknown | undefined;
    };
/**
 * Severity for `status` parts.
 */
export type StatusLevel = "info" | "success" | "warning" | "error";

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
/**
 * Normalized progress value.
 */
export interface Progress {
  /**
   * Units complete.
   */
  current?: number | null;
  /**
   * Progress label.
   */
  label?: string | null;
  /**
   * Total units.
   */
  total?: number | null;
  [k: string]: unknown | undefined;
}
/**
 * Structured error payload (entity name `error` on the wire).
 */
export interface AiuxError {
  /**
   * Stable machine-readable code.
   */
  code: string;
  /**
   * Additional detail for debugging.
   */
  detail?: unknown;
  /**
   * Human-readable message.
   */
  message: string;
  /**
   * Whether the operation may be retried.
   */
  retryable?: boolean | null;
  [k: string]: unknown | undefined;
}
