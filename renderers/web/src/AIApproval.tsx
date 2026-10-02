import { AiuxIcon } from "./icons.jsx";
import { useAiuxRenderContext } from "./context.js";
import { AIUX_ACTIONS, type Approval, type ApprovalStatus } from "./types.js";

/**
 * Approval card (plan §23): every lifecycle state is visually distinct and a
 * resolved approval can never re-execute — buttons exist only while the core
 * reports `requested`.
 */
const STATUS_META: Record<
  ApprovalStatus,
  { label: string; tone: string; icon: string }
> = {
  requested: { label: "Approval requested", tone: "warning", icon: "warning" },
  approved: { label: "Approved", tone: "success", icon: "check" },
  rejected: { label: "Rejected", tone: "destructive", icon: "x" },
  expired: { label: "Expired", tone: "muted", icon: "clock" },
  executed: { label: "Executed", tone: "accent", icon: "check" },
};

export function AIApproval({ approval }: { approval: Approval }) {
  const { onAction } = useAiuxRenderContext();
  const meta = STATUS_META[approval.status];
  const pending = approval.status === "requested";

  const resolve = (decision: "approved" | "rejected") =>
    onAction?.({
      id: AIUX_ACTIONS.approvalResolve,
      payload: { approvalId: approval.id, decision },
    });

  return (
    <section
      className={`aiux-approval aiux-tone-${meta.tone}`}
      aria-label={`Approval: ${approval.prompt}`}
      {...(pending ? { role: "alertdialog", "aria-modal": false } : {})}
    >
      <header className="aiux-approval__head">
        <AiuxIcon name={meta.icon} />
        <span className="aiux-approval__prompt">{approval.prompt}</span>
        <span className={`aiux-badge aiux-badge--${meta.tone}`}>
          {meta.label}
        </span>
      </header>
      {approval.description ? (
        <p className="aiux-approval__description">{approval.description}</p>
      ) : null}
      {approval.action ? (
        <p className="aiux-approval__action">
          Runs <code>{approval.action.id}</code> on approval
        </p>
      ) : null}
      {approval.expiresAt && pending ? (
        <p className="aiux-approval__expires">
          <AiuxIcon name="clock" size="sm" /> Expires{" "}
          <time dateTime={approval.expiresAt}>{approval.expiresAt}</time>
        </p>
      ) : null}
      {approval.resolution ? (
        <p className="aiux-approval__resolution">
          {approval.resolution.decision}
          {approval.resolution.resolvedBy
            ? ` by ${approval.resolution.resolvedBy}`
            : ""}
          {approval.resolution.note ? ` — ${approval.resolution.note}` : ""}
        </p>
      ) : null}
      {pending ? (
        <div className="aiux-approval__buttons" role="group" aria-label="Resolve approval">
          <button
            type="button"
            className="aiux-btn aiux-btn--primary"
            onClick={() => resolve("approved")}
            disabled={!onAction}
          >
            Approve
          </button>
          <button
            type="button"
            className="aiux-btn aiux-btn--secondary"
            onClick={() => resolve("rejected")}
            disabled={!onAction}
          >
            Reject
          </button>
        </div>
      ) : null}
    </section>
  );
}
