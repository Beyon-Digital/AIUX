import { screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { AISurface } from "../src/AISurface.jsx";
import type { SurfaceNode, SurfaceTree } from "../src/types.js";
import { renderWithContext } from "./helpers.jsx";

function tree(root: SurfaceNode, id = "s1"): SurfaceTree {
  return { id, root, revision: 1 };
}

function renderSurface(root: SurfaceNode, onAction = vi.fn()) {
  return {
    onAction,
    ...renderWithContext(<AISurface surface={tree(root)} />, { onAction }),
  };
}

describe("AISurface — semantic primitives → DOM/ARIA", () => {
  it("renders a card with title as a labelled section", () => {
    renderSurface({
      type: "card",
      title: "Order summary",
      children: [{ type: "text", text: "Body" }],
    });
    const card = screen.getByRole("region", { name: "Order summary" });
    expect(card).toHaveTextContent("Body");
  });

  it("clamps heading levels to h1–h6", () => {
    renderSurface({
      type: "stack",
      children: [
        { type: "heading", text: "Nine", level: 9 },
        { type: "heading", text: "Two", level: 2 },
      ],
    });
    expect(screen.getByRole("heading", { name: "Nine", level: 6 })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Two", level: 2 })).toBeInTheDocument();
  });

  it("renders text variants semantically (caption/label/strong/emphasis)", () => {
    renderSurface({
      type: "stack",
      children: [
        { type: "text", text: "cap", variant: "caption" },
        { type: "text", text: "bold", variant: "strong" },
        { type: "text", text: "it", variant: "emphasis" },
      ],
    });
    expect(screen.getByText("bold").tagName).toBe("STRONG");
    expect(screen.getByText("it").tagName).toBe("EM");
  });

  it("maps layout tokens to theme custom properties, not literals", () => {
    const { container } = renderSurface({
      type: "stack",
      gap: "md",
      padding: "lg",
      radius: "sm",
      children: [{ type: "text", text: "x" }],
    });
    const stack = container.firstElementChild!.querySelector(
      "[style]",
    ) as HTMLElement;
    expect(stack.style.gap).toContain("var(--aiux-space-md)");
    expect(stack.style.padding).toContain("var(--aiux-space-lg)");
    expect(stack.style.borderRadius).toContain("var(--aiux-radius-sm)");
  });

  it("renders keyValue as a description list", () => {
    renderSurface({
      type: "keyValue",
      items: [
        { key: "Status", value: "Live" },
        { key: "Region", value: "iad" },
      ],
    });
    const dl = document.querySelector("dl")!;
    expect(dl).toBeInTheDocument();
    expect(within(dl).getByText("Status")).toBeInTheDocument();
    expect(within(dl).getByText("Live")).toBeInTheDocument();
  });

  it("renders ordered and unordered lists", () => {
    renderSurface({
      type: "stack",
      children: [
        {
          type: "list",
          ordered: false,
          children: [{ type: "text", text: "a" }],
        },
        {
          type: "list",
          ordered: true,
          children: [{ type: "text", text: "b" }],
        },
      ],
    });
    expect(document.querySelector("ul")).toBeInTheDocument();
    expect(document.querySelector("ol")).toBeInTheDocument();
  });

  it("renders table headers with column scope", () => {
    renderSurface({
      type: "table",
      caption: "Runs",
      headers: ["Name", "Status"],
      rows: [
        ["r1", "ok"],
        ["r2", "fail"],
      ],
    });
    const table = screen.getByRole("table");
    expect(table).toBeInTheDocument();
    for (const th of table.querySelectorAll("th")) {
      expect(th).toHaveAttribute("scope", "col");
    }
    expect(within(table).getByText("fail")).toBeInTheDocument();
  });

  it("emits a button's action on click", async () => {
    const onAction = vi.fn();
    const user = userEvent.setup();
    renderSurface(
      {
        type: "button",
        label: "Deploy",
        variant: "primary",
        action: { id: "deploy.push", payload: { env: "prod" } },
      },
      onAction,
    );
    await user.click(screen.getByRole("button", { name: "Deploy" }));
    expect(onAction).toHaveBeenCalledWith({
      id: "deploy.push",
      payload: { env: "prod" },
    });
  });

  it("merges collected field values into the submit action payload", async () => {
    const onAction = vi.fn();
    const user = userEvent.setup();
    renderSurface(
      {
        type: "card",
        children: [
          { type: "input", name: "branch", label: "Branch", placeholder: "main" },
          {
            type: "button",
            label: "Create",
            action: { id: "git.branch", payload: { dryRun: true } },
          },
        ],
      },
      onAction,
    );
    await user.type(screen.getByLabelText("Branch"), "feat/web");
    await user.click(screen.getByRole("button", { name: "Create" }));
    expect(onAction).toHaveBeenCalledWith({
      id: "git.branch",
      payload: { dryRun: true, fields: { branch: "feat/web" } },
    });
  });

  it("renders a menu as disclosure with role=menu/menuitem", async () => {
    const onAction = vi.fn();
    const user = userEvent.setup();
    renderSurface(
      {
        type: "menu",
        label: "Options",
        items: [
          { label: "Rename", action: { id: "doc.rename" } },
          { label: "Delete", action: { id: "doc.delete" }, disabled: true },
        ],
      },
      onAction,
    );
    const summary = screen.getByText("Options");
    await user.click(summary);
    const menu = screen.getByRole("menu");
    const items = within(menu).getAllByRole("menuitem");
    expect(items).toHaveLength(2);
    await user.click(screen.getByRole("menuitem", { name: "Rename" }));
    expect(onAction).toHaveBeenCalledWith({ id: "doc.rename" });
    expect(screen.getByRole("menuitem", { name: "Delete" })).toBeDisabled();
  });

  it("renders input/select/checkbox fields with labels", async () => {
    const user = userEvent.setup();
    renderSurface({
      type: "stack",
      children: [
        { type: "input", name: "email", label: "Email", inputType: "email" },
        {
          type: "select",
          name: "tier",
          label: "Tier",
          options: [
            { value: "free", label: "Free" },
            { value: "pro", label: "Pro" },
          ],
        },
        { type: "checkbox", name: "agree", label: "I agree" },
      ],
    });
    const email = screen.getByLabelText("Email");
    expect(email).toHaveAttribute("type", "email");
    await user.selectOptions(screen.getByLabelText("Tier"), "pro");
    await user.click(screen.getByLabelText("I agree"));
    expect(screen.getByLabelText("I agree")).toBeChecked();
  });

  it("renders progress/status/divider/spacer/icon/image/badge", () => {
    renderSurface({
      type: "stack",
      children: [
        { type: "progress", value: 5, max: 10, label: "Half" },
        { type: "status", text: "All good", tone: "success" },
        { type: "divider" },
        { type: "spacer", size: "lg" },
        { type: "icon", name: "check", label: "done" },
        { type: "image", src: "https://img/x.png", alt: "pic" },
        { type: "badge", text: "new", tone: "accent" },
      ],
    });
    expect(screen.getByRole("progressbar")).toHaveAttribute("value", "0.5");
    expect(screen.getByRole("status")).toHaveTextContent("All good");
    expect(screen.getByRole("separator")).toBeInTheDocument();
    expect(screen.getByRole("img", { name: "done" })).toBeInTheDocument();
    expect(screen.getByAltText("pic")).toBeInTheDocument();
    expect(screen.getByText("new")).toBeInTheDocument();
  });

  it("renders markdown/code inside surfaces through safe renderers", () => {
    renderSurface({
      type: "stack",
      children: [
        { type: "markdown", markdown: "# Title\n<iframe src=x>" },
        { type: "code", code: "fn main()", language: "rust" },
      ],
    });
    expect(screen.getByRole("heading", { name: "Title" })).toBeInTheDocument();
    expect(document.querySelector("iframe")).toBeNull();
    expect(screen.getByText("fn main()")).toBeInTheDocument();
  });

  it("shows a note for unknown node types instead of crashing", () => {
    renderSurface({ type: "hologram" as never });
    expect(screen.getByText(/unsupported surface node/i)).toBeInTheDocument();
  });
});
