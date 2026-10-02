import { AiuxIcon } from "./icons.jsx";
import { ProgressPartView } from "./parts.jsx";
import type { Tool } from "./types.js";

const STATUS_LABEL: Record<Tool["status"], string> = {
  running: "Running",
  completed: "Completed",
  failed: "Failed",
};

const STATUS_TONE: Record<Tool["status"], string> = {
  running: "accent",
  completed: "success",
  failed: "destructive",
};

function JsonBlock({ label, value }: { label: string; value: unknown }) {
  return (
    <details className="aiux-tool__details">
      <summary>{label}</summary>
      <pre className="aiux-tool__json" tabIndex={0}>
        {JSON.stringify(value, null, 2)}
      </pre>
    </details>
  );
}

/** Tool invocation card — name, lifecycle status, progress, I/O on demand. */
export function AIToolStatus({ tool }: { tool: Tool }) {
  const tone = STATUS_TONE[tool.status];
  const running = tool.status === "running";
  return (
    <section
      className={`aiux-tool aiux-tone-${tone}`}
      aria-label={`Tool ${tool.name}: ${STATUS_LABEL[tool.status]}`}
      aria-busy={running || undefined}
    >
      <header className="aiux-tool__head">
        <AiuxIcon name={running ? "spinner" : "tool"} />
        <span className="aiux-tool__name">{tool.name}</span>
        <span className={`aiux-badge aiux-badge--${tone}`}>
          {STATUS_LABEL[tool.status]}
        </span>
      </header>
      {tool.progress ? <ProgressPartView progress={tool.progress} /> : null}
      {tool.error ? (
        <p className="aiux-tool__error" role="alert">
          {tool.error.message}
        </p>
      ) : null}
      {tool.input !== undefined ? (
        <JsonBlock label="Input" value={tool.input} />
      ) : null}
      {tool.result !== undefined ? (
        <JsonBlock label="Result" value={tool.result} />
      ) : null}
    </section>
  );
}
