// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyond-digital/aiux-protocol-types generate
/* eslint-disable */

/** Protocol version carried by envelopes and payloads (protocol/versions/v1.json). */
export const PROTOCOL_VERSION = "0.1" as const;

/** The 20 lifecycle event type names of Protocol v1 (plan §3). */
export const EVENT_TYPES = [
  "session.created",
  "run.started",
  "run.cancelled",
  "run.completed",
  "run.failed",
  "message.created",
  "message.updated",
  "part.added",
  "part.updated",
  "text.delta",
  "tool.started",
  "tool.progress",
  "tool.completed",
  "tool.failed",
  "approval.requested",
  "approval.resolved",
  "artifact.created",
  "artifact.updated",
  "surface.created",
  "surface.updated"
] as const;

/** Union of the 20 wire event type names. */
export type EventTypeName = (typeof EVENT_TYPES)[number];

/** Top-level entity schema names of Protocol v1. */
export const ENTITIES = [
  "session",
  "message",
  "part",
  "attachment",
  "citation",
  "contextEntity",
  "capability",
  "tool",
  "approval",
  "artifact",
  "surface",
  "action",
  "error",
  "event",
  "fixture",
  "dispatchReport",
  "protocolError"
] as const;
