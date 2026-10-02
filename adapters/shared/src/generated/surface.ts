// GENERATED FILE — DO NOT EDIT.
// Source: protocol/schemas/v1 (+ protocol/versions/v1.json).
// Regenerate with: pnpm --filter @beyondigital/aiux-protocol-types generate
/* eslint-disable */

/**
 * AIUX Surface Schema v1 node. Serialized as `{"type": "<kind>", ...}`.
 *
 * The primitive set is closed: `surface`, `card`, `stack`, `row`, `grid`, `heading`, `text`, `markdown`, `code`, `icon`, `image`, `badge`, `divider`, `spacer`, `keyValue`, `list`, `table`, `button`, `menu`, `progress`, `status`, `input`, `textarea`, `select`, `checkbox`, `actions`.
 */
export type SurfaceNode =
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Child nodes.
       */
      children?: SurfaceNode[];
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      type: "surface";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Child nodes.
       */
      children?: SurfaceNode[];
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      /**
       * Optional card title.
       */
      title?: string | null;
      type: "card";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Child nodes.
       */
      children?: SurfaceNode[];
      /**
       * Stack direction (default vertical).
       */
      direction?: StackDirection | null;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      type: "stack";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Child nodes.
       */
      children?: SurfaceNode[];
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      type: "row";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Child nodes laid out into the grid.
       */
      children?: SurfaceNode[];
      /**
       * Column count (≥ 1).
       */
      columns: number;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      type: "grid";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Heading level 1–6 (default 1).
       */
      level?: number | null;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      /**
       * Heading text.
       */
      text: string;
      type: "heading";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      /**
       * Text content.
       */
      text: string;
      type: "text";
      /**
       * Semantic variant.
       */
      variant?: TextVariant | null;
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Markdown source.
       */
      markdown: string;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      type: "markdown";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Code source.
       */
      code: string;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Language hint for highlighting.
       */
      language?: string | null;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      type: "code";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Semantic icon name (renderer-resolved).
       */
      name: string;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      /**
       * Semantic size.
       */
      size?: IconSize | null;
      type: "icon";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Accessibility label.
       */
      alt?: string | null;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      /**
       * Image URI (host-mediated resolution).
       */
      src: string;
      type: "image";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      /**
       * Badge text.
       */
      text: string;
      /**
       * Semantic tone.
       */
      tone?: Tone | null;
      type: "badge";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      type: "divider";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      /**
       * Semantic size (default md).
       */
      size?: Gap | null;
      type: "spacer";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Rows.
       */
      items: KeyValueItem[];
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      type: "keyValue";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * List items.
       */
      children?: SurfaceNode[];
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Ordered (numbered) list when true.
       */
      ordered?: boolean;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      type: "list";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Optional caption.
       */
      caption?: string | null;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Column headers.
       */
      headers: string[];
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      /**
       * Rows; each row must match `headers` length.
       */
      rows: string[][];
      type: "table";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Action emitted on activation.
       */
      action: Action;
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Whether the button is disabled.
       */
      disabled?: boolean;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Button label.
       */
      label: string;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      type: "button";
      /**
       * Hierarchy variant.
       */
      variant?: ButtonVariant | null;
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Menu entries.
       */
      items: MenuItem[];
      /**
       * Menu trigger label.
       */
      label?: string | null;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      type: "menu";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Optional label.
       */
      label?: string | null;
      /**
       * Maximum value (default 1.0 semantics are renderer-defined).
       */
      max?: number | null;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      type: "progress";
      /**
       * Current value (omit for indeterminate).
       */
      value?: number | null;
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      /**
       * Status text.
       */
      text: string;
      /**
       * Semantic tone.
       */
      tone?: Tone | null;
      type: "status";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Whether input is disabled.
       */
      disabled?: boolean;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Semantic input type.
       */
      input_type?: InputType | null;
      /**
       * Field label.
       */
      label?: string | null;
      /**
       * Field name submitted in action payloads.
       */
      name: string;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Placeholder text.
       */
      placeholder?: string | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      /**
       * Whether input is required.
       */
      required?: boolean;
      type: "input";
      /**
       * Current value.
       */
      value?: string | null;
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Whether input is disabled.
       */
      disabled?: boolean;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Field label.
       */
      label?: string | null;
      /**
       * Field name submitted in action payloads.
       */
      name: string;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Placeholder text.
       */
      placeholder?: string | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      /**
       * Visible row hint.
       */
      rows?: number | null;
      type: "textarea";
      /**
       * Current value.
       */
      value?: string | null;
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Whether input is disabled.
       */
      disabled?: boolean;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Field label.
       */
      label?: string | null;
      /**
       * Field name submitted in action payloads.
       */
      name: string;
      /**
       * Options (must be non-empty).
       */
      options: SelectOption[];
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Placeholder when no value is selected.
       */
      placeholder?: string | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      type: "select";
      /**
       * Selected value.
       */
      value?: string | null;
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Checked state.
       */
      checked?: boolean;
      /**
       * Whether input is disabled.
       */
      disabled?: boolean;
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Checkbox label.
       */
      label: string;
      /**
       * Field name submitted in action payloads.
       */
      name: string;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      type: "checkbox";
      [k: string]: unknown | undefined;
    }
  | {
      /**
       * Cross-axis alignment.
       */
      alignment?: Alignment | null;
      /**
       * Child nodes.
       */
      children?: SurfaceNode[];
      /**
       * Main-axis distribution.
       */
      distribution?: Distribution | null;
      /**
       * Gap between children.
       */
      gap?: Gap | null;
      /**
       * Inner padding.
       */
      padding?: Padding | null;
      /**
       * Corner radius.
       */
      radius?: Radius | null;
      type: "actions";
      [k: string]: unknown | undefined;
    };
/**
 * Cross-axis alignment within a container.
 */
export type Alignment = "start" | "center" | "end" | "stretch";
/**
 * Main-axis distribution of children within a container.
 */
export type Distribution = "start" | "center" | "end" | "spaceBetween" | "spaceAround" | "spaceEvenly";
/**
 * Semantic gap between children (`xs|sm|md|lg|xl`).
 */
export type Gap = "xs" | "sm" | "md" | "lg" | "xl";
/**
 * Semantic padding (`none|xs|sm|md|lg`).
 */
export type Padding = "none" | "xs" | "sm" | "md" | "lg";
/**
 * Semantic corner radius (`sm|md|lg|full`).
 */
export type Radius = "sm" | "md" | "lg" | "full";
/**
 * Stack direction.
 */
export type StackDirection = "vertical" | "horizontal";
/**
 * Semantic text variant.
 */
export type TextVariant = "body" | "caption" | "label" | "emphasis" | "strong" | "muted";
/**
 * Icon size (semantic, resolved by renderer theme).
 */
export type IconSize = "sm" | "md" | "lg";
/**
 * Semantic tone for badges, statuses, and emphasis.
 */
export type Tone = "default" | "accent" | "muted" | "success" | "warning" | "destructive";
/**
 * Button hierarchy variant.
 */
export type ButtonVariant = "primary" | "secondary" | "ghost" | "destructive";
/**
 * Input field type (semantic; renderers map to platform keyboards).
 */
export type InputType = "text" | "email" | "number" | "password" | "url";

/**
 * A surface: a named, revisioned semantic node tree.
 */
export interface Surface {
  /**
   * Stable surface identifier.
   */
  id: string;
  /**
   * Optional human-facing name.
   */
  name?: string | null;
  /**
   * Monotonic revision; bumps on every `surface.updated`.
   */
  revision?: number;
  /**
   * Root node — must be a `surface` node.
   */
  root: SurfaceNode;
  [k: string]: unknown | undefined;
}
/**
 * A key/value row for `keyValue` nodes.
 */
export interface KeyValueItem {
  /**
   * Item label.
   */
  key: string;
  /**
   * Item value (rendered as text).
   */
  value: string;
  [k: string]: unknown | undefined;
}
/**
 * A semantic action emitted by interactive nodes (button, menu).
 *
 * Payloads are data only (§23); the host resolves `id` through its own policy before executing anything.
 */
export interface Action {
  /**
   * Semantic action identifier, e.g. `invoice.approve`.
   */
  id: string;
  /**
   * Arbitrary JSON payload carried to the host.
   */
  payload?: {
    [k: string]: unknown | undefined;
  };
  [k: string]: unknown | undefined;
}
/**
 * A `menu` entry.
 */
export interface MenuItem {
  /**
   * Action emitted when the item is chosen.
   */
  action: Action;
  /**
   * Whether the item is disabled.
   */
  disabled?: boolean;
  /**
   * Optional leading icon.
   */
  icon?: string | null;
  /**
   * Item label.
   */
  label: string;
  [k: string]: unknown | undefined;
}
/**
 * A selectable option for `select` nodes.
 */
export interface SelectOption {
  /**
   * Option display label.
   */
  label: string;
  /**
   * Option value submitted via action payloads.
   */
  value: string;
  [k: string]: unknown | undefined;
}
