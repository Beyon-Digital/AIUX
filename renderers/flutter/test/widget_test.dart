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
