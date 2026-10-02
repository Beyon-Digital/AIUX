import 'dart:convert';

import 'package:aiux_ffi/aiux_ffi.dart';
import 'package:test/test.dart';

Map<String, dynamic> _event(
        int seq, String type, Map<String, dynamic> payload) =>
    {
      'eventId': 'e$seq',
      'sessionId': 's-dart',
      'sequence': seq,
      'timestamp': '2026-01-01T00:00:0${seq}Z',
      'type': type,
      'payload': {'protocolVersion': '0.1', ...payload},
    };

Map<String, dynamic> _sessionCreated(int seq) =>
    _event(seq, 'session.created', {
      'session': {
        'id': 's-dart',
        'title': 'Dart FFI test',
        'createdAt': '2026-01-01T00:00:00Z'
      }
    });

/// A session bound to `s-dart` with its `session.created` already applied.
AiuxSession _session() {
  final session = AiuxSession.create(configJson: '{}');
  session.dispatch(jsonEncode(_sessionCreated(0)));
  return session;
}

void main() {
  test('library version is reachable', () {
    expect(AiuxSession.libraryVersion(), isNotEmpty);
  });

  test('create → snapshot → serialize → restore → reset', () {
    final session = _session();
    addTearDown(session.close);

    final snapshot = jsonDecode(session.snapshot()) as Map<String, dynamic>;
    expect(snapshot['protocolVersion'], '0.1');
    expect(snapshot['sessionId'], 's-dart');

    final serialized = session.serialize();
    final restored = AiuxSession.restore(serialized);
    addTearDown(restored.close);
    expect(restored.serialize(), serialized);

    session.reset();
    final cleared = jsonDecode(session.snapshot()) as Map<String, dynamic>;
    expect(cleared['messages'], isEmpty);
    expect(cleared['runs'], isEmpty);
  });

  test('dispatch returns the UniFFI-shaped report', () {
    final session = _session();
    addTearDown(session.close);

    final report =
        jsonDecode(session.dispatch(jsonEncode(_event(1, 'message.created', {
      'message': {
        'id': 'm1',
        'role': 'user',
        'parts': [
          {'id': 'p1', 'type': 'text', 'text': 'hi'}
        ],
      }
    })))) as Map<String, dynamic>;
    expect(report, {'applied': 1, 'duplicatesIgnored': 0, 'buffered': 0});

    final messages =
        (jsonDecode(session.snapshot()) as Map<String, dynamic>)['messages'];
    expect(messages, hasLength(1));
  });

  test('dispatch_batch applies an ordered array', () {
    final session = _session();
    addTearDown(session.close);

    final events = [
      _event(1, 'run.started', {
        'run': {
          'id': 'r1',
          'status': 'running',
          'startedAt': '2026-01-01T00:00:01Z'
        }
      }),
      _event(2, 'message.created', {
        'message': {
          'id': 'm1',
          'role': 'assistant',
          'parts': [
            {'id': 'p1', 'type': 'text', 'text': 'hi'}
          ],
        }
      }),
    ];
    final report = jsonDecode(session.dispatchBatch(jsonEncode(events)))
        as Map<String, dynamic>;
    expect(report['applied'], 2);
    expect((jsonDecode(session.snapshot()) as Map<String, dynamic>)['messages'],
        hasLength(1));
  });

  test('malformed JSON surfaces AiuxException with the native error', () {
    final session = _session();
    addTearDown(session.close);
    expect(
      () => session.dispatch('{nope'),
      throwsA(isA<AiuxException>()),
    );
  });
}
