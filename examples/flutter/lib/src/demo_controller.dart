import 'dart:async';

import 'package:beyond_aiux/beyond_aiux.dart';
import 'package:flutter/foundation.dart';

import 'demo_scenario.dart';

// MARK: - Demo controller (the "host" + mocked agent)
//
// `DemoController` plays both sides of the demo:
//   host side   — owns the `AiuxSessionStore`, receives `AiuxAction`s from
//                 views and turns them into protocol events (a real host
//                 would forward them to its agent).
//   agent side  — the mock: answers `aiux.composer.send` with the scripted
//                 stream, holds at `approval.requested`, and resolves when
//                 `aiux.approval.resolve` arrives.
//
// Events trickle in with small delays so streaming/progress states are
// actually visible in the UI.

/// Host + mocked agent driving an [AiuxSessionStore].
class DemoController extends ChangeNotifier {
  DemoController({required this.store});

  /// The session store the views bind to.
  final AiuxSessionStore store;

  /// Running agent transcript — surfaced in the UI for inspection.
  final List<String> log = [];

  final DemoEventFactory _factory =
      DemoEventFactory(sessionId: DemoScenario.sessionId);
  int _turn = 0;
  Completer<bool>? _approvalGate;
  bool _waitingForApproval = false;
  bool _turnCancelled = false;
  bool _runActive = false;

  /// A decision tapped before the gate was installed — consumed on arrival.
  bool? _queuedDecision;

  /// Build a controller over a real FFI session; falls back to a
  /// fail-loud backend so the UI shows the error instead of crashing.
  factory DemoController.bootstrap({String configJson = '{}'}) {
    AiuxSessionBackend backend;
    try {
      backend = AiuxFfiBackend.create(configJson: configJson);
    } catch (e) {
      backend = FailingBackend(error: e);
    }
    return DemoController(store: AiuxSessionStore(backend: backend));
  }

  /// Emit the session bootstrap. Call once when the UI mounts.
  void start() {
    if (store.snapshot.session != null) return;
    try {
      store.ingestEvent(DemoScenario.sessionCreated(_factory));
    } catch (e) {
      _record('session.created failed: $e');
    }
  }

  // MARK: Action handling — the host's job

  /// Route a semantic action emitted by a view. The renderer produced it;
  /// this host decides what it means (PLAN §1, §23).
  void handle(AiuxAction action) {
    switch (action.id) {
      case AiuxAction.composerSend:
        final text = (action.payload['text'] as String?) ?? '';
        if (text.isEmpty) return;
        _sendPrompt(text);
      case AiuxAction.composerCancel:
        _cancelActiveTurn();
      case AiuxAction.approvalResolve:
        _resolveApproval(action.payload['decision'] == 'approved');
      case AiuxAction.composerAttach:
        _record('attach requested — host picker hook');
      case AiuxAction.contextAdd:
        _record('context add requested — host picker hook');
      case AiuxAction.contextRemove:
        _record('context remove: ${action.payload['entityId'] ?? '?'}');
      case AiuxAction.errorRetry:
        _record('retry requested: ${action.payload['code'] ?? ''}');
      default:
        // Host-defined actions (e.g. report.open, report.share) and open
        // requests land here — a real app routes them to navigation.
        final keys = action.payload.keys.toList()..sort();
        _record('action ${action.id} [${keys.join(',')}]');
    }
  }

  // MARK: Agent script

  /// User sent a prompt → echo the message, then stream the mocked turn.
  void _sendPrompt(String text) {
    if (_runActive) {
      _record('busy — run already active');
      return;
    }
    _turn++;
    final turn = _turn;
    _record('you: $text');
    try {
      store.ingestBatch(
          '[${DemoScenario.userMessage(_factory, 'm-user-$turn', text)}]');
    } catch (e) {
      _record('user message failed: $e');
      return;
    }

    _runActive = true;
    _turnCancelled = false;
    _waitingForApproval = true;
    unawaited(_runTurn(turn));
  }

  Future<void> _runTurn(int turn) async {
    // Pull envelopes lazily: each event's sequence number is consumed on
    // moveNext(), so checking cancellation first keeps cancelEvents
    // contiguous with what was actually dispatched.
    final pre = DemoScenario.preApprovalEvents(_factory, turn).iterator;
    while (!_turnCancelled && pre.moveNext()) {
      await _dispatchTrickle(pre.current);
    }
    if (_turnCancelled) return;
    // Hold for the approval decision.
    final approved = await _waitForApproval();
    final post =
        DemoScenario.postApprovalEvents(_factory, turn, approved).iterator;
    while (!_turnCancelled && post.moveNext()) {
      await _dispatchTrickle(post.current);
    }
    _runActive = false;
  }

  Future<bool> _waitForApproval() {
    final queued = _queuedDecision;
    if (queued != null) {
      _queuedDecision = null;
      _waitingForApproval = false;
      return Future.value(queued);
    }
    _approvalGate = Completer<bool>();
    return _approvalGate!.future;
  }

  void _cancelActiveTurn() {
    if (!_runActive) return;
    _turnCancelled = true;
    _approvalGate?.complete(false);
    _approvalGate = null;
    _waitingForApproval = false;
    _queuedDecision = null;
    _runActive = false;
    try {
      store.ingestBatch(
          '[${DemoScenario.cancelEvents(_factory, _turn).join(',')}]');
    } catch (e) {
      _record('cancel events failed: $e');
    }
    _record('run cancelled');
  }

  /// Resolve the pending approval and let the script continue.
  void _resolveApproval(bool approved) {
    if (!_waitingForApproval) {
      _record('approval resolve ignored — nothing pending');
      return;
    }
    _waitingForApproval = false;
    if (_approvalGate != null) {
      _approvalGate!.complete(approved);
      _approvalGate = null;
    } else {
      _queuedDecision = approved;
      _waitingForApproval = true;
    }
    _record(approved ? 'approval: approved' : 'approval: rejected');
  }

  Future<void> _dispatchTrickle(String eventJson) async {
    try {
      store.ingestEvent(eventJson);
    } catch (e) {
      _record('dispatch failed: $e');
    }
    // A short pause between events so streaming/progress states are visible.
    await Future<void>.delayed(const Duration(milliseconds: 320));
  }

  void _record(String line) {
    log.add(line);
    if (log.length > 200) log.removeRange(0, log.length - 200);
    notifyListeners();
  }
}

/// A backend that always fails — only used when FFI creation itself fails,
/// so the UI surfaces the store error instead of crashing at boot.
class FailingBackend implements AiuxSessionBackend {
  FailingBackend({required this.error});
  final Object error;

  @override
  String dispatch(String eventJson) => throw error;
  @override
  String dispatchBatch(String eventsJson) => throw error;
  @override
  String snapshot() => throw error;
  @override
  String serialize() => throw error;
  @override
  void reset() => throw error;
}
