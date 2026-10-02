import Foundation

// MARK: - Snapshot
//
// Decodable mirror of the Rust `snapshot()` render projection
// (core/rust/persistence `Snapshot`) and of the `state` body inside a
// persisted session (`conformance/expected/*.json`). Both shapes carry the
// same entity lists, so one model decodes either. Unknown fields are ignored
// (plan §21 — unknown optional fields must not break older renderers).

/// The render-facing projection of session state — everything a renderer
/// needs and nothing it doesn't.
public struct AIUXSnapshot: Equatable, Sendable {
    /// Protocol version string, e.g. `0.1`.
    public var protocolVersion: String = ""
    /// Bound session id.
    public var sessionId: String = ""
    /// Session entity, once `session.created` lands.
    public var session: AIUXSessionEntity?
    /// Messages in arrival order.
    public var messages: [AIUXMessage] = []
    /// Tool invocations in start order.
    public var tools: [AIUXTool] = []
    /// Approvals in request order.
    public var approvals: [AIUXApproval] = []
    /// Artifacts in creation order.
    public var artifacts: [AIUXArtifact] = []
    /// Surfaces in creation order.
    public var surfaces: [AIUXSurfaceTree] = []
    /// Context entities in injection order.
    public var context: [AIUXContextEntity] = []
    /// Runs in start order.
    public var runs: [AIUXRun] = []
    /// Currently-active run.
    public var activeRunId: String?

    public init() {}
}

extension AIUXSnapshot: Decodable {
    private enum CodingKeys: String, CodingKey {
        case protocolVersion, sessionId, session, messages, tools, approvals
        case artifacts, surfaces, context, runs, activeRunId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        protocolVersion = try c.decodeIfPresent(String.self, forKey: .protocolVersion) ?? ""
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId) ?? ""
        session = try c.decodeIfPresent(AIUXSessionEntity.self, forKey: .session)
        messages = try c.decodeIfPresent([AIUXMessage].self, forKey: .messages) ?? []
        tools = try c.decodeIfPresent([AIUXTool].self, forKey: .tools) ?? []
        approvals = try c.decodeIfPresent([AIUXApproval].self, forKey: .approvals) ?? []
        artifacts = try c.decodeIfPresent([AIUXArtifact].self, forKey: .artifacts) ?? []
        surfaces = try c.decodeIfPresent([AIUXSurfaceTree].self, forKey: .surfaces) ?? []
        context = try c.decodeIfPresent([AIUXContextEntity].self, forKey: .context) ?? []
        runs = try c.decodeIfPresent([AIUXRun].self, forKey: .runs) ?? []
        activeRunId = try c.decodeIfPresent(String.self, forKey: .activeRunId)
    }
}

/// The `serialize()` envelope / `conformance/expected` file shape —
/// `{protocolVersion, sessionId, state: {...same entity lists...}}`.
public struct AIUXPersistedEnvelope: Equatable, Sendable {
    public var protocolVersion: String
    public var sessionId: String
    public var state: AIUXSnapshot

    /// The persisted state as a render snapshot.
    public var snapshot: AIUXSnapshot {
        var s = state
        s.protocolVersion = protocolVersion
        s.sessionId = sessionId
        return s
    }
}

extension AIUXPersistedEnvelope: Decodable {
    private enum CodingKeys: String, CodingKey {
        case protocolVersion, sessionId, state
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        protocolVersion = try c.decodeIfPresent(String.self, forKey: .protocolVersion) ?? ""
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId) ?? ""
        state = try c.decodeIfPresent(AIUXSnapshot.self, forKey: .state) ?? AIUXSnapshot()
    }
}

// MARK: - Session entity

/// A declared session capability (e.g. `tools.execute`).
public struct AIUXCapability: Codable, Equatable, Sendable {
    public var id: String
    public var description: String?
    public var enabled: Bool = true

    public init(id: String) { self.id = id }

    private enum CodingKeys: String, CodingKey { case id, description, enabled }

    /// `enabled` defaults to true on the wire (`default_true` in the schema).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}

/// A contextual entity bound to the session (file, record, URL, ...).
public struct AIUXContextEntity: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: String
    public var label: String
    public var description: String?
    public var uri: String?
    public var data: AIUXJSONValue?

    public init(id: String, kind: String, label: String) {
        self.id = id
        self.kind = kind
        self.label = label
    }
}

/// The `session` entity — established by `session.created`.
public struct AIUXSessionEntity: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String?
    public var createdAt: String?
    public var capabilities: [AIUXCapability] = []
    public var context: [AIUXContextEntity] = []
    public var metadata: AIUXJSONValue?

    public init(id: String) { self.id = id }

    private enum CodingKeys: String, CodingKey {
        case id, title, createdAt, capabilities, context, metadata
    }

    /// Empty lists are omitted on the wire — decode them as `[]`.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        capabilities = try c.decodeIfPresent([AIUXCapability].self, forKey: .capabilities) ?? []
        context = try c.decodeIfPresent([AIUXContextEntity].self, forKey: .context) ?? []
        metadata = try c.decodeIfPresent(AIUXJSONValue.self, forKey: .metadata)
    }
}

// MARK: - Shared scalar enums (camelCase on the wire)

/// Message author role.
public enum AIUXMessageRole: String, Codable, Sendable {
    case user, assistant, system, tool
}

/// Message lifecycle status.
public enum AIUXMessageStatus: String, Codable, Sendable {
    case streaming, complete, failed, cancelled
}

/// Tool lifecycle status.
public enum AIUXToolStatus: String, Codable, Sendable {
    case running, completed, failed
}

/// Approval lifecycle status (plan §23).
public enum AIUXApprovalStatus: String, Codable, Sendable {
    case requested, approved, rejected, expired, executed
}

/// The decision carried by `approval.resolved`.
public enum AIUXApprovalDecision: String, Codable, Sendable {
    case approved, rejected, expired, executed
}

/// Run lifecycle status.
public enum AIUXRunStatus: String, Codable, Sendable {
    case running, completed, failed, cancelled
}

/// Severity for `status` parts and nodes.
public enum AIUXStatusLevel: String, Codable, Sendable {
    case info, success, warning, error
}

// MARK: - Messages

/// A session message composed of typed parts.
public struct AIUXMessage: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var role: AIUXMessageRole
    public var status: AIUXMessageStatus?
    public var parts: [AIUXPart] = []
    public var createdAt: String?
    public var metadata: AIUXJSONValue?

    public init(id: String, role: AIUXMessageRole, parts: [AIUXPart] = []) {
        self.id = id
        self.role = role
        self.parts = parts
    }

    private enum CodingKeys: String, CodingKey {
        case id, role, status, parts, createdAt, metadata
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        role = try c.decode(AIUXMessageRole.self, forKey: .role)
        status = try c.decodeIfPresent(AIUXMessageStatus.self, forKey: .status)
        parts = try c.decodeIfPresent([AIUXPart].self, forKey: .parts) ?? []
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        metadata = try c.decodeIfPresent(AIUXJSONValue.self, forKey: .metadata)
    }
}

// MARK: - Parts

/// A typed part within a message (all 13 protocol part kinds; plan §3).
/// Serialized internally tagged: `{"type": "text", ...}`.
/// Unknown `type` values decode to `.unknown` — forward-compat, never fatal.
public enum AIUXPart: Equatable, Identifiable, Sendable {
    /// Plain text (supports `text.delta` append).
    case text(id: String, text: String)
    /// Markdown (supports `text.delta` append).
    case markdown(id: String, markdown: String)
    /// Code block.
    case code(id: String, code: String, language: String?)
    /// Image attachment.
    case image(id: String, attachment: AIUXAttachment)
    /// Generic attachment.
    case attachment(id: String, attachment: AIUXAttachment)
    /// Source citation.
    case citation(id: String, citation: AIUXCitation)
    /// Reference to a session-level tool record.
    case tool(id: String, toolId: String)
    /// Reference to a session-level approval record.
    case approval(id: String, approvalId: String)
    /// Reference to a session-level artifact.
    case artifact(id: String, artifactId: String)
    /// Inline status line.
    case status(id: String, text: String, level: AIUXStatusLevel?)
    /// Inline progress indicator.
    case progress(id: String, progress: AIUXProgress)
    /// Reference to a session-level surface.
    case surface(id: String, surfaceId: String)
    /// Error content.
    case error(id: String, error: AIUXError)
    /// A part kind this renderer doesn't know — rendered as a placeholder.
    case unknown(id: String, type: String)

    /// The part's stable identifier.
    public var id: String {
        switch self {
        case .text(let id, _): return id
        case .markdown(let id, _): return id
        case .code(let id, _, _): return id
        case .image(let id, _): return id
        case .attachment(let id, _): return id
        case .citation(let id, _): return id
        case .tool(let id, _): return id
        case .approval(let id, _): return id
        case .artifact(let id, _): return id
        case .status(let id, _, _): return id
        case .progress(let id, _): return id
        case .surface(let id, _): return id
        case .error(let id, _): return id
        case .unknown(let id, _): return id
        }
    }

    /// Discriminant name as it appears on the wire.
    public var kind: String {
        switch self {
        case .text: return "text"
        case .markdown: return "markdown"
        case .code: return "code"
        case .image: return "image"
        case .attachment: return "attachment"
        case .citation: return "citation"
        case .tool: return "tool"
        case .approval: return "approval"
        case .artifact: return "artifact"
        case .status: return "status"
        case .progress: return "progress"
        case .surface: return "surface"
        case .error: return "error"
        case .unknown(_, let type): return type
        }
    }
}

extension AIUXPart: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, id
        case text, markdown, code, language
        case attachment, citation, toolId, approvalId, artifactId, surfaceId
        case level, progress, error
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        let id = try c.decodeIfPresent(String.self, forKey: .id)
        let fallbackID = id ?? "part-\(type)-\(UUID().uuidString)"
        switch type {
        case "text":
            self = .text(id: fallbackID, text: try c.decodeIfPresent(String.self, forKey: .text) ?? "")
        case "markdown":
            self = .markdown(id: fallbackID, markdown: try c.decodeIfPresent(String.self, forKey: .markdown) ?? "")
        case "code":
            self = .code(
                id: fallbackID,
                code: try c.decodeIfPresent(String.self, forKey: .code) ?? "",
                language: try c.decodeIfPresent(String.self, forKey: .language)
            )
        case "image":
            let a = try c.decodeIfPresent(AIUXAttachment.self, forKey: .attachment) ?? AIUXAttachment()
            self = .image(id: fallbackID, attachment: a)
        case "attachment":
            let a = try c.decodeIfPresent(AIUXAttachment.self, forKey: .attachment) ?? AIUXAttachment()
            self = .attachment(id: fallbackID, attachment: a)
        case "citation":
            let citation = try c.decodeIfPresent(AIUXCitation.self, forKey: .citation) ?? AIUXCitation()
            self = .citation(id: fallbackID, citation: citation)
        case "tool":
            self = .tool(id: fallbackID, toolId: try c.decodeIfPresent(String.self, forKey: .toolId) ?? "")
        case "approval":
            self = .approval(id: fallbackID, approvalId: try c.decodeIfPresent(String.self, forKey: .approvalId) ?? "")
        case "artifact":
            self = .artifact(id: fallbackID, artifactId: try c.decodeIfPresent(String.self, forKey: .artifactId) ?? "")
        case "status":
            self = .status(
                id: fallbackID,
                text: try c.decodeIfPresent(String.self, forKey: .text) ?? "",
                level: try c.decodeIfPresent(AIUXStatusLevel.self, forKey: .level)
            )
        case "progress":
            let p = try c.decodeIfPresent(AIUXProgress.self, forKey: .progress) ?? AIUXProgress()
            self = .progress(id: fallbackID, progress: p)
        case "surface":
            self = .surface(id: fallbackID, surfaceId: try c.decodeIfPresent(String.self, forKey: .surfaceId) ?? "")
        case "error":
            let e = try c.decodeIfPresent(AIUXError.self, forKey: .error)
                ?? AIUXError(code: "unknown", message: "Unknown error")
            self = .error(id: fallbackID, error: e)
        default:
            self = .unknown(id: fallbackID, type: type.isEmpty ? "missing-type" : type)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let id, let text):
            try c.encode("text", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(text, forKey: .text)
        case .markdown(let id, let markdown):
            try c.encode("markdown", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(markdown, forKey: .markdown)
        case .code(let id, let code, let language):
            try c.encode("code", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(code, forKey: .code)
            try c.encodeIfPresent(language, forKey: .language)
        case .image(let id, let a):
            try c.encode("image", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(a, forKey: .attachment)
        case .attachment(let id, let a):
            try c.encode("attachment", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(a, forKey: .attachment)
        case .citation(let id, let citation):
            try c.encode("citation", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(citation, forKey: .citation)
        case .tool(let id, let toolId):
            try c.encode("tool", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(toolId, forKey: .toolId)
        case .approval(let id, let approvalId):
            try c.encode("approval", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(approvalId, forKey: .approvalId)
        case .artifact(let id, let artifactId):
            try c.encode("artifact", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(artifactId, forKey: .artifactId)
        case .status(let id, let text, let level):
            try c.encode("status", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(text, forKey: .text)
            try c.encodeIfPresent(level, forKey: .level)
        case .progress(let id, let progress):
            try c.encode("progress", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(progress, forKey: .progress)
        case .surface(let id, let surfaceId):
            try c.encode("surface", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(surfaceId, forKey: .surfaceId)
        case .error(let id, let error):
            try c.encode("error", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(error, forKey: .error)
        case .unknown(let id, let type):
            try c.encode(type, forKey: .type)
            try c.encode(id, forKey: .id)
        }
    }
}

// MARK: - Attachments, citations, progress, errors

/// A file/media reference carried by parts or messages.
public struct AIUXAttachment: Codable, Equatable, Sendable {
    public var id: String?
    public var name: String?
    public var mimeType: String?
    public var uri: String?
    public var sizeBytes: UInt64?

    public init() {}
}

/// A source citation.
public struct AIUXCitation: Codable, Equatable, Sendable {
    public var id: String?
    public var title: String?
    public var uri: String?
    public var snippet: String?
    public var source: String?

    public init() {}
}

/// Normalized progress value.
public struct AIUXProgress: Codable, Equatable, Sendable {
    public var current: Double?
    public var total: Double?
    public var label: String?

    public init() {}

    /// Fraction complete in `0...1`, when the payload carries a computable one.
    public var fraction: Double? {
        guard let current, let total, total > 0 else { return nil }
        return min(max(current / total, 0), 1)
    }
}

/// Structured error payload.
public struct AIUXError: Codable, Equatable, Sendable {
    public var code: String
    public var message: String
    public var retryable: Bool?
    public var detail: AIUXJSONValue?

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

// MARK: - Tools, approvals, artifacts, runs

/// A tool invocation tracked by the session.
public struct AIUXTool: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var status: AIUXToolStatus
    public var input: AIUXJSONValue?
    public var progress: AIUXProgress?
    public var result: AIUXJSONValue?
    public var error: AIUXError?
    public var startedAt: String?
    public var completedAt: String?

    public init(id: String, name: String, status: AIUXToolStatus) {
        self.id = id
        self.name = name
        self.status = status
    }
}

/// Recorded resolution of an approval.
public struct AIUXApprovalResolution: Codable, Equatable, Sendable {
    public var decision: AIUXApprovalDecision
    public var resolvedBy: String?
    public var note: String?
    public var resolvedAt: String?

    public init(decision: AIUXApprovalDecision) { self.decision = decision }
}

/// An approval request tracked by the session (plan §23).
public struct AIUXApproval: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var prompt: String
    public var description: String?
    public var toolId: String?
    public var action: AIUXAction?
    public var status: AIUXApprovalStatus
    public var expiresAt: String?
    public var resolution: AIUXApprovalResolution?

    public init(id: String, prompt: String, status: AIUXApprovalStatus) {
        self.id = id
        self.prompt = prompt
        self.status = status
    }
}

/// A versioned artifact produced during the session.
public struct AIUXArtifact: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: String
    public var title: String?
    public var revision: UInt64 = 0
    public var content: String?
    public var uri: String?
    public var metadata: AIUXJSONValue?

    public init(id: String, kind: String) {
        self.id = id
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, title, revision, content, uri, metadata
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(String.self, forKey: .kind)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        revision = try c.decodeIfPresent(UInt64.self, forKey: .revision) ?? 0
        content = try c.decodeIfPresent(String.self, forKey: .content)
        uri = try c.decodeIfPresent(String.self, forKey: .uri)
        metadata = try c.decodeIfPresent(AIUXJSONValue.self, forKey: .metadata)
    }
}

/// A run: one agent execution span within a session.
public struct AIUXRun: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var status: AIUXRunStatus
    public var retryOf: String?
    public var inputMessageId: String?
    public var result: AIUXJSONValue?
    public var error: AIUXError?
    public var startedAt: String?
    public var completedAt: String?

    public init(id: String, status: AIUXRunStatus) {
        self.id = id
        self.status = status
    }
}

// MARK: - Semantic action

/// A semantic action emitted by interactive nodes and views.
///
/// Payloads are data only (plan §23); the host resolves `id` through its own
/// policy before executing anything. Views never execute.
public struct AIUXAction: Codable, Equatable, Sendable {
    /// Semantic action identifier, e.g. `invoice.approve`.
    public var id: String
    /// Arbitrary JSON payload carried to the host.
    public var payload: [String: AIUXJSONValue]

    public init(id: String, payload: [String: AIUXJSONValue] = [:]) {
        self.id = id
        self.payload = payload
    }
}

// MARK: - Canonical action ids emitted by AIUXSwiftUI views
//
// Every id lives under the `aiux.*` namespace; host apps resolve them through
// their own policy (plan §1, §23). Surface payloads may also carry arbitrary
// host-defined ids (e.g. `invoice.approve`).

extension AIUXAction {
    /// Composer send: payload `{text}`.
    public static let composerSend = "aiux.composer.send"
    /// Composer cancel: stops the active run.
    public static let composerCancel = "aiux.composer.cancel"
    /// Composer attachment hook: host opens its picker.
    public static let composerAttach = "aiux.composer.attach"
    /// Approval resolve: payload `{approvalId, decision}` (+ `action` when the
    /// request carried one).
    public static let approvalResolve = "aiux.approval.resolve"
    /// Retry a failed error part: payload `{partId, code}`.
    public static let errorRetry = "aiux.error.retry"
    /// Open a citation: payload `{citationId?, uri?, title?}` — host validates
    /// the target before navigating (§23).
    public static let citationOpen = "aiux.citation.open"
    /// Open an attachment/artifact URI: payload `{uri?}` — host-mediated.
    public static let attachmentOpen = "aiux.attachment.open"
    /// Context chip remove: payload `{entityId}`.
    public static let contextRemove = "aiux.context.remove"
    /// Context bar add hook: host opens its picker.
    public static let contextAdd = "aiux.context.add"
    /// Surface field change: payload `{name, value}`.
    public static let fieldChange = "aiux.field.change"
    /// Artifact opened: payload `{artifactId}`.
    public static let artifactOpen = "aiux.artifact.open"
}
