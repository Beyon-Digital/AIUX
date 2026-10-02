import {
  createContext,
  useContext,
  useMemo,
  useState,
  type CSSProperties,
  type JSX,
} from "react";
import { AiuxIcon } from "./icons.jsx";
import { AiuxMarkdown } from "./markdown.jsx";
import { useAiuxRenderContext } from "./context.js";
import { CodePartView } from "./parts.jsx";
import {
  AIUX_ACTIONS,
  type AiuxAction,
  type KeyValueItem,
  type MenuItem,
  type SelectOption,
  type SurfaceNode,
  type SurfaceTree,
} from "./types.js";

/**
 * AIUX Surface Schema → DOM/ARIA mapping (plan §6, ADR 0006). The schema is
 * semantic, not stylistic: layout values are tokens resolved through theme
 * custom properties; interactive nodes emit `AiuxAction`s — payloads are
 * data, never code (§23).
 */

/* Per-surface form state: input/textarea/select/checkbox values keyed by
 * `name`, folded into action payloads as `fields` when a button fires. */
interface SurfaceFieldState {
  values: Record<string, string>;
  setValue(name: string, value: string): void;
}
const FieldContext = createContext<SurfaceFieldState | null>(null);

const GAP = (v?: string) => (v ? `var(--aiux-space-${v})` : undefined);
const PAD = (v?: string) =>
  v && v !== "none" ? `var(--aiux-space-${v})` : v === "none" ? 0 : undefined;

const ALIGN: Record<string, CSSProperties["alignItems"]> = {
  start: "flex-start",
  center: "center",
  end: "flex-end",
  stretch: "stretch",
};
const DISTRIBUTE: Record<string, CSSProperties["justifyContent"]> = {
  start: "flex-start",
  center: "center",
  end: "flex-end",
  spaceBetween: "space-between",
  spaceAround: "space-around",
  spaceEvenly: "space-evenly",
};

function layoutStyle(node: SurfaceNode): CSSProperties {
  return {
    gap: GAP(node.gap),
    padding: PAD(node.padding),
    borderRadius: node.radius ? `var(--aiux-radius-${node.radius})` : undefined,
    alignItems: node.alignment ? ALIGN[node.alignment] : undefined,
    justifyContent: node.distribution
      ? DISTRIBUTE[node.distribution]
      : undefined,
  };
}

function toneClass(prefix: string, tone?: string): string {
  return `${prefix} aiux-tone-${tone ?? "default"}`;
}

function SurfaceChildren({
  children,
}: {
  children?: SurfaceNode[] | undefined;
}) {
  return (
    <>
      {(children ?? []).map((child, i) => (
        <SurfaceNodeView key={i} node={child} />
      ))}
    </>
  );
}

function MenuNode({ node }: { node: SurfaceNode }) {
  const { onAction } = useAiuxRenderContext();
  const items = (node.items ?? []) as MenuItem[];
  return (
    <details className="aiux-menu" style={layoutStyle(node)}>
      <summary
        className="aiux-btn aiux-btn--secondary aiux-menu__trigger"
        aria-haspopup="menu"
      >
        {node.label ?? "Menu"}
      </summary>
      <div className="aiux-menu__list" role="menu">
        {items.map((item, i) => (
          <button
            key={i}
            type="button"
            role="menuitem"
            className="aiux-menu__item"
            disabled={item.disabled || !onAction}
            onClick={() => onAction?.(item.action)}
          >
            {item.icon ? <AiuxIcon name={item.icon} size="sm" /> : null}
            {item.label}
          </button>
        ))}
      </div>
    </details>
  );
}

/** Field wrappers register values into the enclosing surface's field state. */
function useField(name: string, initial: string): [string, (v: string) => void] {
  const fields = useContext(FieldContext);
  const [local, setLocal] = useState(initial);
  const value = fields ? (fields.values[name] ?? initial) : local;
  const setValue = (v: string) => {
    setLocal(v);
    fields?.setValue(name, v);
  };
  return [value, setValue];
}

function SurfaceNodeView({ node }: { node: SurfaceNode }): JSX.Element | null {
  const { onAction } = useAiuxRenderContext();
  const fields = useContext(FieldContext);
  const style = layoutStyle(node);

  switch (node.type) {
    case "surface":
      return (
        <div className="aiux-surface" role="region" style={style}>
          <SurfaceChildren children={node.children} />
        </div>
      );
    case "card":
      return (
        <section
          className="aiux-card"
          style={style}
          aria-label={node.title ?? undefined}
        >
          {node.title ? (
            <h3 className="aiux-card__title">{node.title}</h3>
          ) : null}
          <SurfaceChildren children={node.children} />
        </section>
      );
    case "stack":
      return (
        <div
          className={`aiux-stack aiux-stack--${node.direction ?? "vertical"}`}
          style={style}
        >
          <SurfaceChildren children={node.children} />
        </div>
      );
    case "row":
      return (
        <div className="aiux-stack aiux-stack--horizontal" style={style}>
          <SurfaceChildren children={node.children} />
        </div>
      );
    case "grid":
      return (
        <div
          className="aiux-grid"
          style={{
            ...style,
            gridTemplateColumns: `repeat(${Math.max(1, node.columns ?? 1)}, minmax(0, 1fr))`,
          }}
        >
          <SurfaceChildren children={node.children} />
        </div>
      );
    case "heading": {
      const level = Math.min(Math.max(node.level ?? 1, 1), 6);
      const Tag = `h${level}` as keyof JSX.IntrinsicElements;
      return (
        <Tag className="aiux-heading" style={style}>
          {node.text}
        </Tag>
      );
    }
    case "text": {
      const variant = node.variant ?? "body";
      if (variant === "strong")
        return (
          <strong className="aiux-surf-text" style={style}>
            {node.text}
          </strong>
        );
      if (variant === "emphasis")
        return (
          <em className="aiux-surf-text" style={style}>
            {node.text}
          </em>
        );
      return (
        <p className={`aiux-surf-text aiux-surf-text--${variant}`} style={style}>
          {node.text}
        </p>
      );
    }
    case "markdown":
      return (
        <div className="aiux-markdown" style={style}>
          <AiuxMarkdown source={node.markdown ?? ""} />
        </div>
      );
    case "code":
      return (
        <CodePartView code={node.code ?? ""} language={node.language} />
      );
    case "icon":
      return (
        <span style={style}>
          <AiuxIcon
            name={node.name ?? ""}
            size={node.size as "sm" | "md" | "lg" | undefined}
            label={node.label}
          />
        </span>
      );
    case "image":
      return (
        <img
          className="aiux-surf-image"
          style={style}
          src={node.src}
          alt={node.alt ?? ""}
        />
      );
    case "badge":
      return (
        <span
          className={toneClass("aiux-badge", node.tone)}
          style={style}
        >
          {node.text}
        </span>
      );
    case "divider":
      return <hr className="aiux-divider" style={style} />;
    case "spacer":
      return (
        <div
          className="aiux-spacer"
          style={{
            ...style,
            blockSize: GAP(node.size as string | undefined) ?? "var(--aiux-space-md)",
          }}
          aria-hidden
        />
      );
    case "keyValue": {
      const items = (node.items ?? []) as KeyValueItem[];
      return (
        <dl className="aiux-kv" style={style}>
          {items.map((item, i) => (
            <div className="aiux-kv__row" key={i}>
              <dt className="aiux-kv__key">{item.key}</dt>
              <dd className="aiux-kv__value">{item.value}</dd>
            </div>
          ))}
        </dl>
      );
    }
    case "list": {
      const ListTag = node.ordered ? "ol" : "ul";
      return (
        <ListTag className="aiux-list" style={style}>
          {(node.children ?? []).map((child, i) => (
            <li key={i} className="aiux-list__item">
              <SurfaceNodeView node={child} />
            </li>
          ))}
        </ListTag>
      );
    }
    case "table": {
      const headers = node.headers ?? [];
      const rows = (node.rows ?? []) as string[][];
      return (
        <table className="aiux-table" style={style}>
          {node.caption ? <caption>{node.caption}</caption> : null}
          <thead>
            <tr>
              {headers.map((h, i) => (
                <th key={i} scope="col">
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((row, i) => (
              <tr key={i}>
                {row.map((cell, j) => (
                  <td key={j}>{cell}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      );
    }
    case "button": {
      const action = node.action;
      return (
        <button
          type="button"
          className={`aiux-btn aiux-btn--${node.variant ?? "secondary"}`}
          style={style}
          disabled={node.disabled || !onAction}
          onClick={() => {
            if (!action || !onAction) return;
            const fieldValues = fields?.values ?? {};
            const payload =
              Object.keys(fieldValues).length > 0
                ? { ...action.payload, fields: fieldValues }
                : action.payload;
            onAction({ id: action.id, ...(payload ? { payload } : {}) });
          }}
        >
          {node.label}
        </button>
      );
    }
    case "menu":
      return <MenuNode node={node} />;
    case "progress": {
      const max = Number(node.max ?? 1);
      const value =
        node.value !== undefined && max > 0
          ? Math.min(Math.max(Number(node.value) / max, 0), 1)
          : undefined;
      return (
        <div className="aiux-progress" style={style}>
          {node.label ? (
            <span className="aiux-progress__label">{node.label}</span>
          ) : null}
          <progress
            className="aiux-progress__bar"
            value={value}
            max={1}
            aria-label={node.label ?? "Progress"}
          />
        </div>
      );
    }
    case "status":
      return (
        <div
          className={toneClass("aiux-status", node.tone)}
          style={style}
          role="status"
        >
          <AiuxIcon name={node.tone === "destructive" ? "error" : "info"} />
          <span>{node.text}</span>
        </div>
      );
    case "input":
      return <InputField node={node} style={style} />;
    case "textarea":
      return <TextareaField node={node} style={style} />;
    case "select":
      return <SelectField node={node} style={style} />;
    case "checkbox":
      return <CheckboxField node={node} style={style} />;
    case "actions":
      return (
        <div className="aiux-actions" role="group" style={style}>
          <SurfaceChildren children={node.children} />
        </div>
      );
    default:
      return (
        <div className="aiux-missing" role="note" style={style}>
          Unsupported surface node <code>{String(node.type)}</code>
        </div>
      );
  }
}

function FieldLabel({
  label,
  required,
  children,
}: {
  label?: string | undefined;
  required?: boolean | undefined;
  children: React.ReactNode;
}) {
  if (!label) return <>{children}</>;
  return (
    <label className="aiux-field">
      <span className="aiux-field__label">
        {label}
        {required ? <span aria-hidden> *</span> : null}
      </span>
      {children}
    </label>
  );
}

function InputField({
  node,
  style,
}: {
  node: SurfaceNode;
  style: CSSProperties;
}) {
  const [value, setValue] = useField(node.name ?? "", String(node.value ?? ""));
  return (
    <span style={style}>
      <FieldLabel label={node.label} required={node.required}>
        <input
          className="aiux-input"
          name={node.name}
          type={node.inputType ?? "text"}
          placeholder={node.placeholder}
          value={value}
          required={node.required}
          disabled={node.disabled}
          aria-label={node.label ?? node.name}
          onChange={(e) => setValue(e.target.value)}
        />
      </FieldLabel>
    </span>
  );
}

function TextareaField({
  node,
  style,
}: {
  node: SurfaceNode;
  style: CSSProperties;
}) {
  const [value, setValue] = useField(node.name ?? "", String(node.value ?? ""));
  return (
    <span style={style}>
      <FieldLabel label={node.label}>
        <textarea
          className="aiux-input"
          name={node.name}
          placeholder={node.placeholder}
          value={value}
          rows={typeof node.rows === "number" ? node.rows : 3}
          disabled={node.disabled}
          aria-label={node.label ?? node.name}
          onChange={(e) => setValue(e.target.value)}
        />
      </FieldLabel>
    </span>
  );
}

function SelectField({
  node,
  style,
}: {
  node: SurfaceNode;
  style: CSSProperties;
}) {
  const options = (node.options ?? (node.items as SelectOption[])) ?? [];
  const [value, setValue] = useField(node.name ?? "", String(node.value ?? ""));
  return (
    <span style={style}>
      <FieldLabel label={node.label}>
        <select
          className="aiux-input"
          name={node.name}
          value={value}
          disabled={node.disabled}
          aria-label={node.label ?? node.name}
          onChange={(e) => setValue(e.target.value)}
        >
          {node.placeholder ? (
            <option value="" disabled>
              {node.placeholder}
            </option>
          ) : null}
          {options.map((o) => (
            <option key={o.value} value={o.value}>
              {o.label}
            </option>
          ))}
        </select>
      </FieldLabel>
    </span>
  );
}

function CheckboxField({
  node,
  style,
}: {
  node: SurfaceNode;
  style: CSSProperties;
}) {
  const [value, setValue] = useField(
    node.name ?? "",
    node.checked ? "true" : "",
  );
  return (
    <label className="aiux-checkbox" style={style}>
      <input
        type="checkbox"
        name={node.name}
        checked={value === "true"}
        disabled={node.disabled}
        onChange={(e) => setValue(e.target.checked ? "true" : "")}
      />
      <span>{node.label}</span>
    </label>
  );
}

/** Render a session-level `Surface` (a revisioned semantic node tree). */
export function AISurface({ surface }: { surface: SurfaceTree }) {
  const [values, setValues] = useState<Record<string, string>>({});
  const fieldState = useMemo<SurfaceFieldState>(
    () => ({
      values,
      setValue: (name, value) =>
        setValues((prev) => ({ ...prev, [name]: value })),
    }),
    [values],
  );
  return (
    <FieldContext.Provider value={fieldState}>
      <div
        className="aiux-surface-root"
        data-aiux-surface={surface.id}
        data-aiux-revision={surface.revision}
        aria-label={surface.name ?? `Surface ${surface.id}`}
      >
        <SurfaceNodeView node={surface.root} />
      </div>
    </FieldContext.Provider>
  );
}
