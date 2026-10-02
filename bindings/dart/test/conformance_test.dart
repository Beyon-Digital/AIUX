import 'dart:convert';
import 'dart:io';

import 'package:aiux_ffi/aiux_ffi.dart';
import 'package:test/test.dart';

/// State conformance through the C ABI (PLAN §16 Phase 7 gate): replay every
/// fixture's `events` array via `dispatch()` and byte-compare `serialize()`
/// against `conformance/expected/<name>.json` — the same assertion the Rust
/// harness (`aiux-conformance verify`) makes.
Directory _findRepoDir(String name) {
  var dir = Directory.current.absolute;
  while (true) {
    final candidate = Directory('${dir.path}/$name');
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('could not locate conformance dir "$name" walking up from '
          '${Directory.current.path}');
    }
    dir = parent;
  }
}

void main() {
  final fixtures = _findRepoDir('conformance/fixtures')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final expectedDir = _findRepoDir('conformance/expected');

  for (final fixture in fixtures) {
    final name = fixture.uri.pathSegments.last.replaceAll('.json', '');
    test('conformance: $name', () {
      final decoded =
          jsonDecode(fixture.readAsStringSync()) as Map<String, dynamic>;
      final events = decoded['events'] as List<dynamic>;

      final session = AiuxSession.create(configJson: '{}');
      addTearDown(session.close);
      for (final event in events) {
        session.dispatch(jsonEncode(event));
      }

      final expectedFile = File('${expectedDir.path}/$name.json');
      expect(expectedFile.existsSync(), isTrue,
          reason: 'missing expected output ${expectedFile.path}');
      expect(session.serialize(), expectedFile.readAsStringSync(),
          reason: 'serialized state differs from expected/$name.json');
    });
  }
}
