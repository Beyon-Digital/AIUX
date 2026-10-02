import 'dart:convert';
import 'dart:io';

import 'package:aiux_ffi/aiux_ffi.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';

// MARK: - Session driver
//
// `AiuxSessionStore` owns the session backend, ingests event batches, and
// publishes decoded snapshots to the views. All session behavior (state
// machine, ordering, idempotency) lives in the Rust core — views hold no
// business logic.
//
// The backend is a narrow JSON-string protocol matching the frozen
// `AiuxSession` facade (core/rust/session, PLAN §4). `AiuxFfiBackend`
// conforms it to `aiux_ffi.AiuxSession`; fixture playback can drive the
// store with any conforming backend.

/// The JSON-in/JSON-out session boundary every backend implements.
/// Mirrors `AiuxSession`: `dispatch`, `dispatchBatch`, `snapshot`,
/// `serialize`, `reset`.
abstract interface class AiuxSessionBackend {
  /// Reduce one event (JSON envelope).
  String dispatch(String eventJson);

  /// Reduce an ordered JSON array of events in one call.
  String dispatchBatch(String eventsJson);

  /// Canonical-JSON render snapshot for the current state.
  String snapshot();

  /// Canonical-JSON serialized session state.
  String serialize();

  /// Clear all session state.
  void reset();
}

/// The C-ABI backend: `aiux_ffi.AiuxSession` conformed to
/// [AiuxSessionBackend]. This is the Phase 7 path (PLAN §13):
/// Rust core → Dart FFI → Flutter widgets.
final class AiuxFfiBackend implements AiuxSessionBackend {
  AiuxFfiBackend._(this._session);

  final AiuxSession _session;

  /// Open a fresh session via `aiux_session_create`.
  factory AiuxFfiBackend.create({String? configJson, String? libraryPath}) =>
      AiuxFfiBackend._(AiuxSession.create(
          configJson: configJson,
          api:
              libraryPath == null ? null : AiuxCapi(libraryPath: libraryPath)));

  /// Restore a session from a `serialize()` payload.
  factory AiuxFfiBackend.restore(String serializedJson,
          {String? libraryPath}) =>
      AiuxFfiBackend._(AiuxSession.restore(serializedJson,
          api:
              libraryPath == null ? null : AiuxCapi(libraryPath: libraryPath)));

  @override
  String dispatch(String eventJson) => _session.dispatch(eventJson);

  @override
  String dispatchBatch(String eventsJson) => _session.dispatchBatch(eventsJson);

  @override
  String snapshot() => _session.snapshot();

  @override
  String serialize() => _session.serialize();

  @override
  void reset() => _session.reset();

  /// Release the native session.
  void close() => _session.close();
}

/// A backend's `dispatch`/`dispatchBatch` report.
class AiuxDispatchReport {
  AiuxDispatchReport({
    this.applied = 0,
    this.duplicatesIgnored = 0,
    this.buffered = 0,
  });

  factory AiuxDispatchReport.fromJson(Map<String, dynamic> json) =>
      AiuxDispatchReport(
        applied: json['applied'] is num ? (json['applied'] as num).toInt() : 0,
        duplicatesIgnored: json['duplicatesIgnored'] is num
            ? (json['duplicatesIgnored'] as num).toInt()
            : 0,
        buffered:
            json['buffered'] is num ? (json['buffered'] as num).toInt() : 0,
      );

  /// Events applied to state.
  final int applied;

  /// Replays of already-seen event ids, safely ignored.
  final int duplicatesIgnored;

  /// Out-of-order events parked pending missing sequences.
  final int buffered;
}

/// Errors surfaced by the store around backend or decode failures.
sealed class AiuxStoreError implements Exception {
  const AiuxStoreError(this.detail);
  final String detail;

  @override
  String toString() => '$runtimeType: $detail';
}

/// The backend call failed (`ProtocolError` at the FFI boundary).
final class AiuxBackendError extends AiuxStoreError {
  const AiuxBackendError(super.detail);
}

/// `snapshot()` returned JSON the renderer could not decode.
final class AiuxCorruptSnapshotError extends AiuxStoreError {
  const AiuxCorruptSnapshotError(super.detail);
}

/// `dispatch*` returned an unparseable report.
final class AiuxCorruptReportError extends AiuxStoreError {
  const AiuxCorruptReportError(super.detail);
}

/// The snapshot-observing session object every AIUX view binds to.
class AiuxSessionStore extends ChangeNotifier {
  AiuxSessionStore({required this.backend}) {
    refresh();
  }

  /// The session backend (FFI via [AiuxFfiBackend], or a fixture/test
  /// backend).
  final AiuxSessionBackend backend;

  /// The latest decoded snapshot — published to all views.
  AiuxRenderModel get renderModel => _renderModel;
  AiuxRenderModel _renderModel = AiuxRenderModel(snapshot: AiuxSnapshot());

  /// The last backend/decode failure, kept for display. Views surface it;
  /// they never attempt recovery themselves.
  AiuxStoreError? get lastError => _lastError;
  AiuxStoreError? _lastError;

  /// The current snapshot.
  AiuxSnapshot get snapshot => _renderModel.snapshot;

  void _publish() {
    notifyListeners();
  }

  /// Pull `backend.snapshot()` into the published render model.
  void refresh() {
    try {
      final json = backend.snapshot();
      final decoded =
          AiuxSnapshot.fromJson(jsonDecode(json) as Map<String, dynamic>);
      _renderModel = AiuxRenderModel(snapshot: decoded);
    } catch (e) {
      _lastError = AiuxCorruptSnapshotError(e.toString());
    }
    _publish();
  }

  /// Reduce one event and republish. Returns the dispatch report.
  AiuxDispatchReport ingestEvent(String eventJson) {
    final String reportJson;
    try {
      reportJson = backend.dispatch(eventJson);
    } catch (e) {
      _lastError = AiuxBackendError(e.toString());
      _publish();
      rethrow;
    }
    return _ingestReport(reportJson);
  }

  /// Reduce a batch of events and republish once (PLAN §22 — streaming
  /// deltas batch here). Returns the dispatch report.
  AiuxDispatchReport ingestBatch(String eventsJson) {
    final String reportJson;
    try {
      reportJson = backend.dispatchBatch(eventsJson);
    } catch (e) {
      _lastError = AiuxBackendError(e.toString());
      _publish();
      rethrow;
    }
    return _ingestReport(reportJson);
  }

  /// Replay a conformance fixture (its `events` array) through the backend.
  AiuxDispatchReport ingestFixture(AiuxFixture fixture) =>
      ingestBatch(fixture.eventsJson());

  /// Serialized session state for persistence/replay.
  String serializedSession() {
    try {
      return backend.serialize();
    } catch (e) {
      _lastError = AiuxBackendError(e.toString());
      _publish();
      rethrow;
    }
  }

  /// Clear the session and republish an empty snapshot.
  void resetSession() {
    try {
      backend.reset();
      _lastError = null;
    } catch (e) {
      _lastError = AiuxBackendError(e.toString());
    }
    refresh();
  }

  AiuxDispatchReport _ingestReport(String reportJson) {
    try {
      final report = AiuxDispatchReport.fromJson(
          jsonDecode(reportJson) as Map<String, dynamic>);
      _lastError = null;
      refresh();
      return report;
    } catch (e) {
      _lastError = AiuxCorruptReportError(e.toString());
      refresh();
      rethrow;
    }
  }
}

// MARK: - Conformance fixture support
//
// The conformance catalog (`conformance/fixtures/*.json`) is the shared
// contract between the Rust core and every renderer. `AiuxFixture` decodes a
// fixture file's event array for replay through any `AiuxSessionBackend`.
// Renderers never mutate fixture contents.

/// One conformance fixture: `{name, protocolVersion, events: [...]}`.
/// Events are kept as raw JSON so replay happens verbatim.
class AiuxFixture {
  AiuxFixture._(
      {required this.name, this.protocolVersion, required this.events});

  /// Fixture name from the file (`name` field, else filename).
  final String name;

  /// Protocol version declared by the fixture.
  final String? protocolVersion;

  /// The raw `events` array as compact JSON objects.
  final List<String> events;

  /// Decode a fixture file's `events` array into raw JSON strings.
  /// A payload that is not a `{... , "events": [...]}` object throws
  /// [FormatException].
  factory AiuxFixture.fromJson(String json, {String name = 'fixture'}) {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('fixture is not a JSON object');
    }
    final rawEvents = decoded['events'];
    if (rawEvents is! List) {
      throw const FormatException('fixture is missing an events array');
    }
    return AiuxFixture._(
      name: decoded['name'] is String ? decoded['name'] as String : name,
      protocolVersion: decoded['protocolVersion'] is String
          ? decoded['protocolVersion'] as String
          : null,
      events: rawEvents.map((e) => jsonEncode(e)).toList(),
    );
  }

  /// Load a fixture from a file.
  factory AiuxFixture.fromFile(File file) =>
      AiuxFixture.fromJson(file.readAsStringSync(),
          name: file.uri.pathSegments.last.replaceAll('.json', ''));

  /// The `events` array serialized as one JSON array — the exact argument
  /// `dispatchBatch`/`ingestBatch` expects.
  String eventsJson() => '[${events.join(',')}]';
}

/// Reads the fixture directory (fixtures + expected states).
/// Pure I/O — no session or view logic.
abstract final class AiuxFixtureCatalog {
  /// Fixture names in the directory — every `*.json` file in
  /// `conformance/fixtures/` is a conformance case. Sorted for stability.
  static List<String> manifest(Directory directory) => directory
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
      .toList()
    ..sort();

  /// Load every fixture listed in the directory, in manifest order.
  static List<AiuxFixture> loadAll(Directory directory) => manifest(directory)
      .map((name) => AiuxFixture.fromFile(File('${directory.path}/$name.json')))
      .toList();
}
