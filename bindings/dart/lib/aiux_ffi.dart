/// Dart FFI wrapper over the AIUX C ABI (`aiux-capi`).
///
/// Mirrors the frozen session facade (PLAN §4): create / restore / dispatch /
/// dispatchBatch / snapshot / serialize / reset. JSON strings cross the
/// boundary; no internal type is exposed. See `bindings/dart/capi/aiux_capi.h`.
library;

export 'src/bindings.dart' show AiuxCapi;
export 'src/session.dart' show AiuxException, AiuxSession;
