import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';

/// Error reported by the `aiux-capi` boundary (see `aiux_take_last_error`).
final class AiuxException implements Exception {
  AiuxException(this.message);

  final String message;

  @override
  String toString() => 'AiuxException: $message';
}

/// High-level wrapper over a native `AiuxSessionHandle`.
///
/// Mirrors the frozen facade: dispatch / dispatchBatch / snapshot /
/// serialize / reset — JSON in, JSON out. [close] releases the native
/// session; a [Finalizer] covers callers that forget.
final class AiuxSession {
  AiuxSession._(this._handle, this._api);

  /// Shared API instance — sessions default to it so tests and apps can
  /// inject a specific library path via [AiuxCapi.new].
  static AiuxCapi? _defaultApi;
  static AiuxCapi get _api0 => _defaultApi ??= AiuxCapi();
  static set defaultApi(AiuxCapi api) => _defaultApi = api;

  static final Finalizer<_Pair> _finalizer = Finalizer((p) {
    p.api.freeSession(p.handle);
  });

  final Pointer<AiuxSessionHandle> _handle;
  final AiuxCapi _api;
  bool _closed = false;

  /// `aiux_capi_version`.
  static String libraryVersion({AiuxCapi? api}) {
    final a = api ?? _api0;
    return a.takeString(a.version()) ?? '';
  }

  /// `aiux_session_create(config_json)` — `configJson` may be null/`{}`.
  factory AiuxSession.create({String? configJson, AiuxCapi? api}) {
    final a = api ?? _api0;
    final config = (configJson ?? '{}').toNativeUtf8();
    try {
      final h = a.create(config);
      if (h == nullptr) throw _error(a, 'aiux_session_create failed');
      return AiuxSession._register(h, a);
    } finally {
      malloc.free(config);
    }
  }

  /// `aiux_session_restore(serialized_json)`.
  factory AiuxSession.restore(String serializedJson, {AiuxCapi? api}) {
    final a = api ?? _api0;
    final payload = serializedJson.toNativeUtf8();
    try {
      final h = a.restore(payload);
      if (h == nullptr) throw _error(a, 'aiux_session_restore failed');
      return AiuxSession._register(h, a);
    } finally {
      malloc.free(payload);
    }
  }

  static AiuxSession _register(Pointer<AiuxSessionHandle> h, AiuxCapi api) {
    final s = AiuxSession._(h, api);
    _finalizer.attach(s, _Pair(h, api), detach: s);
    return s;
  }

  /// `aiux_session_dispatch(event_json)` → dispatch report JSON.
  String dispatch(String eventJson) => _callString(
      'aiux_session_dispatch', (e) => _api.dispatch(_handle, e), eventJson);

  /// `aiux_session_dispatch_batch(events_json)` → dispatch report JSON.
  String dispatchBatch(String eventsJson) => _callString(
      'aiux_session_dispatch_batch',
      (e) => _api.dispatchBatch(_handle, e),
      eventsJson);

  /// `aiux_session_snapshot` → render snapshot JSON.
  String snapshot() {
    _check();
    final p = _api.snapshot(_handle);
    final out = _api.takeString(p);
    if (out == null) throw _error(_api, 'aiux_session_snapshot failed');
    return out;
  }

  /// `aiux_session_serialize` → canonical serialized state JSON.
  String serialize() {
    _check();
    final p = _api.serialize(_handle);
    final out = _api.takeString(p);
    if (out == null) throw _error(_api, 'aiux_session_serialize failed');
    return out;
  }

  /// `aiux_session_reset` — clears all session state.
  void reset() {
    _check();
    _api.reset(_handle);
  }

  /// Release the native session. Idempotent.
  void close() {
    if (_closed) return;
    _closed = true;
    _finalizer.detach(this);
    _api.freeSession(_handle);
  }

  String _callString(
      String name, Pointer<Utf8> Function(Pointer<Utf8>) call, String argJson) {
    _check();
    final arg = argJson.toNativeUtf8();
    try {
      final p = call(arg);
      final out = _api.takeString(p);
      if (out == null) throw _error(_api, '$name failed');
      return out;
    } finally {
      malloc.free(arg);
    }
  }

  void _check() {
    if (_closed) throw StateError('AiuxSession is closed');
  }

  static AiuxException _error(AiuxCapi api, String fallback) {
    final detail = api.takeString(api.takeLastError());
    return AiuxException(detail ?? fallback);
  }
}

final class _Pair {
  _Pair(this.handle, this.api);
  final Pointer<AiuxSessionHandle> handle;
  final AiuxCapi api;
}
