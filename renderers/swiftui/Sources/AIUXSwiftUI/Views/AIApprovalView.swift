import SwiftUI

// MARK: - Approval (plan §23)
//
// `AIApproval` renders an approval request in all five lifecycle states —
// requested / approved / rejected / expired / executed — with the requested
// action's summary. Interactive controls emit `aiux.approval.resolve`
// actions upward; the renderer NEVER executes or auto-resolves anything.

/// Approval card. Approve/Reject are only actionable while `requested`.
public struct AIApproval: View {
    @Environment(\.aiuxTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.aiuxAction) private var emit

    public let approval: AIUXApproval

    public init(approval: AIUXApproval) {
        self.approval = approval
    }

    public var body: some View {
        let colors = theme.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: theme.space(.sm)) {
            HStack(spacing: theme.space(.sm)) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                Text(approval.prompt)
                    .font(theme.typography.label)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                badge
            }

            if let description = approval.description {
                Text(description)
                    .font(theme.typography.body)
                    .foregroundStyle(colors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let summary = approval.action.map({ actionSummary($0) }) {
                Text(summary)
                    .font(theme.typography.code)
                    .foregroundStyle(colors.muted)
                    .padding(theme.space(.sm))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colors.background)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radius.radius(.sm)))
                    .accessibilityLabel("Requested action: \(approval.action?.id ?? "")")
            }

            if let expiresAt = approval.expiresAt, approval.status == .requested {
                Label("Expires \(expiresAt)", systemImage: "clock")
                    .font(theme.typography.caption)
                    .foregroundStyle(colors.warning)
            }

            if let note = approval.resolution?.note {
                Text(note)
                    .font(theme.typography.caption)
                    .foregroundStyle(colors.muted)
            }

            controls
        }
        .padding(theme.space(.md))
        .background(colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.radius(.lg)))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.radius(.lg))
                .strokeBorder(statusColor.opacity(0.5), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Approval request: \(approval.prompt), status \(approval.status.rawValue)")
    }

    // MARK: Status rendering — all five states visually distinct (§23)

    private var statusIcon: String {
        switch approval.status {
        case .requested: return "hand.raised"
        case .approved: return "checkmark.circle"
        case .rejected: return "xmark.circle"
        case .expired: return "clock.badge.exclamationmark"
        case .executed: return "checkmark.seal.fill"
        }
    }

    private var statusColor: Color {
        let colors = theme.colors(for: colorScheme)
        switch approval.status {
        case .requested: return colors.warning
        case .approved: return colors.accent
        case .rejected: return colors.destructive
        case .expired: return colors.muted
        case .executed: return colors.success
        }
    }

    private var badge: some View {
        Text(approval.status.rawValue)
            .font(theme.typography.caption)
            .foregroundStyle(statusColor)
            .padding(.horizontal, theme.space(.xs))
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: Controls

    @ViewBuilder
    private var controls: some View {
        switch approval.status {
        case .requested:
            HStack(spacing: theme.space(.sm)) {
                Button {
                    resolve(.approved)
                } label: {
                    Text("Approve")
                        .font(theme.typography.label)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.colors(for: colorScheme).accent)
                .accessibilityHint("Emit approval for the host to execute")

                Button {
                    resolve(.rejected)
                } label: {
                    Text("Reject")
                        .font(theme.typography.label)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(theme.colors(for: colorScheme).destructive)
            }
        case .approved:
            Label("Approved — awaiting execution", systemImage: "hourglass")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors(for: colorScheme).accent)
        case .rejected:
            Label("Rejected", systemImage: "hand.raised.slash")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors(for: colorScheme).destructive)
        case .expired:
            Label("Expired", systemImage: "clock.badge.exclamationmark")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors(for: colorScheme).muted)
        case .executed:
            Label("Executed", systemImage: "checkmark.seal")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors(for: colorScheme).success)
        }
    }

    /// Emit `aiux.approval.resolve` — payload `{approvalId, decision}`. The
    /// host maps this to an `approval.resolved` event (or its own policy).
    private func resolve(_ decision: AIUXApprovalDecision) {
        emit(AIUXAction(id: AIUXAction.approvalResolve, payload: [
            "approvalId": .string(approval.id),
            "decision": .string(decision.rawValue),
        ]))
    }

    /// One-line summary of the requested action: `id` + sorted payload keys.
    private func actionSummary(_ action: AIUXAction) -> String {
        let keys = action.payload.keys.sorted()
        let kv = keys.map { "\($0): \(aiuxJSONDescription(action.payload[$0]) ?? "")" }
        return ([action.id] + kv).joined(separator: "\n")
    }
}
