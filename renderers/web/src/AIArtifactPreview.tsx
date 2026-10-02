import { AiuxIcon } from "./icons.jsx";
import { AISurface } from "./AISurface.jsx";
import { useAiuxRenderContext } from "./context.js";
import { AIUX_ACTIONS, type Artifact } from "./types.js";

const PREVIEW_LINES = 6;

const WORKSPACE_LABEL: Record<string, string> = {
  fullscreen: "Opens fullscreen",
  detail: "Opens in detail pane",
  sheet: "Opens as sheet",
};

/** Artifact card — kind icon, title, revision badge, lazy content preview.
 * `artifact.preview` supplies a semantic summary / inline surface descriptor
 * and `artifact.workspace` declares how the artifact opens (ADR 0007). */
export function AIArtifactPreview({ artifact }: { artifact: Artifact }) {
  const { onAction } = useAiuxRenderContext();
  const title = artifact.title ?? artifact.id;
  const preview =
    artifact.content !== undefined
      ? artifact.content.split("\n").slice(0, PREVIEW_LINES).join("\n")
      : undefined;
  const truncated =
    artifact.content !== undefined &&
    artifact.content.split("\n").length > PREVIEW_LINES;
  const workspaceMode = artifact.workspace?.mode ?? "fullscreen";

  return (
    <section className="aiux-artifact" aria-label={`Artifact: ${title}`}>
      <header className="aiux-artifact__head">
        <AiuxIcon name="artifact" />
        <span className="aiux-artifact__title">{title}</span>
        <span className="aiux-badge aiux-badge--muted">{artifact.kind}</span>
        {artifact.revision !== undefined ? (
          <span className="aiux-badge aiux-badge--muted">
            rev {artifact.revision}
          </span>
        ) : null}
      </header>
      {artifact.preview?.summary ? (
        <p className="aiux-artifact__summary">{artifact.preview.summary}</p>
      ) : null}
      {artifact.preview?.surface ? (
        <div className="aiux-artifact__surface">
          <AISurface surface={artifact.preview.surface} />
        </div>
      ) : null}
      {preview !== undefined ? (
        <pre className="aiux-artifact__preview" tabIndex={0}>
          {preview}
          {truncated ? "\n…" : ""}
        </pre>
      ) : null}
      {artifact.workspace ? (
        <span className="aiux-badge aiux-badge--muted">
          {WORKSPACE_LABEL[workspaceMode] ?? "Opens fullscreen"}
        </span>
      ) : null}
      <div className="aiux-artifact__foot">
        {artifact.uri ? (
          <a
            className="aiux-btn aiux-btn--secondary"
            href={artifact.uri}
            target="_blank"
            rel="noopener noreferrer"
          >
            Open source
          </a>
        ) : null}
        {onAction ? (
          <button
            type="button"
            className="aiux-btn aiux-btn--secondary"
            onClick={() =>
              onAction({
                id: AIUX_ACTIONS.artifactOpen,
                payload: {
                  artifactId: artifact.id,
                  ...(artifact.workspace
                    ? { mode: workspaceMode }
                    : {}),
                },
              })
            }
          >
            Open artifact
          </button>
        ) : null}
      </div>
    </section>
  );
}
