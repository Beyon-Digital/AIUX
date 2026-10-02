import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'load.dart' as load;

/// Opaque handle to a live `AiuxSession` on the Rust side.
final class AiuxSessionHandle extends Opaque {}

typedef _VersionNative = Pointer<Utf8> Function();
typedef _CreateNative = Pointer<AiuxSessionHandle> Function(Pointer<Utf8>);
typedef _FreeSessionNative = Void Function(Pointer<AiuxSessionHandle>);
typedef _DispatchNative = Pointer<Utf8> Function(
    Pointer<AiuxSessionHandle>, Pointer<Utf8>);
typedef _UnaryNative = Pointer<Utf8> Function(Pointer<AiuxSessionHandle>);
typedef _ResetNative = Void Function(Pointer<AiuxSessionHandle>);
typedef _FreeStringNative = Void Function(Pointer<Utf8>);

/// Resolved `aiux-capi` exports. Construct once and reuse — callers pass the
/// instance to [AiuxSession].
final class AiuxCapi {
  AiuxCapi({String? libraryPath}) : this._(load.open(libraryPath));

  AiuxCapi._(DynamicLibrary lib)
      : version = lib.lookupFunction<_VersionNative, Pointer<Utf8> Function()>(
            'aiux_capi_version'),
        create = lib.lookupFunction<
            _CreateNative,
            Pointer<AiuxSessionHandle> Function(
                Pointer<Utf8>)>('aiux_session_create'),
        restore = lib.lookupFunction<
            _CreateNative,
            Pointer<AiuxSessionHandle> Function(
                Pointer<Utf8>)>('aiux_session_restore'),
        freeSession = lib.lookupFunction<_FreeSessionNative,
            void Function(Pointer<AiuxSessionHandle>)>('aiux_session_free'),
        dispatch = lib.lookupFunction<
            _DispatchNative,
            Pointer<Utf8> Function(Pointer<AiuxSessionHandle>,
                Pointer<Utf8>)>('aiux_session_dispatch'),
        dispatchBatch = lib.lookupFunction<
            _DispatchNative,
            Pointer<Utf8> Function(Pointer<AiuxSessionHandle>,
                Pointer<Utf8>)>('aiux_session_dispatch_batch'),
        snapshot = lib.lookupFunction<
            _UnaryNative,
            Pointer<Utf8> Function(
                Pointer<AiuxSessionHandle>)>('aiux_session_snapshot'),
        serialize = lib.lookupFunction<
            _UnaryNative,
            Pointer<Utf8> Function(
                Pointer<AiuxSessionHandle>)>('aiux_session_serialize'),
        reset = lib.lookupFunction<_ResetNative,
            void Function(Pointer<AiuxSessionHandle>)>('aiux_session_reset'),
        freeString =
            lib.lookupFunction<_FreeStringNative, void Function(Pointer<Utf8>)>(
                'aiux_string_free'),
        takeLastError =
            lib.lookupFunction<_VersionNative, Pointer<Utf8> Function()>(
                'aiux_take_last_error');

  final Pointer<Utf8> Function() version;
  final Pointer<AiuxSessionHandle> Function(Pointer<Utf8>) create;
  final Pointer<AiuxSessionHandle> Function(Pointer<Utf8>) restore;
  final void Function(Pointer<AiuxSessionHandle>) freeSession;
  final Pointer<Utf8> Function(Pointer<AiuxSessionHandle>, Pointer<Utf8>)
      dispatch;
  final Pointer<Utf8> Function(Pointer<AiuxSessionHandle>, Pointer<Utf8>)
      dispatchBatch;
  final Pointer<Utf8> Function(Pointer<AiuxSessionHandle>) snapshot;
  final Pointer<Utf8> Function(Pointer<AiuxSessionHandle>) serialize;
  final void Function(Pointer<AiuxSessionHandle>) reset;
  final void Function(Pointer<Utf8>) freeString;
  final Pointer<Utf8> Function() takeLastError;

  /// Copy a heap string returned by the library into a Dart [String] and
  /// release the native allocation. Returns `null` on a NULL pointer.
  String? takeString(Pointer<Utf8> p) {
    if (p == nullptr) return null;
    try {
      return p.toDartString();
    } finally {
      freeString(p);
    }
  }
}
