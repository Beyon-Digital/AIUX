import { expect, test } from "@playwright/test";

test.describe("examples/web smoke", () => {
  test("fixture replays through real wasm and passes conformance", async ({
    page,
  }) => {
    await page.goto("/");
    // Fixture replayed + serialized byte-identically to expected/*.json.
    await expect(
      page.getByText("conformance: PASS", { exact: false }),
    ).toBeVisible({ timeout: 30_000 });
    await expect(page.getByRole("feed", { name: "Conversation" })).toBeVisible();
    // Boot fixture (approval-accepted) renders its approval in the activity rail.
    await expect(
      page.getByRole("region", { name: "Session activity" }),
    ).toBeVisible();
  });

  test("composer submits through the host → live assistant stream", async ({
    page,
  }) => {
    await page.goto("/");
    const input = page.getByRole("textbox", { name: "Message" });
    await input.fill("hello aiux");
    await input.press("Enter");
    // User message + scripted streaming reply both land via protocol events.
    await expect(page.getByText("hello aiux", { exact: true })).toBeVisible();
    await expect(
      page.getByText(/scripted streaming reply/, { exact: false }).first(),
    ).toBeVisible({ timeout: 20_000 });
    // Host logged the semantic action it received.
    await expect(page.getByText(/aiux\.composer\.submit/).first()).toBeVisible();
  });

  test("fixture switch + embedded mode render", async ({ page }) => {
    await page.goto("/");
    await page
      .getByRole("combobox", { name: "Fixture" })
      .selectOption("approval-requested");
    await expect(page.getByRole("alertdialog").first()).toBeVisible({
      timeout: 30_000,
    });
    await page
      .getByRole("combobox", { name: "Mode" })
      .selectOption("embedded");
    await expect(page.locator(".aiux--embedded")).toBeVisible();
  });
});
