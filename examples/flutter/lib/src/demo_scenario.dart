import 'dart:convert';

import 'package:beyond_aiux/beyond_aiux.dart';

// MARK: - Mocked agent scenario (Phase 7 demo — port of the iOS example)
//
// `DemoScenario` authors protocol events for the scripted interaction:
//   user prompt → streaming assistant text → tool start → tool progress →
//   tool finish → approval request → (user approve) → approval executed →
//   markdown + artifact + surface results.
//
// Events are ordinary protocol JSON envelopes, fabricated client-side with
// monotonically increasing `sequence` — exactly what a remote agent stream
// would send.

/// Builds protocol event envelopes for the demo session.
class DemoEventFactory {
  DemoEventFactory({required this.sessionId});

  final String sessionId;
  int _sequence = 0;

  /// The next event envelope as compact JSON.
  String event(String type, Map<String, dynamic> payload) {
    final sequence = _sequence++;
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
            1767225600000 + sequence * 1000,
            isUtc: true)
        .toIso8601String();
    return jsonEncode({
      'eventId': 'demo-$sequence',
      'sessionId': sessionId,
      'sequence': sequence,
      'timestamp': timestamp,
      'type': type,
      'protocolVersion': aiuxProtocolVersion,
      'payload': payload,
    });
  }

  /// The protocol version stamped on payloads.
  String get pv => aiuxProtocolVersion;
}

/// The scripted agent interaction.
abstract final class DemoScenario {
  static const sessionId = 'demo';

  /// `session.created` — establishes the session + context entities so the
  /// context bar renders from the first frame.
  static String sessionCreated(DemoEventFactory factory) =>
      factory.event('session.created', {
        'protocolVersion': factory.pv,
        'session': {
          'id': sessionId,
          'title': 'AIUX demo',
          'createdAt': '2026-01-02T00:00:00Z',
          'context': [
            {
              'id': 'ctx-file',
              'kind': 'file',
              'label': 'report-draft.md',
              'uri': 'aiux://files/report-draft',
            },
            {
              'id': 'ctx-doc',
              'kind': 'url',
              'label': 'AIUX spec',
              'uri': 'https://docs.beyondigital.in/aiux',
            },
          ],
        },
      });

  /// The user message echo for a prompt.
  static String userMessage(
          DemoEventFactory factory, String messageId, String text) =>
      factory.event('message.created', {
        'protocolVersion': factory.pv,
        'message': {
          'id': messageId,
          'role': 'user',
          'parts': [
            {'id': '$messageId-p0', 'type': 'text', 'text': text},
          ],
        },
      });

  /// Events the agent streams *before* the approval request — run start,
  /// streaming text, tool lifecycle, then the `approval.requested` with its
  /// in-message `approval` part.
  static List<String> preApprovalEvents(DemoEventFactory factory, int turn) {
    final runId = 'r$turn';
    final messageId = 'm-agent-$turn';
    final toolId = 't$turn';
    final approvalId = 'a$turn';
    final events = <String>[];

    events.add(factory.event('run.started', {
      'protocolVersion': factory.pv,
      'run': {
        'id': runId,
        'status': 'running',
        'startedAt': '2026-01-02T00:00:01Z',
      },
    }));
    events.add(factory.event('message.created', {
      'protocolVersion': factory.pv,
      'message': {'id': messageId, 'role': 'assistant', 'status': 'streaming'},
    }));
    events.add(factory.event('part.added', {
      'protocolVersion': factory.pv,
      'messageId': messageId,
      'part': {'id': '$messageId-text', 'type': 'text', 'text': ''},
    }));
    for (final chunk in [
      'Searching ',
      'your workspace ',
      'for the ',
      'report…'
    ]) {
      events.add(factory.event('text.delta', {
        'protocolVersion': factory.pv,
        'messageId': messageId,
        'partId': '$messageId-text',
        'delta': chunk,
      }));
    }
    events.add(factory.event('part.added', {
      'protocolVersion': factory.pv,
      'messageId': messageId,
      'part': {'id': '$messageId-tool', 'type': 'tool', 'toolId': toolId},
    }));
    events.add(factory.event('tool.started', {
      'protocolVersion': factory.pv,
      'tool': {
        'id': toolId,
        'name': 'search',
        'status': 'running',
        'input': {'q': 'quarterly report'},
      },
    }));
    events.add(factory.event('tool.progress', {
      'protocolVersion': factory.pv,
      'toolId': toolId,
      'progress': {'current': 1, 'total': 3, 'label': 'querying'},
    }));
    events.add(factory.event('tool.progress', {
      'protocolVersion': factory.pv,
      'toolId': toolId,
      'progress': {'current': 3, 'total': 3, 'label': 'ranking'},
    }));
    events.add(factory.event('tool.completed', {
      'protocolVersion': factory.pv,
      'toolId': toolId,
      'result': {'hits': 3},
    }));
    events.add(factory.event('part.added', {
      'protocolVersion': factory.pv,
      'messageId': messageId,
      'part': {
        'id': '$messageId-approval',
        'type': 'approval',
        'approvalId': approvalId,
      },
    }));
    events.add(factory.event('approval.requested', {
      'protocolVersion': factory.pv,
      'approval': {
        'id': approvalId,
        'prompt': 'Publish the quarterly report?',
        'description':
            'Creates the report artifact and posts the summary card.',
        'status': 'requested',
        'expiresAt': '2026-01-02T01:00:00Z',
        'action': {
          'id': 'report.publish',
          'payload': {'reportId': 'rpt-$turn'},
        },
      },
    }));
    return events;
  }

  /// Events after the approval resolves — branches on the decision:
  /// approved → executed → markdown + artifact + surface result;
  /// rejected → rejected status + polite wrap-up.
  static List<String> postApprovalEvents(
      DemoEventFactory factory, int turn, bool approved) {
    final runId = 'r$turn';
    final messageId = 'm-agent-$turn';
    final approvalId = 'a$turn';
    final events = <String>[];

    events.add(factory.event('approval.resolved', {
      'protocolVersion': factory.pv,
      'approvalId': approvalId,
      'resolution': {
        'decision': approved ? 'approved' : 'rejected',
        'resolvedBy': 'user',
        'resolvedAt': '2026-01-02T00:00:20Z',
      },
    }));

    if (!approved) {
      events.add(factory.event('part.added', {
        'protocolVersion': factory.pv,
        'messageId': messageId,
        'part': {
          'id': '$messageId-note',
          'type': 'status',
          'text': 'Publication cancelled.',
          'level': 'warning',
        },
      }));
      events.add(factory.event('message.updated', {
        'protocolVersion': factory.pv,
        'messageId': messageId,
        'status': 'complete',
      }));
      events.add(factory.event('run.completed', {
        'protocolVersion': factory.pv,
        'runId': runId,
      }));
      return events;
    }

    events.add(factory.event('approval.resolved', {
      'protocolVersion': factory.pv,
      'approvalId': approvalId,
      'resolution': {
        'decision': 'executed',
        'resolvedBy': 'host',
        'resolvedAt': '2026-01-02T00:00:25Z',
      },
    }));
    events.add(factory.event('part.added', {
      'protocolVersion': factory.pv,
      'messageId': messageId,
      'part': {
        'id': '$messageId-result',
        'type': 'markdown',
        'markdown': '**Report published.** Summary card below.',
      },
    }));
    events.add(factory.event('artifact.created', {
      'protocolVersion': factory.pv,
      'artifact': {
        'id': 'art-$turn',
        'kind': 'document',
        'title': 'quarterly-report.md',
        'revision': 0,
        'content':
            '# Quarterly report\n\n- Revenue: \$420.00\n- Status: published\n',
      },
    }));
    events.add(factory.event('part.added', {
      'protocolVersion': factory.pv,
      'messageId': messageId,
      'part': {
        'id': '$messageId-artifact',
        'type': 'artifact',
        'artifactId': 'art-$turn',
      },
    }));
    events.add(factory.event('surface.created', {
      'protocolVersion': factory.pv,
      'surface': {
        'id': 'sf-$turn',
        'name': 'report-card',
        'revision': 0,
        'root': {
          'type': 'surface',
          'gap': 'sm',
          'children': [
            {'type': 'heading', 'text': 'Quarterly report', 'level': 2},
            {
              'type': 'keyValue',
              'items': [
                {'key': 'Total', 'value': r'$420.00'},
                {'key': 'Status', 'value': 'published'},
              ],
            },
            {
              'type': 'status',
              'text': 'Published to workspace',
              'tone': 'success',
            },
            {
              'type': 'actions',
              'children': [
                {
                  'type': 'button',
                  'label': 'Open report',
                  'variant': 'primary',
                  'action': {
                    'id': 'report.open',
                    'payload': {'reportId': 'rpt-$turn'},
                  },
                },
                {
                  'type': 'button',
                  'label': 'Share',
                  'variant': 'secondary',
                  'action': {
                    'id': 'report.share',
                    'payload': {'reportId': 'rpt-$turn'},
                  },
                },
              ],
            },
          ],
        },
      },
    }));
    events.add(factory.event('part.added', {
      'protocolVersion': factory.pv,
      'messageId': messageId,
      'part': {
        'id': '$messageId-surface',
        'type': 'surface',
        'surfaceId': 'sf-$turn',
      },
    }));
    events.add(factory.event('message.updated', {
      'protocolVersion': factory.pv,
      'messageId': messageId,
      'status': 'complete',
    }));
    events.add(factory.event('run.completed', {
      'protocolVersion': factory.pv,
      'runId': runId,
      'result': {'published': true},
    }));
    return events;
  }

  /// Cancellation events when the user stops a running turn.
  static List<String> cancelEvents(DemoEventFactory factory, int turn) {
    final runId = 'r$turn';
    final messageId = 'm-agent-$turn';
    return [
      factory.event('run.cancelled', {
        'protocolVersion': factory.pv,
        'runId': runId,
        'reason': 'user pressed stop',
      }),
      factory.event('message.updated', {
        'protocolVersion': factory.pv,
        'messageId': messageId,
        'status': 'cancelled',
      }),
    ];
  }
}
