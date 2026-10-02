import 'dart:ffi';
import 'dart:io';

/// Locate and load the `aiux-capi` shared library.
///
/// Resolution order:
/// 1. `libraryPath` argument / `AIUX_CAPI_PATH` env — an explicit .so/.dylib/.dll.
/// 2. Next to the executable and its `lib/` dir — the installed bundle
///    layout (e.g. Flutter Linux `<bundle>/lib/libaiux_capi.so`).
/// 3. `<repo>/target/{release,debug}/libaiux_capi.<ext>` walking ancestors of
///    the current directory for a `Cargo.toml` (the repo root).
/// 4. `DynamicLibrary.open('libaiux_capi.<ext>')` — the platform loader path.
DynamicLibrary open(String? libraryPath) {
  final explicit = libraryPath ?? Platform.environment['AIUX_CAPI_PATH'];
  if (explicit != null && explicit.isNotEmpty) {
    return DynamicLibrary.open(explicit);
  }
  for (final candidate in _candidates()) {
    if (File(candidate).existsSync()) return DynamicLibrary.open(candidate);
  }
  return DynamicLibrary.open(_libName());
}

String _libName() {
  if (Platform.isMacOS) return 'libaiux_capi.dylib';
  if (Platform.isWindows) return 'aiux_capi.dll';
  return 'libaiux_capi.so';
}

List<String> _candidates() {
  final name = _libName();
  final out = <String>[
    // Bundled app: the library installs alongside the executable (lib/
    // subdir for Flutter bundles, flat for dart compile exe output dirs).
    '${File(Platform.resolvedExecutable).parent.path}/lib/$name',
    '${File(Platform.resolvedExecutable).parent.path}/$name',
  ];
  var dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/Cargo.toml').existsSync()) {
      out
        ..add('${dir.path}/target/release/$name')
        ..add('${dir.path}/target/debug/$name');
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return out;
}
