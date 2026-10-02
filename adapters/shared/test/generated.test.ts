import { describe, expect, it } from "vitest";

import {
  ENTITIES,
  EVENT_TYPES,
  PROTOCOL_VERSION,
  type AiuxEvent,
} from "../src/index";
import {
  createEventValidator,
  loadFixture,
  loadVersionManifest,
} from "../src/testing";

describe("generated constants", () => {
  it("match protocol/versions/v1.json", () => {
    const manifest = loadVersionManifest();
    expect(PROTOCOL_VERSION).toBe(manifest.protocolVersion);
    expect([...EVENT_TYPES]).toEqual(manifest.eventTypes);
    expect([...ENTITIES]).toEqual(manifest.entities);
  });
});

describe("conformance fixtures", () => {
  const validator = createEventValidator();
  const fixture = loadFixture("streaming-response");

  it("every fixture event validates against its event schema", () => {
    for (const event of fixture.events) {
      validator.assertValid(event);
    }
  });

  it("rejects an envelope missing required fields", () => {
    const bad = { type: "text.delta", eventId: "x" } as unknown as AiuxEvent;
    expect(validator.validate(bad).ok).toBe(false);
  });
});
