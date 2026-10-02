import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { AIConversation } from "../src/AIConversation.jsx";
import type { AiuxSnapshot } from "../src/types.js";
import { stubSession } from "./helpers.jsx";

const SNAPSHOT: AiuxSnapshot = {
  protocolVersion: "0.1",
  sessionId: "s1",
  session: { id: "s1", title: "Keys", createdAt: "2026-01-01T00:00:00Z" },
  messages: [
    { id: "m1", role: "user", parts: [{ id: "p1", type: "text", text: "one" }] },
    { id: "m2", role: "assistant", parts: [{ id: "p2", type: "text", text: "two" }] },
    { id: "m3", role: "assistant", parts: [{ id: "p3", type: "text", text: "three" }] },
  ],
};

describe("feed keyboard navigation", () => {
  it("PageDown/PageUp steps between message articles", async () => {
    const user = userEvent.setup();
    render(<AIConversation session={stubSession(SNAPSHOT)} />);
    const feed = screen.getByRole("feed");
    const articles = feed.querySelectorAll("article");
    feed.focus();
    await user.keyboard("{PageDown}");
    expect(document.activeElement).toBe(articles[0]);
    await user.keyboard("{PageDown}");
    expect(document.activeElement).toBe(articles[1]);
    await user.keyboard("{PageUp}");
    expect(document.activeElement).toBe(articles[0]);
    await user.keyboard("{PageUp}"); // clamps at first
    expect(document.activeElement).toBe(articles[0]);
  });

  it("Home/End jump to first/last article", async () => {
    const user = userEvent.setup();
    render(<AIConversation session={stubSession(SNAPSHOT)} />);
    const feed = screen.getByRole("feed");
    const articles = feed.querySelectorAll("article");
    feed.focus();
    await user.keyboard("{End}");
    expect(document.activeElement).toBe(articles[2]);
    await user.keyboard("{Home}");
    expect(document.activeElement).toBe(articles[0]);
  });

  it("articles are focus targets but not in the Tab order", () => {
    render(<AIConversation session={stubSession(SNAPSHOT)} />);
    for (const a of screen.getByRole("feed").querySelectorAll("article")) {
      expect(a).toHaveAttribute("tabindex", "-1");
    }
  });
});

describe("composer keyboard behavior", () => {
  it("Enter submits aiux.composer.submit and clears the input", async () => {
    const onAction = vi.fn();
    const user = userEvent.setup();
    render(
      <AIConversation session={stubSession(SNAPSHOT)} onAction={onAction} />,
    );
    const input = screen.getByLabelText("Message");
    await user.type(input, "ship it{Enter}");
    expect(onAction).toHaveBeenCalledWith(
      expect.objectContaining({
        id: "aiux.composer.submit",
        payload: { text: "ship it" },
      }),
    );
    expect(input).toHaveValue("");
    expect(document.activeElement).toBe(input); // focus stays for follow-up
  });

  it("Shift+Enter inserts a newline instead of submitting", async () => {
    const onAction = vi.fn();
    const user = userEvent.setup();
    render(
      <AIConversation session={stubSession(SNAPSHOT)} onAction={onAction} />,
    );
    const input = screen.getByLabelText("Message");
    await user.type(input, "line1{Shift>}{Enter}{/Shift}line2");
    expect(onAction).not.toHaveBeenCalled();
    expect(input).toHaveValue("line1\nline2");
  });

  it("Escape clears the draft", async () => {
    const user = userEvent.setup();
    render(<AIConversation session={stubSession(SNAPSHOT)} />);
    const input = screen.getByLabelText("Message");
    await user.type(input, "draft");
    await user.keyboard("{Escape}");
    expect(input).toHaveValue("");
  });
});
