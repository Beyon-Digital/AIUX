import 'package:aiux_example/main.dart';
import 'package:aiux_example/src/demo_controller.dart';
import 'package:aiux_example/src/demo_scenario.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Advance fake time in slices so the controller's trickle loop runs.
Future<void> _pumpFor(WidgetTester tester, Duration total,
    {Duration step = const Duration(milliseconds: 200)}) async {
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DemoEventFactory emits sequential envelopes', () {
    final factory = DemoEventFactory(sessionId: 's');
    final first = factory.event('session.created', {});
    final second = factory.event('run.started', {});
    expect(first, contains('"sequence":0'));
    expect(second, contains('"sequence":1'));
    expect(first, contains('"sessionId":"s"'));
  });

  test('DemoController boots with the scripted session', () {
    final controller = DemoController.bootstrap();
    controller.start();
    expect(controller.store.snapshot.session?.title, 'AIUX demo');
    expect(controller.store.snapshot.context, hasLength(2));
    controller.store.dispose();
  });

  testWidgets('demo app plays the scripted interaction end-to-end',
      (tester) async {
    await tester.pumpWidget(const AiuxExampleApp());
    await tester.pump();

    // Session bootstrapped: title + context chips visible.
    expect(find.text('AIUX demo'), findsWidgets);
    expect(find.text('report-draft.md'), findsOneWidget);
    expect(find.text('AIUX spec'), findsOneWidget);

    // Send a prompt through the composer.
    await tester.enterText(find.byType(TextField).first, 'Publish it');
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tap(find.bySemanticsLabel('Send'));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Publish it'), findsOneWidget); // user echo, still visible

    // Trickle: ~15 pre-approval events × 320ms of fake time.
    await _pumpFor(tester, const Duration(seconds: 6));
    expect(find.text('Publish the quarterly report?'), findsOneWidget);
    expect(find.text('search'), findsWidgets);

    // Approve → executed → artifact + surface results.
    await tester.tap(find.text('Approve'));
    await _pumpFor(tester, const Duration(seconds: 5));
    expect(find.textContaining('Report published', findRichText: true),
        findsOneWidget);
    expect(find.text('quarterly-report.md'), findsOneWidget);
    expect(find.text('Quarterly report'), findsOneWidget);
    expect(find.text(r'$420.00'), findsOneWidget);
    expect(find.text('Open report'), findsOneWidget);
  });
}
