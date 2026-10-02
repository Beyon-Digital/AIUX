import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { AIApproval } from "../src/AIApproval.jsx";
import { AIArtifactPreview } from "../src/AIArtifactPreview.jsx";
import { AiuxMarkdown } from "../src/markdown.jsx";
import { PartView } from "../src/parts.jsx";
import type {
  Approval,
  Artifact,
  Attachment,
  CodePart,
  ErrorPart,
  ImagePart,
  MarkdownPart,
  ProgressPart,
  StatusPart,
  TextPart,
  Tool,
  ToolPart,
} from "../src/types.js";
import { renderWithContext } from "./helpers.jsx";

const text: TextPart = { id: "p1", type: "text", text: "Hello world" };
const markdown: MarkdownPart = {
  id: "p2",
  type: "markdown",
  markdown: "**bold** [site](https://example.com)",
};
const code: CodePart = {
  id: "p3",
  type: "code",
  code: "const x = 1;",
  language: "ts",
};
const image: ImagePart = {
  id: "p4",
  type: "image",
  attachment: { name: "chart.png", uri: "https://img/chart.png" },
};
const attachment: Attachment = {
  name: "report.pdf",
  uri: "https://files/report.pdf",
  sizeBytes: 2048,
};
const progress: ProgressPart = {
  id: "p6",
  type: "progress",
  progress: { current: 3, total: 10, label: "Uploading" },
};
const errorPart: ErrorPart = {
  id: "p7",
  type: "error",
  error: {
    code: "rate_limited",
    message: "Too many requests",
    retryable: true,
  },
};

describe("part renderers", () => {
  it("renders a text part", () => {
    renderWithContext(<PartView part={text} messageId="m1" />);
    expect(screen.getByText("Hello world")).toBeInTheDocument();
  });

  it("renders markdown through the safe AST renderer", () => {
    renderWithContext(<PartView part={markdown} messageId="m1" />);
    const link = screen.getByRole("link", { name: "site" });
    expect(link).toHaveAttribute("href", "https://example.com");
    expect(link).toHaveAttribute("target", "_blank");
    expect(link).toHaveAttribute("rel", expect.stringContaining("noopener"));
    expect(screen.getByText("bold").tagName).toBe("STRONG");
  });

  it("never renders raw HTML from markdown (plan §23)", () => {
    renderWithContext(
      <AiuxMarkdown source={'hi <script>alert(1)</script> <img src="x" onerror="x()">'} />,
    );
    expect(screen.queryByText("alert(1)")).not.toBeInTheDocument();
    expect(document.querySelector("script")).toBeNull();
    expect(document.querySelector("img")).toBeNull();
  });

  it("neutralizes unsafe link schemes in markdown", () => {
    renderWithContext(
      <AiuxMarkdown source="[x](javascript:alert(1)) [y](data:text/html,<b>z</b>)" />,
    );
    expect(screen.queryByRole("link")).not.toBeInTheDocument();
  });

  it("renders code with a copy affordance", async () => {
    const user = userEvent.setup();
    renderWithContext(<PartView part={code} messageId="m1" />);
    const copy = screen.getByRole("button", { name: /copy/i });
    expect(copy).toBeInTheDocument();
    await user.click(copy);
    // clipboard absent in jsdom → execCommand fallback keeps the button alive
  });

  it("renders an image with alt text and caption", () => {
    renderWithContext(<PartView part={image} messageId="m1" />);
    expect(screen.getByAltText("chart.png")).toBeInTheDocument();
  });

  it("renders an attachment as a real link", () => {
    renderWithContext(
      <PartView
        part={{ id: "p5", type: "attachment", attachment }}
        messageId="m1"
      />,
    );
    const link = screen.getByRole("link", { name: /report\.pdf/i });
    expect(link).toHaveAttribute("href", "https://files/report.pdf");
    expect(screen.getByText(/2\.0 ?KB/)).toBeInTheDocument();
  });

  it("renders a status part with matching ARIA semantics", () => {
    const info: StatusPart = {
      id: "p8",
      type: "status",
      text: "Indexing…",
      level: "info",
    };
    renderWithContext(<PartView part={info} messageId="m1" />);
    expect(screen.getByRole("status")).toHaveTextContent("Indexing…");
    const errorStatus: StatusPart = {
      id: "p9",
      type: "status",
      text: "Boom",
      level: "error",
    };
    renderWithContext(<PartView part={errorStatus} messageId="m1" />);
    expect(screen.getByRole("alert")).toHaveTextContent("Boom");
  });

  it("normalizes progress to 0–1", () => {
    renderWithContext(<PartView part={progress} messageId="m1" />);
    const bar = screen.getByRole("progressbar");
    expect(bar).toHaveAttribute("value", "0.3");
    expect(bar).toHaveAttribute("max", "1");
    expect(screen.getByText("Uploading")).toBeInTheDocument();
  });

  it("renders error part with retry that emits aiux.error.retry", async () => {
    const onAction = vi.fn();
    const user = userEvent.setup();
    renderWithContext(<PartView part={errorPart} messageId="m9" />, {
      onAction,
    });
    expect(screen.getByRole("alert")).toHaveTextContent("Too many requests");
    await user.click(screen.getByRole("button", { name: /retry/i }));
    expect(onAction).toHaveBeenCalledWith(
      expect.objectContaining({
        id: "aiux.error.retry",
        payload: expect.objectContaining({ messageId: "m9", partId: "p7" }),
      }),
    );
  });

  it("renders a tool part via the entity index", () => {
    const tool: Tool = {
      id: "t1",
      name: "search",
      status: "running",
    };
    const toolPart: ToolPart = { id: "pt", type: "tool", toolId: "t1" };
    renderWithContext(<PartView part={toolPart} messageId="m1" />, {
      entities: {
        tools: new Map([["t1", tool]]),
        approvals: new Map(),
        artifacts: new Map(),
        surfaces: new Map(),
      },
    });
    const card = screen.getByRole("region", { name: /tool search/i });
    expect(card).toHaveAttribute("aria-busy", "true");
    expect(screen.getByText("search")).toBeInTheDocument();
  });

  it("renders a missing-reference chip for unknown tool ids", () => {
    const toolPart: ToolPart = { id: "pt", type: "tool", toolId: "nope" };
    renderWithContext(<PartView part={toolPart} messageId="m1" />);
    expect(screen.getByRole("note")).toHaveTextContent(/missing tool.*nope/i);
  });

  it("renders an approval as alertdialog with action buttons", async () => {
    const approval: Approval = {
      id: "a1",
      prompt: "Deploy to production?",
      action: { id: "deploy.push" },
      status: "requested",
    };
    const onAction = vi.fn();
    const user = userEvent.setup();
    renderWithContext(<AIApproval approval={approval} />, { onAction });
    expect(screen.getByRole("alertdialog")).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: /approve/i }));
    expect(onAction).toHaveBeenCalledWith(
      expect.objectContaining({
        id: "aiux.approval.resolve",
        payload: { approvalId: "a1", decision: "approved" },
      }),
    );
  });

  it("renders a resolved approval without buttons", () => {
    const approval: Approval = {
      id: "a1",
      prompt: "Deploy?",
      action: { id: "deploy.push" },
      status: "approved",
      resolution: { decision: "approved", resolvedBy: "user" },
    };
    renderWithContext(<AIApproval approval={approval} />);
    expect(screen.queryByRole("button")).not.toBeInTheDocument();
    expect(screen.getByText("Approved")).toBeInTheDocument();
    expect(screen.getByText(/by user/)).toBeInTheDocument();
  });

  it("renders an artifact preview and emits aiux.artifact.open", async () => {
    const artifact: Artifact = {
      id: "ar1",
      kind: "code",
      title: "Plan",
      revision: 2,
      content: "step 1\nstep 2\nstep 3\nstep 4\nstep 5\nstep 6\nstep 7",
      uri: "aiux://artifact/ar1",
    };
    const onAction = vi.fn();
    const user = userEvent.setup();
    renderWithContext(<AIArtifactPreview artifact={artifact} />, { onAction });
    expect(screen.getByText("Plan")).toBeInTheDocument();
    const preview = document.querySelector(".aiux-artifact__preview")!;
    expect(preview.textContent).toContain("step 6");
    expect(preview.textContent).not.toContain("step 7");
    expect(preview.textContent).toMatch(/…$/);
    await user.click(screen.getByRole("button", { name: /open artifact/i }));
    expect(onAction).toHaveBeenCalledWith(
      expect.objectContaining({
        id: "aiux.artifact.open",
        payload: { artifactId: "ar1" },
      }),
    );
  });
});
