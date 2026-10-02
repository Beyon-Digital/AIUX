import 'dart:io';

import 'package:beyond_aiux/beyond_aiux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden (screenshot) tests for the Flutter renderer — Phase 8 (plan §16).
///
/// Golden PNGs are a REVIEW ARTIFACT, not a committed gate: they are produced
/// by the `flutter-goldens` CI job (`AIUX_GOLDENS=1 flutter test
/// test/golden_test.dart --update-goldens`) and uploaded with each run for a
/// human to eyeball — fonts render via the deterministic Ahem test font, so
/// runs are byte-stable on identical harness versions. To make them a hard
/// gate later, commit `test/goldens/` and drop `--update-goldens` in a
/// dedicated compare job.
///
/// Gated on the AIUX_GOLDENS env var so the normal `flutter test` still
/// compiles this file but skips it — goldens only make sense in the
/// dedicated job or a deliberate local run.
final _runGoldens = Platform.environment['AIUX_GOLDENS'] == '1';

/// Representative fixture set: every part kind + every surface DSL class,
/// light and dark. Kept small — each golden is a manual review burden.
const _fixtures = [
  'basic-response',
  'streaming-response',
  'markdown-code',
  'tool-success',
  'approval-requested',
  'context-injection',
  'attachment',
  'citation',
  'artifact-workspace',
  'surface-created',
  'surface-form',
  'surface-table',
  'surface-list',
];

Directory _repoDir() {
  var dir = Directory.current.absolute;
  while (true) {
    if (Directory('${dir.path}/conformance/fixtures').existsSync()) {
      return dir;
    }
    final parent = dir.parent.absolute;
    if (parent.path == dir.path) {
      throw StateError('repo root not found above ${Directory.current.path}');
    }
    dir = parent;
  }
}

Future<void> _pumpGolden(
  WidgetTester tester,
  AiuxSessionStore store, {
  Brightness brightness = Brightness.light,
}) async {
  // Fixed surface size → identical layout across machines; two frames
  // instead of pumpAndSettle because streaming/progress animate forever.
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: AIConversation(store: store)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 60));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = _repoDir();
  AiuxFixture fixture(String name) => AiuxFixture.fromFile(
      File('${repo.path}/conformance/fixtures/$name.json'));

  group('Flutter goldens', () {
    for (final name in _fixtures) {
      testWidgets(name, (tester) async {
        final store =
            AiuxSessionStore(backend: AiuxFfiBackend.create())
              ..ingestFixture(fixture(name));
        await _pumpGolden(tester, store);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$name.png'),
        );
        store.dispose();
      }, skip: !_runGoldens);
    }

    testWidgets('dark theme — surface-created', (tester) async {
      final store = AiuxSessionStore(backend: AiuxFfiBackend.create())
        ..ingestFixture(fixture('surface-created'));
      await _pumpGolden(tester, store, brightness: Brightness.dark);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/surface-created-dark.png'),
      );
      store.dispose();
    }, skip: !_runGoldens);
  });
}
