import { act, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { AIConversation } from "../src/AIConversation.jsx";
import { AiuxSessionProvider } from "../src/session.jsx";
import type { AiuxSnapshot, SurfaceTree, Tool } from "../src/types.js";
import { stubSession } from "./helpers.jsx";

const SNAPSHOT: AiuxSnapshot = {
  protocolVersion: "0.1",
  sessionId: "s1",
  session: {
    id: "s1",
    title: "Fixture chat",
    createdAt: "2026-01-01T00:00:00Z",
    context: [
      { id: "c1", kind: "file", label: "README.md", uri: "aiux://files/README.md" },
    ],
  },
  messages: [
    {
      id: "m1",
      role: "user",
      parts: [{ id: "p1", type: "text", text: "Hi" }],
    },
    {
      id: "m2",
      role: "assistant",
      status: "complete",
      parts: [{ id: "p2", type: "markdown", markdown: "**Hey** there" }],
    },
  ],
  tools: [
    { id: "t9", name: "unreferenced_tool", status: "completed" } as Tool,
  ],
  approvals: [
    {
      id: "a9",
      prompt: "Loose approval?",
      action: { id: "x.y" },
      status: "requested",
    },
  ],
  artifacts: [],
  surfaces: [
    {
      id: "su1",
      revision: 1,
      root: { type: "text", text: "Loose surface" },
    } satisfies SurfaceTree,
  ],
  context: [],
  runs: [],
};

describe("AIConversation", () => {
  it("renders the snapshot: title, context chips, messages", () => {
    render(<AIConversation session={stubSession(SNAPSHOT)} />);
    expect(
      screen.getByRole("heading", { name: "Fixture chat" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("link", { name: /README\.md/ }),
    ).toBeInTheDocument();
    const feed = screen.getByRole("feed", { name: "Conversation" });
    expect(feed.querySelectorAll("article")).toHaveLength(2);
    expect(screen.getByText("Hey").tagName).toBe("STRONG");
  });

  it("renders unreferenced entities in the activity rail", () => {
    render(<AIConversation session={stubSession(SNAPSHOT)} />);
    const rail = screen.getByRole("region", { name: "Session activity" });
    expect(rail).toHaveTextContent("unreferenced_tool");
    expect(rail).toHaveTextContent("Loose approval?");
    expect(rail).toHaveTextContent("Loose surface");
  });

  it("scopes theme CSS custom properties to the component root", () => {
    const { container } = render(
      <AIConversation
        session={stubSession(SNAPSHOT)}
        theme={{ colorScheme: "dark", colors: { accent: "#ff0000" } }}
      />,
    );
    const root = container.querySelector(".aiux") as HTMLElement;
    expect(root.dataset.aiuxTheme).toBe("dark");
    expect(root.style.getPropertyValue("--aiux-color-accent")).toBe("#ff0000");
    expect(root.style.getPropertyValue("--aiux-color-background")).toBeTruthy();
  });

  it("supports embedded mode", () => {
    const { container } = render(
      <AIConversation session={stubSession(SNAPSHOT)} mode="embedded" />,
    );
    expect(container.querySelector(".aiux--embedded")).toBeInTheDocument();
  });

  it("rerenders on snapshot updates (subscription)", () => {
    const session = stubSession(SNAPSHOT);
    render(<AIConversation session={session} />);
    act(() =>
      session.emit({
        ...SNAPSHOT,
        messages: [
          ...SNAPSHOT.messages!,
          {
            id: "m3",
            role: "assistant",
            parts: [{ id: "p3", type: "text", text: "New!" }],
          },
        ],
      }),
    );
    expect(screen.getByText("New!")).toBeInTheDocument();
  });

  it("resolves a session by id from AiuxSessionProvider", () => {
    const session = stubSession(SNAPSHOT);
    render(
      <AiuxSessionProvider sessions={{ s1: session }}>
        <AIConversation sessionId="s1" />
      </AiuxSessionProvider>,
    );
    expect(screen.getByText("Hi")).toBeInTheDocument();
  });

  it("shows a status when the session is missing", () => {
    render(<AIConversation sessionId="ghost" />);
    expect(screen.getByRole("status")).toHaveTextContent("ghost");
  });

  it("gates the attach affordance on the files.upload capability", () => {
    render(
      <AIConversation
        session={stubSession(SNAPSHOT)}
        capabilities={[{ id: "files.upload", enabled: false }]}
      />,
    );
    expect(
      screen.queryByRole("button", { name: /attach/i }),
    ).not.toBeInTheDocument();
  });

  it("marks the feed busy while a run is active", () => {
    render(
      <AIConversation
        session={stubSession({ ...SNAPSHOT, activeRunId: "r1" })}
      />,
    );
    expect(screen.getByRole("feed")).toHaveAttribute("aria-busy", "true");
  });
});
