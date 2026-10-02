import { AiuxIcon } from "./icons.jsx";
import { AiuxMarkdown, safeUrl } from "./markdown.jsx";
import { useAiuxRenderContext } from "./context.js";
import { useCopyToClipboard } from "./hooks.js";
import { AIApproval } from "./AIApproval.jsx";
import { AIArtifactPreview } from "./AIArtifactPreview.jsx";
import { AISurface } from "./AISurface.jsx";
import { AIToolStatus } from "./AIToolStatus.jsx";
import {
  AIUX_ACTIONS,
  type AiuxPart,
  type Attachment,
  type StatusLevel,
} from "./types.js";

function formatBytes(bytes: number | undefined): string | undefined {
  if (bytes === undefined) return undefined;
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export function TextPartView({ text }: { text: string }) {
  return <p className="aiux-text">{text}</p>;
}

export function MarkdownPartView({ markdown }: { markdown: string }) {
  return (
    <div className="aiux-markdown">
      <AiuxMarkdown source={markdown} />
    </div>
  );
}

export function CodePartView({
  code,
  language,
}: {
  code: string;
  language?: string | undefined;
}) {
  const { copied, copy } = useCopyToClipboard();
  return (
    <figure className="aiux-code">
      <figcaption className="aiux-code__bar">
        <span className="aiux-code__lang">{language ?? "code"}</span>
        <button
          type="button"
          className="aiux-btn aiux-btn--ghost aiux-code__copy"
          onClick={() => copy(code)}
          aria-label={copied ? "Copied" : "Copy code"}
        >
          <AiuxIcon name={copied ? "check" : "copy"} size="sm" />
          {copied ? "Copied" : "Copy"}
        </button>
      </figcaption>
      <pre className="aiux-code__pre" tabIndex={0}>
        <code className={language ? `language-${language}` : undefined}>
          {code}
        </code>
      </pre>
    </figure>
  );
}

export function ImagePartView({ attachment }: { attachment: Attachment }) {
  const alt = attachment.name ?? "image attachment";
  const meta = [attachment.mimeType, formatBytes(attachment.sizeBytes)]
    .filter(Boolean)
    .join(" · ");
  return (
    <figure className="aiux-image">
      {attachment.uri ? (
        <img className="aiux-image__img" src={attachment.uri} alt={alt} />
      ) : (
        <div className="aiux-image__placeholder" role="img" aria-label={alt}>
          <AiuxIcon name="image" size="lg" />
        </div>
      )}
      {(attachment.name || meta) && (
        <figcaption className="aiux-image__caption">
          {attachment.name}
          {meta ? <span className="aiux-muted"> {meta}</span> : null}
        </figcaption>
      )}
    </figure>
  );
}

export function AttachmentPartView({ attachment }: { attachment: Attachment }) {
  const label = attachment.name ?? "Attachment";
  const meta = [attachment.mimeType, formatBytes(attachment.sizeBytes)]
    .filter(Boolean)
    .join(" · ");
  const body = (
    <>
      <AiuxIcon name="attachment" />
      <span className="aiux-attachment__name">{label}</span>
      {meta ? <span className="aiux-attachment__meta">{meta}</span> : null}
    </>
  );
  // URIs are host-mediated references (§23) — render a real link when
  // present and the scheme is web-safe; untrusted schemes stay inert text.
  const uri = attachment.uri ? safeUrl(attachment.uri) : "";
  return uri ? (
    <a className="aiux-attachment" href={uri}>
      {body}
    </a>
  ) : (
    <span className="aiux-attachment">{body}</span>
  );
}

export function CitationPartView({
  citation,
}: {
  citation: {
    title?: string;
    uri?: string;
    snippet?: string;
    source?: string;
  };
}) {
  const title = citation.title ?? citation.uri ?? "Source";
  const citationUri = citation.uri ? safeUrl(citation.uri) : "";
  return (
    <aside className="aiux-citation">
      <AiuxIcon name="citation" />
      <div className="aiux-citation__body">
        {citationUri ? (
          <a
            className="aiux-citation__title"
            href={citationUri}
            target="_blank"
            rel="noopener noreferrer"
          >
            {title}
          </a>
        ) : (
          <span className="aiux-citation__title">{title}</span>
        )}
        {citation.snippet ? (
          <blockquote className="aiux-citation__snippet">
            {citation.snippet}
          </blockquote>
        ) : null}
        {citation.source ? (
          <span className="aiux-citation__source">{citation.source}</span>
        ) : null}
      </div>
    </aside>
  );
}

const STATUS_ICON: Record<StatusLevel, string> = {
  info: "info",
  success: "success",
  warning: "warning",
  error: "error",
};

export function StatusPartView({
  text,
  level = "info",
}: {
  text: string;
  level?: StatusLevel | undefined;
}) {
  return (
    <div
      className={`aiux-status aiux-tone-${level}`}
      role={level === "error" ? "alert" : "status"}
    >
      <AiuxIcon name={STATUS_ICON[level] ?? "info"} />
      <span>{text}</span>
    </div>
  );
}

export function ProgressPartView({
  progress,
}: {
  progress: { current?: number; total?: number; label?: string };
}) {
  const { current, total, label } = progress;
  const determinate = current !== undefined && total !== undefined && total > 0;
  const value = determinate ? Math.min(Math.max(current / total, 0), 1) : undefined;
  return (
    <div className="aiux-progress">
      {label ? <span className="aiux-progress__label">{label}</span> : null}
      <progress
        className="aiux-progress__bar"
        value={value}
        max={1}
        aria-label={label ?? "Progress"}
      />
      {determinate ? (
        <span className="aiux-progress__value">
          {Math.round((value ?? 0) * 100)}%
        </span>
      ) : null}
    </div>
  );
}

export function ErrorPartView({
  error,
  messageId,
  partId,
}: {
  error: { code: string; message: string; retryable?: boolean };
  messageId: string;
  partId: string;
}) {
  const { onAction } = useAiuxRenderContext();
  return (
    <div className="aiux-error" role="alert">
      <AiuxIcon name="error" />
      <div className="aiux-error__body">
        <span className="aiux-error__code">{error.code}</span>
        <span className="aiux-error__message">{error.message}</span>
      </div>
      {error.retryable && onAction ? (
        <button
          type="button"
          className="aiux-btn aiux-btn--secondary"
          onClick={() =>
            onAction({
              id: AIUX_ACTIONS.errorRetry,
              payload: { messageId, partId, code: error.code },
            })
          }
        >
          Retry
        </button>
      ) : null}
    </div>
  );
}

export function ToolPartView({ toolId }: { toolId: string }) {
  const { entities } = useAiuxRenderContext();
  const tool = entities.tools.get(toolId);
  if (!tool) {
    return <MissingRef kind="tool" id={toolId} />;
  }
  return <AIToolStatus tool={tool} />;
}

export function ApprovalPartView({ approvalId }: { approvalId: string }) {
  const { entities } = useAiuxRenderContext();
  const approval = entities.approvals.get(approvalId);
  if (!approval) {
    return <MissingRef kind="approval" id={approvalId} />;
  }
  return <AIApproval approval={approval} />;
}

export function ArtifactPartView({ artifactId }: { artifactId: string }) {
  const { entities } = useAiuxRenderContext();
  const artifact = entities.artifacts.get(artifactId);
  if (!artifact) {
    return <MissingRef kind="artifact" id={artifactId} />;
  }
  return <AIArtifactPreview artifact={artifact} />;
}

export function SurfacePartView({ surfaceId }: { surfaceId: string }) {
  const { entities } = useAiuxRenderContext();
  const surface = entities.surfaces.get(surfaceId);
  if (!surface) {
    return <MissingRef kind="surface" id={surfaceId} />;
  }
  return <AISurface surface={surface} />;
}

function MissingRef({ kind, id }: { kind: string; id: string }) {
  return (
    <div className="aiux-missing" role="note">
      Missing {kind} <code>{id}</code>
    </div>
  );
}

/** Dispatch a protocol part to its renderer. Unknown kinds degrade visibly,
 * never silently (plan §21 forward compatibility). */
export function PartView({
  part,
  messageId,
}: {
  part: AiuxPart;
  messageId: string;
}) {
  switch (part.type) {
    case "text":
      return <TextPartView text={part.text} />;
    case "markdown":
      return <MarkdownPartView markdown={part.markdown} />;
    case "code":
      return <CodePartView code={part.code} language={part.language} />;
    case "image":
      return <ImagePartView attachment={part.attachment} />;
    case "attachment":
      return <AttachmentPartView attachment={part.attachment} />;
    case "citation":
      return <CitationPartView citation={part.citation} />;
    case "tool":
      return <ToolPartView toolId={part.toolId} />;
    case "approval":
      return <ApprovalPartView approvalId={part.approvalId} />;
    case "artifact":
      return <ArtifactPartView artifactId={part.artifactId} />;
    case "status":
      return <StatusPartView text={part.text} level={part.level} />;
    case "progress":
      return <ProgressPartView progress={part.progress} />;
    case "surface":
      return <SurfacePartView surfaceId={part.surfaceId} />;
    case "error":
      return (
        <ErrorPartView
          error={part.error}
          messageId={messageId}
          partId={part.id}
        />
      );
    default:
      return (
        <div className="aiux-missing" role="note">
          Unsupported part type{" "}
          <code>{String((part as { type?: string }).type)}</code>
        </div>
      );
  }
}
