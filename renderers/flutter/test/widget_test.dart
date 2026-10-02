import 'dart:convert';
import 'dart:io';

import 'package:beyond_aiux/beyond_aiux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Walks ancestors of the package dir to the repo root.
Directory _repoDir() {
  var dir = Directory.current.absolute;
  while (true) {
    if (Directory('${dir.path}/conformance/fixtures').existsSync() &&
        File('${dir.path}/Cargo.toml').existsSync()) {
      return dir;
    }
    final parent = dir.parent.absolute;
    if (parent.path == dir.path) {
      throw StateError('repo root not found above ${Directory.current.path}');
    }
    dir = parent;
  }
}

/// Records every action emitted from the subtree.
class _ActionRecorder extends StatelessWidget {
  const _ActionRecorder({required this.sink, required this.child});

  final List<AiuxAction> sink;
  final Widget child;

  @override
  Widget build(BuildContext context) => AiuxScope(
        model: AiuxScope.modelOf(context),
        emit: sink.add,
        child: child,
      );
}

AiuxSessionStore _storeFor(AiuxFixture fixture) {
  final store = AiuxSessionStore(backend: AiuxFfiBackend.create());
  store.ingestFixture(fixture);
  return store;
}

Future<void> _pumpConversation(
  WidgetTester tester,
  AiuxSessionStore store, {
  List<AiuxAction>? actions,
  AiuxConversationMode mode = AiuxConversationMode.fullscreen,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: _ActionRecorder(
          sink: actions ?? [],
          child: AIConversation(store: store, mode: mode),
        ),
      ),
    ),
  );
  // No pumpAndSettle — streaming dots and progress indicators animate
  // forever; two frames is enough for layout + ListenableBuilder.
  await tester.pump(const Duration(milliseconds: 60));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = _repoDir();
  AiuxFixture fixture(String name) => AiuxFixture.fromFile(
      File('${repo.path}/conformance/fixtures/$name.json'));

  group('AIConversation over the real FFI backend', () {
    testWidgets('basic-response renders both messages', (tester) async {
      final store = _storeFor(fixture('basic-response'));
      await _pumpConversation(tester, store);
      expect(find.text('What is the answer?'), findsOneWidget);
      expect(find.text('The answer is 42.'), findsOneWidget);
      expect(find.text('Basic response'), findsNothing); // empty state gone
      store.dispose();
    });

    testWidgets('dark theme resolves without errors', (tester) async {
      final store = _storeFor(fixture('basic-response'));
      await _pumpConversation(tester, store, brightness: Brightness.dark);
      expect(find.text('The answer is 42.'), findsOneWidget);
      store.dispose();
    });

    testWidgets('context-injection renders chips and emits remove',
        (tester) async {
      final actions = <AiuxAction>[];
      final store = _storeFor(fixture('context-injection'));
      await _pumpConversation(tester, store, actions: actions);
      expect(find.text('Cargo.toml'), findsOneWidget);
      expect(find.text('AIUX-7'), findsOneWidget);
      expect(find.text('Design doc'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close).last);
      expect(actions.last.id, AiuxAction.contextRemove);
      expect(actions.last.payload['entityId'], 'ctx-3');
      store.dispose();
    });

    testWidgets('surface-created renders the card tree and emits actions',
        (tester) async {
      final actions = <AiuxAction>[];
      final store = _storeFor(fixture('surface-created'));
      await _pumpConversation(tester, store, actions: actions);
      expect(find.text('Invoice summary'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text(r'$420.00'), findsOneWidget);
      expect(find.text('Due soon'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      expect(actions.last.id, isNotEmpty);
      store.dispose();
    });

    testWidgets('session-level entities decode into the render model',
        (tester) async {
      // approval-requested / tool-success carry entities with no message
      // parts — the stream renders only parts (matching the SwiftUI
      // reference); the entities resolve through the render model.
      final store = _storeFor(fixture('approval-requested'));
      expect(
          store.snapshot.approvals.single.prompt, 'Delete 12 stale branches?');
      expect(store.renderModel.hasPendingApproval, isTrue);
      await _pumpConversation(tester, store);
      store.dispose();

      final toolStore = _storeFor(fixture('tool-success'));
      expect(toolStore.snapshot.tools.single.name, 'search');
      toolStore.dispose();
    });

    testWidgets('markdown-code renders markdown and code parts',
        (tester) async {
      final store = _storeFor(fixture('markdown-code'));
      await _pumpConversation(tester, store);
      expect(find.textContaining('fn main'), findsWidgets);
      store.dispose();
    });

    testWidgets('embedded mode hides context bar and composer', (tester) async {
      final store = _storeFor(fixture('context-injection'));
      await _pumpConversation(tester, store,
          mode: AiuxConversationMode.embedded);
      expect(find.byType(AIContextBar), findsNothing);
      expect(find.byType(AIComposer), findsNothing);
      store.dispose();
    });

    testWidgets('every conformance fixture renders without errors',
        (tester) async {
      final fixtures = AiuxFixtureCatalog.loadAll(
          Directory('${repo.path}/conformance/fixtures'));
      for (final f in fixtures) {
        final store = _storeFor(f);
        expect(store.lastError, isNull, reason: 'fixture ${f.name}');
        await _pumpConversation(tester, store);
        expect(tester.takeException(), isNull, reason: 'fixture ${f.name}');
        store.dispose();
        (store.backend as AiuxFfiBackend).close();
      }
    });

    testWidgets('surface.updated re-renders a changed select value',
        (tester) async {
      final store = _storeFor(_selectFixture());
      await _pumpConversation(tester, store);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Published'), findsNothing);
      // The wire value changes draft → published; the mounted dropdown's
      // own FormFieldState must follow, not just `initialValue`.
      store.ingestEvent(_surfaceUpdatedSelect);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Published'), findsOneWidget);
      expect(find.text('Draft'), findsNothing);
      store.dispose();
      (store.backend as AiuxFfiBackend).close();
    });

    testWidgets('surface images refuse internal hosts and oversized data',
        (tester) async {
      final store = _storeFor(_imageFixture());
      await _pumpConversation(tester, store);
      // Loopback/private/non-canonical hosts, an over-cap inline payload,
      // and a non-image data URI all render as unsupported; only the tiny
      // inline png reaches an Image widget.
      expect(find.textContaining('Unsupported image:'), findsNWidgets(5));
      expect(find.byType(Image), findsOneWidget);
      store.dispose();
      (store.backend as AiuxFfiBackend).close();
    });

    testWidgets('composer send emits aiux.composer.send', (tester) async {
      final actions = <AiuxAction>[];
      final store = _storeFor(fixture('basic-response'));
      await _pumpConversation(tester, store, actions: actions);
      await tester.enterText(find.byType(TextField).first, 'Ship it');
      await tester.pump(const Duration(milliseconds: 16));
      await tester.tap(find.bySemanticsLabel('Send'));
      expect(actions.last.id, AiuxAction.composerSend);
      expect(actions.last.payload['text'], 'Ship it');
      store.dispose();
    });

    testWidgets('fullscreen mode shows composer and context bar',
        (tester) async {
      final store = _storeFor(fixture('context-injection'));
      await _pumpConversation(tester, store);
      expect(find.byType(AIContextBar), findsOneWidget);
      expect(find.byType(AIComposer), findsOneWidget);
      store.dispose();
    });
  });

  group('entity views with decoded fixtures', () {
    testWidgets('AIApproval renders prompt and emits resolve', (tester) async {
      final actions = <AiuxAction>[];
      final store = _storeFor(fixture('approval-requested'));
      final approval = store.snapshot.approvals.single;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: _ActionRecorder(
            sink: actions,
            child: Center(child: AIApproval(approval: approval)),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Delete 12 stale branches?'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      expect(actions.last.id, AiuxAction.approvalResolve);
      expect(actions.last.payload['approvalId'], 'a1');
      expect(actions.last.payload['decision'], 'approved');
      store.dispose();
    });

    testWidgets('AIToolStatus renders name, status, progress', (tester) async {
      final store = _storeFor(fixture('tool-success'));
      final tool = store.snapshot.tools.single;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(child: AIToolStatus(tool: tool)),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('search'), findsOneWidget);
      expect(find.text('completed'), findsOneWidget);
      expect(find.text('ranking'), findsOneWidget);
      store.dispose();
    });

    testWidgets('AIArtifactPreview renders card and opens detail',
        (tester) async {
      final store = _storeFor(fixture('artifact-update'));
      final artifact = store.snapshot.artifacts.single;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(child: AIArtifactPreview(artifact: artifact)),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('lib.rs (v2)'), findsOneWidget);
      await tester.tap(find.text('lib.rs (v2)'));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.textContaining('pub fn a()'), findsOneWidget);
      store.dispose();
    });
  });

  group('degradation', () {
    testWidgets('unknown part kind renders placeholder', (tester) async {
      const part = AiuxUnknownPart(id: 'p1', type: 'hologram');
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: AIPartView(part: part))),
      ));
      expect(find.textContaining('Unsupported'), findsOneWidget);
    });
  });
}

// MARK: - Inline fixture builders

const _pv = '0.1';

Map<String, Object?> _env(int seq, String type, Map<String, Object?> payload) =>
    {
      'eventId': 'fix-$seq',
      'protocolVersion': _pv,
      'sequence': seq,
      'sessionId': 's1',
      'timestamp': '2026-01-01T00:00:0${seq}Z',
      'type': type,
      'payload': payload,
    };

/// Minimal scripted message carrying a single surface with [children] —
/// covers nodes no shipped conformance fixture exercises.
AiuxFixture _surfaceFixture(List<Map<String, Object?>> children) =>
    AiuxFixture.fromJson(jsonEncode({
      'name': 'surface-fields',
      'protocolVersion': _pv,
      'events': [
        _env(0, 'session.created', {
          'protocolVersion': _pv,
          'session': {
            'id': 's1',
            'title': 'Surface fields',
            'createdAt': '2026-01-01T00:00:00Z',
          },
        }),
        _env(1, 'run.started', {
          'protocolVersion': _pv,
          'run': {
            'id': 'r1',
            'startedAt': '2026-01-01T00:00:01Z',
            'status': 'running',
          },
        }),
        _env(2, 'message.created', {
          'protocolVersion': _pv,
          'message': {
            'id': 'm1',
            'role': 'assistant',
            'status': 'streaming',
          },
        }),
        _env(3, 'surface.created', {
          'protocolVersion': _pv,
          'surface': {
            'id': 'sf-1',
            'name': 'fields',
            'revision': 0,
            'root': {'type': 'surface', 'children': children},
          },
        }),
        _env(4, 'part.added', {
          'protocolVersion': _pv,
          'messageId': 'm1',
          'part': {'id': 'm1-sf', 'type': 'surface', 'surfaceId': 'sf-1'},
        }),
        _env(5, 'message.updated', {
          'protocolVersion': _pv,
          'messageId': 'm1',
          'status': 'complete',
        }),
      ],
    }));

const _selectOptions = [
  {'value': 'draft', 'label': 'Draft'},
  {'value': 'published', 'label': 'Published'},
];

AiuxFixture _selectFixture() => _surfaceFixture([
      {
        'type': 'select',
        'name': 'status',
        'label': 'Status',
        'value': 'draft',
        'options': _selectOptions,
      },
    ]);

/// surface.updated replacing the root with value 'published' (seq 6).
String get _surfaceUpdatedSelect => jsonEncode(_env(6, 'surface.updated', {
      'protocolVersion': _pv,
      'surfaceId': 'sf-1',
      'root': {
        'type': 'surface',
        'children': [
          {
            'type': 'select',
            'name': 'status',
            'label': 'Status',
            'value': 'published',
            'options': _selectOptions,
          },
        ],
      },
    }));

AiuxFixture _imageFixture() => _surfaceFixture([
      {'type': 'image', 'src': 'http://127.0.0.1:8080/x.png', 'alt': 'loop'},
      {'type': 'image', 'src': 'http://host.local/i.png', 'alt': 'local'},
      {'type': 'image', 'src': 'http://0x7f000001/i.png', 'alt': 'hex'},
      {
        'type': 'image',
        'src': 'data:image/png;base64,${'A' * (8 * 1024 * 1024 + 16)}',
        'alt': 'huge',
      },
      {
        'type': 'image',
        'src': 'data:text/plain;base64,aGVsbG8=',
        'alt': 'not-image',
      },
      {
        // Tiny valid inline png — the one node that reaches an Image widget.
        'type': 'image',
        'src':
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
        'alt': 'pixel',
      },
    ]);
