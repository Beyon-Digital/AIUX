# Accessibility — per-renderer checklists & run-throughs

Phase 8 deliverable (§16/§18). Each renderer must pass its checklist before
v0.1 DoD sign-off. **Status** column: `CI` = verified in CI on every PR,
`manual` = human run-through required (recorded below each table).

## Web (React)

Semantics are already asserted in `test/keyboard.test.tsx` + the golden DOM
snapshots (`test/golden.test.tsx` records the rendered ARIA tree for all 27
fixtures — regressions in roles/labels are diffs).

| Check | Status |
|-------|--------|
| Feed is `role="feed"` with `aria-label="Conversation"`, `aria-busy` while streaming | CI (goldens) |
| Messages `role="article"`, labelled with role + completion state | CI (goldens) |
| Composer: labelled textarea, disabled send, attach button `aria-label` | CI (goldens) |
| Approvals `role="alertdialog"` with labelled action group; expiry `<time datetime>` | CI (goldens) |
| Focusable regions: feed `tabindex=0` + `aria-keyshortcuts` (PgUp/PgDn/Home/End) | CI (keyboard.test) |
| All keyboard ops: send (Enter), newline (Shift+Enter), scroll keys | CI |
| `prefers-reduced-motion` collapses streaming dots | CI (theme unit) |
| axe-core audit on all 27 fixture states | manual — add `@axe-core/playwright` later |
| Screen-reader pass (VoiceOver/Safari, NVDA/Chrome): streaming announced as polite updates | manual |
| 200% text zoom: no clipped composer/cards | manual |

## SwiftUI

| Check | Status |
|-------|--------|
| Every interactive element has an accessibility label (buttons, composer, approval actions) | manual — audit `renderers/swiftui` for `.accessibilityLabel` coverage |
| VoiceOver reads message stream in order; streaming updates announce | manual (device) |
| Dynamic Type: `body`→`xxxLarge` without truncation in cards/keyValue | manual (device) |
| Reduce Motion honored (match theme contract) | manual (device) |
| Approval dialog exposes alert semantics + distinct states | manual |

## Compose

| Check | Status |
|-------|--------|
| `contentDescription` on icon-only buttons/images | manual — audit `renderers/compose` |
| TalkBack traversal order = visual order | manual (emulator) |
| Font scale 2.0 layout pass | manual (emulator) |
| Semantics roles on approvals (alert) | manual |
| Compose UI test: semantics assertions on the fixture gallery | planned — `createComposeRule` + `assertHasClickAction`/labels |

## Flutter

| Check | Status |
|-------|--------|
| `Semantics` labels on all interactive widgets | manual — audit `renderers/flutter` |
| TalkBack/VoiceOver pass on example app | manual |
| `MediaQuery.textScaler` 2.0 pass | widget-testable — add `testWidgets` with `textScaler` |
| Reduced motion honored | manual |

## Expo bridge

Inherits the native renderer underneath — the SwiftUI/Compose checklists
apply. Extra: `accessibilityLabel`/`accessible` must tunnel through the
Expo view's own chrome (the JS-side wrapper adds no semantics).

## Golden / screenshot matrix (what's CI-verifiable vs manual)

| Renderer | Mechanism | CI-verifiable today |
|----------|-----------|---------------------|
| Web | Vitest DOM snapshots for all 27 fixtures (`test/golden.test.tsx` → `__snapshots__`) — full serialized HTML incl. ARIA | **Yes** — runs in `js` job |
| Flutter | `test/golden_test.dart` (env-gated `AIUX_GOLDENS=1`) → PNGs produced by `flutter-goldens` CI job, uploaded as artifacts for human review | **Artifact-review** — deterministic (Ahem font, fixed 800×1200 surface) but not gated |
| Compose | Paparazzi (JVM, no emulator) over `AISurface`/`AIConversation` fixture states — recommended wiring documented below | Planned — not wired; needs `app.cash.paparazzi` plugin |
| SwiftUI | `swift-snapshot-testing` pointfree package or Xcode `.xcresult` screenshots via example-app scheme | Manual — requires macOS asset review |
| Expo | Inherits native snapshots above; JS side has no visual surface of its own | n/a |

### Manual run-throughs performed

| Date | Renderer | Who | Result |
|------|----------|-----|--------|
| 2026-10-02 | web | Phase 8 (automated: jest-axe equivalent — golden ARIA + keyboard tests green; axe pass pending playwright wiring) | pass on covered items |
| — | swiftui | — | pending DoD run on device |
| — | compose | — | pending DoD run on emulator |
| — | flutter | — | pending DoD run |

> Sign-off rule: `manual` rows must be filled before the `v0.1` tag. The
> Phase 8 PR lands the *infrastructure* (CI-verifiable rows); the run-through
> cells are intentionally left open for the DoD pass.
