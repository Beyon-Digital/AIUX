import 'dart:convert';

import 'surface_node.dart';

// MARK: - Protocol models (PLAN §3)
//
// Decoding mirror of the Rust `snapshot()` render projection
// (core/rust/persistence `Snapshot`) and of the `state` body inside a
// persisted session (`conformance/expected/*.json`). Both shapes carry the
// same entity lists, so one model decodes either. Unknown fields are ignored
// (PLAN §21 — unknown optional fields must not break older renderers).

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

List<dynamic> _list(Object? v) => v is List ? v : const [];

String _str(Map<String, dynamic> m, String key, [String fallback = '']) =>
    m[key] is String ? m[key] as String : fallback;

String? _strOr(Map<String, dynamic> m, String key) =>
    m[key] is String ? m[key] as String : null;

bool _bool(Map<String, dynamic> m, String key, [bool fallback = false]) =>
    m[key] is bool ? m[key] as bool : fallback;

int _int(Map<String, dynamic> m, String key, [int fallback = 0]) =>
    m[key] is num ? (m[key] as num).toInt() : fallback;

double? _doubleOr(Map<String, dynamic> m, String key) =>
    m[key] is num ? (m[key] as num).toDouble() : null;

T? _enumOr<T extends Enum>(List<T> values, Object? wire) {
  if (wire is! String) return null;
  for (final v in values) {
    if (v.name == wire) return v;
  }
  return null;
}

T _enumOrDefault<T extends Enum>(List<T> values, Object? wire, T fallback) =>
    _enumOr(values, wire) ?? fallback;

/// Compact JSON string for free-form payloads (tool input/result, metadata).
String? aiuxJsonDescribe(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } catch (_) {
    return value.toString();
  }
}

// MARK: - Snapshot

/// The render-facing projection of session state — everything a renderer
/// needs and nothing it doesn't.
class AiuxSnapshot {
  AiuxSnapshot({
    this.protocolVersion = '',
    this.sessionId = '',
    this.session,
    this.messages = const [],
    this.tools = const [],
    this.approvals = const [],
    this.artifacts = const [],
    this.surfaces = const [],
    this.context = const [],
    this.runs = const [],
    this.activeRunId,
  });

  factory AiuxSnapshot.fromJson(Map<String, dynamic> json) => AiuxSnapshot(
        protocolVersion: _str(json, 'protocolVersion'),
        sessionId: _str(json, 'sessionId'),
        session: json['session'] is Map
            ? AiuxSessionEntity.fromJson(_map(json['session']))
            : null,
        messages: _list(json['messages'])
            .map((e) => AiuxMessage.fromJson(_map(e)))
            .toList(),
        tools: _list(json['tools'])
            .map((e) => AiuxTool.fromJson(_map(e)))
            .toList(),
        approvals: _list(json['approvals'])
            .map((e) => AiuxApproval.fromJson(_map(e)))
            .toList(),
        artifacts: _list(json['artifacts'])
            .map((e) => AiuxArtifact.fromJson(_map(e)))
            .toList(),
        surfaces: _list(json['surfaces'])
            .map((e) => AiuxSurfaceTree.fromJson(_map(e)))
            .toList(),
        context: _list(json['context'])
            .map((e) => AiuxContextEntity.fromJson(_map(e)))
            .toList(),
        runs:
            _list(json['runs']).map((e) => AiuxRun.fromJson(_map(e))).toList(),
        activeRunId: _strOr(json, 'activeRunId'),
      );

  /// Protocol version string, e.g. `0.1`.
  final String protocolVersion;
  final String sessionId;
  final AiuxSessionEntity? session;
  final List<AiuxMessage> messages;
  final List<AiuxTool> tools;
  final List<AiuxApproval> approvals;
  final List<AiuxArtifact> artifacts;
  final List<AiuxSurfaceTree> surfaces;
  final List<AiuxContextEntity> context;
  final List<AiuxRun> runs;
  final String? activeRunId;
}

/// The `serialize()` envelope / `conformance/expected` file shape —
/// `{protocolVersion, sessionId, state: {...same entity lists...}}`.
class AiuxPersistedEnvelope {
  AiuxPersistedEnvelope({
    required this.protocolVersion,
    required this.sessionId,
    required this.state,
    this.nextExpectedSequence = 0,
    this.seenEventIds = const [],
  });

  factory AiuxPersistedEnvelope.fromJson(Map<String, dynamic> json) =>
      AiuxPersistedEnvelope(
        protocolVersion: _str(json, 'protocolVersion'),
        sessionId: _str(json, 'sessionId'),
        state: AiuxSnapshot.fromJson(_map(json['state'])),
        nextExpectedSequence: _int(json, 'nextExpectedSequence'),
        seenEventIds:
            _list(json['seenEventIds']).map((e) => e.toString()).toList(),
      );

  final String protocolVersion;
  final String sessionId;
  final AiuxSnapshot state;
  final int nextExpectedSequence;
  final List<String> seenEventIds;

  /// The persisted state as a render snapshot.
  AiuxSnapshot get snapshot => AiuxSnapshot(
        protocolVersion: protocolVersion,
        sessionId: sessionId,
        session: state.session,
        messages: state.messages,
        tools: state.tools,
        approvals: state.approvals,
        artifacts: state.artifacts,
        surfaces: state.surfaces,
        context: state.context,
        runs: state.runs,
        activeRunId: state.activeRunId,
      );
}

// MARK: - Session entity

/// A declared session capability (e.g. `tools.execute`).
class AiuxCapability {
  AiuxCapability({required this.id, this.description, this.enabled = true});

  factory AiuxCapability.fromJson(Map<String, dynamic> json) => AiuxCapability(
        id: _str(json, 'id'),
        description: _strOr(json, 'description'),
        enabled: _bool(json, 'enabled', true),
      );

  final String id;
  final String? description;
  final bool enabled;
}

/// A contextual entity bound to the session (file, record, URL, ...).
class AiuxContextEntity {
  AiuxContextEntity({
    required this.id,
    required this.kind,
    required this.label,
    this.description,
    this.uri,
    this.data,
  });

  factory AiuxContextEntity.fromJson(Map<String, dynamic> json) =>
      AiuxContextEntity(
        id: _str(json, 'id'),
        kind: _str(json, 'kind'),
        label: _str(json, 'label'),
        description: _strOr(json, 'description'),
        uri: _strOr(json, 'uri'),
        data: json['data'],
      );

  final String id;
  final String kind;
  final String label;
  final String? description;
  final String? uri;
  final Object? data;
}

/// The `session` entity — established by `session.created`.
class AiuxSessionEntity {
  AiuxSessionEntity({
    required this.id,
    this.title,
    this.createdAt,
    this.capabilities = const [],
    this.context = const [],
    this.metadata,
  });

  factory AiuxSessionEntity.fromJson(Map<String, dynamic> json) =>
      AiuxSessionEntity(
        id: _str(json, 'id'),
        title: _strOr(json, 'title'),
        createdAt: _strOr(json, 'createdAt'),
        capabilities: _list(json['capabilities'])
            .map((e) => AiuxCapability.fromJson(_map(e)))
            .toList(),
        context: _list(json['context'])
            .map((e) => AiuxContextEntity.fromJson(_map(e)))
            .toList(),
        metadata: json['metadata'],
      );

  final String id;
  final String? title;
  final String? createdAt;
  final List<AiuxCapability> capabilities;
  final List<AiuxContextEntity> context;
  final Object? metadata;
}

// MARK: - Shared scalar enums (camelCase on the wire)

enum AiuxMessageRole { user, assistant, system, tool }

enum AiuxMessageStatus { streaming, complete, failed, cancelled }

enum AiuxToolStatus { running, completed, failed }

enum AiuxApprovalStatus { requested, approved, rejected, expired, executed }

enum AiuxApprovalDecision { approved, rejected, expired, executed }

enum AiuxRunStatus { running, completed, failed, cancelled }

enum AiuxStatusLevel { info, success, warning, error }

// MARK: - Messages & parts

/// A session message composed of typed parts.
class AiuxMessage {
  AiuxMessage({
    required this.id,
    required this.role,
    this.status,
    this.parts = const [],
    this.createdAt,
    this.metadata,
  });

  factory AiuxMessage.fromJson(Map<String, dynamic> json) => AiuxMessage(
        id: _str(json, 'id'),
        role: _enumOrDefault(
            AiuxMessageRole.values, json['role'], AiuxMessageRole.assistant),
        status: _enumOr(AiuxMessageStatus.values, json['status']),
        parts: _list(json['parts'])
            .map((e) => AiuxPart.fromJson(_map(e)))
            .toList(),
        createdAt: _strOr(json, 'createdAt'),
        metadata: json['metadata'],
      );

  final String id;
  final AiuxMessageRole role;
  final AiuxMessageStatus? status;
  final List<AiuxPart> parts;
  final String? createdAt;
  final Object? metadata;
}

/// A typed part within a message — all 13 protocol part kinds (PLAN §3) plus
/// `unknown` for forward compatibility. Serialized internally tagged:
/// `{"type": "text", ...}`.
sealed class AiuxPart {
  const AiuxPart({required this.id});

  /// The part's stable identifier.
  final String id;

  /// Discriminant name as it appears on the wire.
  String get kind;

  factory AiuxPart.fromJson(Map<String, dynamic> json) {
    final type = _str(json, 'type');
    var id = _str(json, 'id');
    if (id.isEmpty) id = 'part-$type';
    switch (type) {
      case 'text':
        return AiuxTextPart(id: id, text: _str(json, 'text'));
      case 'markdown':
        return AiuxMarkdownPart(id: id, markdown: _str(json, 'markdown'));
      case 'code':
        return AiuxCodePart(
            id: id,
            code: _str(json, 'code'),
            language: _strOr(json, 'language'));
      case 'image':
        return AiuxImagePart(
            id: id,
            attachment: AiuxAttachment.fromJson(_map(json['attachment'])));
      case 'attachment':
        return AiuxAttachmentPart(
            id: id,
            attachment: AiuxAttachment.fromJson(_map(json['attachment'])));
      case 'citation':
        return AiuxCitationPart(
            id: id, citation: AiuxCitation.fromJson(_map(json['citation'])));
      case 'tool':
        return AiuxToolPart(id: id, toolId: _str(json, 'toolId'));
      case 'approval':
        return AiuxApprovalPart(id: id, approvalId: _str(json, 'approvalId'));
      case 'artifact':
        return AiuxArtifactPart(id: id, artifactId: _str(json, 'artifactId'));
      case 'status':
        return AiuxStatusPart(
            id: id,
            text: _str(json, 'text'),
            level: _enumOr(AiuxStatusLevel.values, json['level']));
      case 'progress':
        return AiuxProgressPart(
            id: id, progress: AiuxProgress.fromJson(_map(json['progress'])));
      case 'surface':
        return AiuxSurfacePart(id: id, surfaceId: _str(json, 'surfaceId'));
      case 'error':
        final error = json['error'] is Map
            ? AiuxError.fromJson(_map(json['error']))
            : AiuxError(code: 'unknown', message: 'Unknown error');
        return AiuxErrorPart(id: id, error: error);
      default:
        return AiuxUnknownPart(
            id: id, type: type.isEmpty ? 'missing-type' : type);
    }
  }
}

class AiuxTextPart extends AiuxPart {
  const AiuxTextPart({required super.id, required this.text});
  final String text;
  @override
  String get kind => 'text';
}

class AiuxMarkdownPart extends AiuxPart {
  const AiuxMarkdownPart({required super.id, required this.markdown});
  final String markdown;
  @override
  String get kind => 'markdown';
}

class AiuxCodePart extends AiuxPart {
  const AiuxCodePart({required super.id, required this.code, this.language});
  final String code;
  final String? language;
  @override
  String get kind => 'code';
}

class AiuxImagePart extends AiuxPart {
  const AiuxImagePart({required super.id, required this.attachment});
  final AiuxAttachment attachment;
  @override
  String get kind => 'image';
}

class AiuxAttachmentPart extends AiuxPart {
  const AiuxAttachmentPart({required super.id, required this.attachment});
  final AiuxAttachment attachment;
  @override
  String get kind => 'attachment';
}

class AiuxCitationPart extends AiuxPart {
  const AiuxCitationPart({required super.id, required this.citation});
  final AiuxCitation citation;
  @override
  String get kind => 'citation';
}

class AiuxToolPart extends AiuxPart {
  const AiuxToolPart({required super.id, required this.toolId});
  final String toolId;
  @override
  String get kind => 'tool';
}

class AiuxApprovalPart extends AiuxPart {
  const AiuxApprovalPart({required super.id, required this.approvalId});
  final String approvalId;
  @override
  String get kind => 'approval';
}

class AiuxArtifactPart extends AiuxPart {
  const AiuxArtifactPart({required super.id, required this.artifactId});
  final String artifactId;
  @override
  String get kind => 'artifact';
}

class AiuxStatusPart extends AiuxPart {
  const AiuxStatusPart({required super.id, required this.text, this.level});
  final String text;
  final AiuxStatusLevel? level;
  @override
  String get kind => 'status';
}

class AiuxProgressPart extends AiuxPart {
  const AiuxProgressPart({required super.id, required this.progress});
  final AiuxProgress progress;
  @override
  String get kind => 'progress';
}

class AiuxSurfacePart extends AiuxPart {
  const AiuxSurfacePart({required super.id, required this.surfaceId});
  final String surfaceId;
  @override
  String get kind => 'surface';
}

class AiuxErrorPart extends AiuxPart {
  const AiuxErrorPart({required super.id, required this.error});
  final AiuxError error;
  @override
  String get kind => 'error';
}

/// A part kind this renderer doesn't know — rendered as a placeholder.
class AiuxUnknownPart extends AiuxPart {
  const AiuxUnknownPart({required super.id, required this.type});
  final String type;
  @override
  String get kind => type;
}

// MARK: - Attachments, citations, progress, errors

/// A file/media reference carried by parts or messages.
class AiuxAttachment {
  AiuxAttachment({this.id, this.name, this.mimeType, this.uri, this.sizeBytes});

  factory AiuxAttachment.fromJson(Map<String, dynamic> json) => AiuxAttachment(
        id: _strOr(json, 'id'),
        name: _strOr(json, 'name'),
        mimeType: _strOr(json, 'mimeType'),
        uri: _strOr(json, 'uri'),
        sizeBytes: json['sizeBytes'] is num
            ? (json['sizeBytes'] as num).toInt()
            : null,
      );

  final String? id;
  final String? name;
  final String? mimeType;
  final String? uri;
  final int? sizeBytes;
}

/// A source citation.
class AiuxCitation {
  AiuxCitation({this.id, this.title, this.uri, this.snippet, this.source});

  factory AiuxCitation.fromJson(Map<String, dynamic> json) => AiuxCitation(
        id: _strOr(json, 'id'),
        title: _strOr(json, 'title'),
        uri: _strOr(json, 'uri'),
        snippet: _strOr(json, 'snippet'),
        source: _strOr(json, 'source'),
      );

  final String? id;
  final String? title;
  final String? uri;
  final String? snippet;
  final String? source;
}

/// Normalized progress value.
class AiuxProgress {
  AiuxProgress({this.current, this.total, this.label});

  factory AiuxProgress.fromJson(Map<String, dynamic> json) => AiuxProgress(
        current: _doubleOr(json, 'current'),
        total: _doubleOr(json, 'total'),
        label: _strOr(json, 'label'),
      );

  final double? current;
  final double? total;
  final String? label;

  /// Fraction complete in `0...1`, when the payload carries a computable one.
  double? get fraction {
    final c = current, t = total;
    if (c == null || t == null || t <= 0) return null;
    return (c / t).clamp(0.0, 1.0);
  }
}

/// Structured error payload.
class AiuxError {
  AiuxError(
      {required this.code, required this.message, this.retryable, this.detail});

  factory AiuxError.fromJson(Map<String, dynamic> json) => AiuxError(
        code: _str(json, 'code'),
        message: _str(json, 'message'),
        retryable: json['retryable'] is bool ? json['retryable'] as bool : null,
        detail: json['detail'],
      );

  final String code;
  final String message;
  final bool? retryable;
  final Object? detail;
}

// MARK: - Tools, approvals, artifacts, runs

/// A tool invocation tracked by the session.
class AiuxTool {
  AiuxTool({
    required this.id,
    required this.name,
    required this.status,
    this.input,
    this.progress,
    this.result,
    this.error,
    this.startedAt,
    this.completedAt,
  });

  factory AiuxTool.fromJson(Map<String, dynamic> json) => AiuxTool(
        id: _str(json, 'id'),
        name: _str(json, 'name'),
        status: _enumOrDefault(
            AiuxToolStatus.values, json['status'], AiuxToolStatus.running),
        input: json['input'],
        progress: json['progress'] is Map
            ? AiuxProgress.fromJson(_map(json['progress']))
            : null,
        result: json['result'],
        error: json['error'] is Map
            ? AiuxError.fromJson(_map(json['error']))
            : null,
        startedAt: _strOr(json, 'startedAt'),
        completedAt: _strOr(json, 'completedAt'),
      );

  final String id;
  final String name;
  final AiuxToolStatus status;
  final Object? input;
  final AiuxProgress? progress;
  final Object? result;
  final AiuxError? error;
  final String? startedAt;
  final String? completedAt;
}

/// Recorded resolution of an approval.
class AiuxApprovalResolution {
  AiuxApprovalResolution({
    required this.decision,
    this.resolvedBy,
    this.note,
    this.resolvedAt,
  });

  factory AiuxApprovalResolution.fromJson(Map<String, dynamic> json) =>
      AiuxApprovalResolution(
        decision: _enumOrDefault(AiuxApprovalDecision.values, json['decision'],
            AiuxApprovalDecision.approved),
        resolvedBy: _strOr(json, 'resolvedBy'),
        note: _strOr(json, 'note'),
        resolvedAt: _strOr(json, 'resolvedAt'),
      );

  final AiuxApprovalDecision decision;
  final String? resolvedBy;
  final String? note;
  final String? resolvedAt;
}

/// An approval request tracked by the session (PLAN §23).
class AiuxApproval {
  AiuxApproval({
    required this.id,
    required this.prompt,
    required this.status,
    this.description,
    this.toolId,
    this.action,
    this.expiresAt,
    this.resolution,
  });

  factory AiuxApproval.fromJson(Map<String, dynamic> json) => AiuxApproval(
        id: _str(json, 'id'),
        prompt: _str(json, 'prompt'),
        status: _enumOrDefault(AiuxApprovalStatus.values, json['status'],
            AiuxApprovalStatus.requested),
        description: _strOr(json, 'description'),
        toolId: _strOr(json, 'toolId'),
        action: json['action'] is Map
            ? AiuxAction.fromJson(_map(json['action']))
            : null,
        expiresAt: _strOr(json, 'expiresAt'),
        resolution: json['resolution'] is Map
            ? AiuxApprovalResolution.fromJson(_map(json['resolution']))
            : null,
      );

  final String id;
  final String prompt;
  final AiuxApprovalStatus status;
  final String? description;
  final String? toolId;
  final AiuxAction? action;
  final String? expiresAt;
  final AiuxApprovalResolution? resolution;
}

/// A versioned artifact produced during the session.
class AiuxArtifact {
  AiuxArtifact({
    required this.id,
    required this.kind,
    this.title,
    this.revision = 0,
    this.content,
    this.uri,
    this.metadata,
  });

  factory AiuxArtifact.fromJson(Map<String, dynamic> json) => AiuxArtifact(
        id: _str(json, 'id'),
        kind: _str(json, 'kind'),
        title: _strOr(json, 'title'),
        revision: _int(json, 'revision'),
        content: _strOr(json, 'content'),
        uri: _strOr(json, 'uri'),
        metadata: json['metadata'],
      );

  final String id;
  final String kind;
  final String? title;
  final int revision;
  final String? content;
  final String? uri;
  final Object? metadata;
}

/// A run: one agent execution span within a session.
class AiuxRun {
  AiuxRun({
    required this.id,
    required this.status,
    this.retryOf,
    this.inputMessageId,
    this.result,
    this.error,
    this.startedAt,
    this.completedAt,
  });

  factory AiuxRun.fromJson(Map<String, dynamic> json) => AiuxRun(
        id: _str(json, 'id'),
        status: _enumOrDefault(
            AiuxRunStatus.values, json['status'], AiuxRunStatus.running),
        retryOf: _strOr(json, 'retryOf'),
        inputMessageId: _strOr(json, 'inputMessageId'),
        result: json['result'],
        error: json['error'] is Map
            ? AiuxError.fromJson(_map(json['error']))
            : null,
        startedAt: _strOr(json, 'startedAt'),
        completedAt: _strOr(json, 'completedAt'),
      );

  final String id;
  final AiuxRunStatus status;
  final String? retryOf;
  final String? inputMessageId;
  final Object? result;
  final AiuxError? error;
  final String? startedAt;
  final String? completedAt;
}

// MARK: - Semantic action

/// A semantic action emitted by interactive nodes and views.
///
/// Payloads are data only (PLAN §23); the host resolves `id` through its own
/// policy before executing anything. Views never execute.
class AiuxAction {
  const AiuxAction({required this.id, this.payload = const {}});

  factory AiuxAction.fromJson(Map<String, dynamic> json) => AiuxAction(
        id: _str(json, 'id'),
        payload: json['payload'] is Map ? _map(json['payload']) : const {},
      );

  /// Semantic action identifier, e.g. `invoice.approve`.
  final String id;

  /// Arbitrary JSON payload carried to the host.
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {'id': id, 'payload': payload};

  // Canonical action ids emitted by beyond_aiux views — every id lives under
  // the `aiux.*` namespace; hosts resolve through their own policy (PLAN §23).
  static const composerSend = 'aiux.composer.send';
  static const composerCancel = 'aiux.composer.cancel';
  static const composerAttach = 'aiux.composer.attach';
  static const approvalResolve = 'aiux.approval.resolve';
  static const errorRetry = 'aiux.error.retry';
  static const citationOpen = 'aiux.citation.open';
  static const attachmentOpen = 'aiux.attachment.open';
  static const contextRemove = 'aiux.context.remove';
  static const contextAdd = 'aiux.context.add';
  static const fieldChange = 'aiux.field.change';
  static const artifactOpen = 'aiux.artifact.open';
}

// MARK: - Render model

/// Snapshot entities indexed by id — the lookup layer between typed part
/// references and the views that render them. Rebuilt per snapshot.
class AiuxRenderModel {
  AiuxRenderModel({required this.snapshot})
      : toolsById = {for (final t in snapshot.tools) t.id: t},
        approvalsById = {for (final a in snapshot.approvals) a.id: a},
        artifactsById = {for (final a in snapshot.artifacts) a.id: a},
        surfacesById = {for (final s in snapshot.surfaces) s.id: s};

  final AiuxSnapshot snapshot;
  final Map<String, AiuxTool> toolsById;
  final Map<String, AiuxApproval> approvalsById;
  final Map<String, AiuxArtifact> artifactsById;
  final Map<String, AiuxSurfaceTree> surfacesById;

  AiuxTool? tool(String id) => toolsById[id];
  AiuxApproval? approval(String id) => approvalsById[id];
  AiuxArtifact? artifact(String id) => artifactsById[id];
  AiuxSurfaceTree? surface(String id) => surfacesById[id];

  /// The currently streaming message, if the active run has one in flight.
  AiuxMessage? get streamingMessage {
    for (final m in snapshot.messages.reversed) {
      if (m.status == AiuxMessageStatus.streaming) return m;
    }
    return null;
  }

  /// Whether any approval is still awaiting resolution.
  bool get hasPendingApproval =>
      snapshot.approvals.any((a) => a.status == AiuxApprovalStatus.requested);
}
