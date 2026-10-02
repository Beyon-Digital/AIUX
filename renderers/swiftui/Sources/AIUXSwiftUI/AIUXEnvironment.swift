import SwiftUI

// MARK: - Action + entity environment
//
// Views emit `AIUXAction`s upward through the environment; the host decides
// execution (plan §1, §23). Entity references inside parts (`tool`, `approval`,
// `artifact`, `surface`) resolve against a per-snapshot index carried in the
// environment, so part views never need prop drilling.

/// Snapshot entities indexed by id — the lookup layer between typed part
/// references and the views that render them. Rebuilt per snapshot.
public struct AIUXRenderModel: Equatable, Sendable {
    public var snapshot: AIUXSnapshot
    public var toolsByID: [String: AIUXTool]
    public var approvalsByID: [String: AIUXApproval]
    public var artifactsByID: [String: AIUXArtifact]
    public var surfacesByID: [String: AIUXSurfaceTree]

    public init(snapshot: AIUXSnapshot) {
        self.snapshot = snapshot
        toolsByID = Dictionary(uniqueKeysWithValues: snapshot.tools.map { ($0.id, $0) })
        approvalsByID = Dictionary(uniqueKeysWithValues: snapshot.approvals.map { ($0.id, $0) })
        artifactsByID = Dictionary(uniqueKeysWithValues: snapshot.artifacts.map { ($0.id, $0) })
        surfacesByID = Dictionary(uniqueKeysWithValues: snapshot.surfaces.map { ($0.id, $0) })
    }

    public func tool(_ id: String) -> AIUXTool? { toolsByID[id] }
    public func approval(_ id: String) -> AIUXApproval? { approvalsByID[id] }
    public func artifact(_ id: String) -> AIUXArtifact? { artifactsByID[id] }
    public func surface(_ id: String) -> AIUXSurfaceTree? { surfacesByID[id] }

    /// The currently streaming message, if the active run has one in flight.
    public var streamingMessage: AIUXMessage? {
        snapshot.messages.last { $0.status == .streaming }
    }

    /// Whether any approval is still awaiting resolution.
    public var hasPendingApproval: Bool {
        snapshot.approvals.contains { $0.status == .requested }
    }
}

// MARK: - Environment keys

/// The default action handler drops actions with nothing to call — safe for
/// previews and read-only embeddings.
private struct AIUXActionHandlerKey: EnvironmentKey {
    static let defaultValue: (AIUXAction) -> Void = { _ in }
}

private struct AIUXRenderModelKey: EnvironmentKey {
    static let defaultValue: AIUXRenderModel = AIUXRenderModel(snapshot: AIUXSnapshot())
}

extension EnvironmentValues {
    /// The handler every AIUX view reports semantic actions to.
    /// Set with `.onAIUXAction(_:)`.
    public var aiuxAction: (AIUXAction) -> Void {
        get { self[AIUXActionHandlerKey.self] }
        set { self[AIUXActionHandlerKey.self] = newValue }
    }

    /// The resolved entity index for the snapshot being rendered.
    public var aiuxRenderModel: AIUXRenderModel {
        get { self[AIUXRenderModelKey.self] }
        set { self[AIUXRenderModelKey.self] = newValue }
    }
}

extension View {
    /// Register the semantic-action handler for the AIUX subtree.
    public func onAIUXAction(_ handler: @escaping (AIUXAction) -> Void) -> some View {
        environment(\.aiuxAction, handler)
    }
}
