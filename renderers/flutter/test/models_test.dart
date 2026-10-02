import 'dart:convert';
import 'dart:io';

import 'package:beyond_aiux/beyond_aiux.dart';
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

void main() {
  final repo = _repoDir();

  group('AiuxPersistedEnvelope', () {
    test('decodes every conformance expected file', () {
      final expectedDir = Directory('${repo.path}/conformance/expected');
      final files = expectedDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'));
      expect(files, isNotEmpty);
      for (final file in files) {
        final envelope =
            AiuxPersistedEnvelope.fromJson(jsonDecode(file.readAsStringSync()));
        expect(envelope.protocolVersion, '0.1', reason: file.path);
        expect(envelope.nextExpectedSequence, greaterThanOrEqualTo(0),
            reason: file.path);
      }
    });

    test('exposes the state body as a snapshot-shaped map', () {
      final file =
          File('${repo.path}/conformance/expected/basic-response.json');
      final envelope =
          AiuxPersistedEnvelope.fromJson(jsonDecode(file.readAsStringSync()));
      final snapshot = envelope.snapshot;
      expect(snapshot.messages, hasLength(2));
      expect(snapshot.messages.first.role, AiuxMessageRole.user);
    });
  });

  group('AiuxSnapshot decode', () {
    test('tolerates empty and sparse payloads', () {
      final empty = AiuxSnapshot.fromJson(const {});
      expect(empty.messages, isEmpty);
      expect(empty.tools, isEmpty);
      expect(empty.session, isNull);
      final sparse = AiuxSnapshot.fromJson(jsonDecode(
          '{"protocolVersion":"0.1","sessionId":"s1","messages":[{"id":"m1","role":"user"}]}'));
      expect(sparse.sessionId, 's1');
      expect(sparse.messages.single.parts, isEmpty);
      expect(sparse.messages.single.status, isNull);
    });

    test('decodes every part kind and degrades unknown kinds', () {
      AiuxPart decode(Map<String, dynamic> j) => AiuxPart.fromJson(j);
      expect(decode({'id': 'p', 'type': 'text', 'text': 'x'}),
          isA<AiuxTextPart>());
      expect(decode({'id': 'p', 'type': 'markdown', 'markdown': 'x'}),
          isA<AiuxMarkdownPart>());
      expect(decode({'id': 'p', 'type': 'code', 'code': 'x'}),
          isA<AiuxCodePart>());
      expect(decode({'id': 'p', 'type': 'image', 'attachment': {}}),
          isA<AiuxImagePart>());
      expect(decode({'id': 'p', 'type': 'attachment', 'attachment': {}}),
          isA<AiuxAttachmentPart>());
      expect(decode({'id': 'p', 'type': 'citation', 'citation': {}}),
          isA<AiuxCitationPart>());
      expect(decode({'id': 'p', 'type': 'tool', 'toolId': 't'}),
          isA<AiuxToolPart>());
      expect(decode({'id': 'p', 'type': 'approval', 'approvalId': 'a'}),
          isA<AiuxApprovalPart>());
      expect(decode({'id': 'p', 'type': 'artifact', 'artifactId': 'a'}),
          isA<AiuxArtifactPart>());
      expect(decode({'id': 'p', 'type': 'status', 'text': 'x'}),
          isA<AiuxStatusPart>());
      expect(decode({'id': 'p', 'type': 'progress', 'progress': {}}),
          isA<AiuxProgressPart>());
      expect(decode({'id': 'p', 'type': 'surface', 'surfaceId': 's'}),
          isA<AiuxSurfacePart>());
      expect(decode({'id': 'p', 'type': 'error', 'error': {}}),
          isA<AiuxErrorPart>());
      expect(decode({'id': 'p', 'type': 'hologram'}), isA<AiuxUnknownPart>());
      // `type` missing entirely still degrades rather than throwing.
      expect(decode({'id': 'p'}), isA<AiuxUnknownPart>());
    });
  });

  group('AiuxRenderModel', () {
    test('indexes entities by id', () {
      final snapshot = AiuxSnapshot.fromJson(jsonDecode(
          '{"messages":[{"id":"m1","role":"assistant","status":"streaming"}],'
          '"tools":[{"id":"t1","name":"search","status":"running"}],'
          '"approvals":[{"id":"a1","prompt":"ok?","status":"requested"}],'
          '"artifacts":[{"id":"x1","kind":"code","revision":1}],'
          '"surfaces":[{"id":"s1","revision":2,"root":{"type":"text","text":"hi"}}]}'));
      final model = AiuxRenderModel(snapshot: snapshot);
      expect(model.tool('t1')!.name, 'search');
      expect(model.approval('a1')!.prompt, 'ok?');
      expect(model.artifact('x1')!.revision, 1);
      expect(model.surface('s1')!.revision, 2);
      expect(model.tool('nope'), isNull);
      expect(model.streamingMessage!.id, 'm1');
      expect(model.hasPendingApproval, isTrue);
    });
  });

  group('AiuxAction', () {
    test('canonical ids match the protocol contract', () {
      expect(AiuxAction.composerSend, 'aiux.composer.send');
      expect(AiuxAction.approvalResolve, 'aiux.approval.resolve');
      expect(AiuxAction.citationOpen, 'aiux.citation.open');
      expect(AiuxAction.contextRemove, 'aiux.context.remove');
      expect(AiuxAction.fieldChange, 'aiux.field.change');
    });

    test('round-trips through JSON', () {
      const action =
          AiuxAction(id: AiuxAction.composerSend, payload: {'text': 'hi'});
      expect(AiuxAction.fromJson(action.toJson()).id, AiuxAction.composerSend);
      expect(action.toJson()['payload']['text'], 'hi');
    });
  });

  group('AiuxFixture / catalog', () {
    test('loads every fixture from conformance/fixtures', () {
      final dir = Directory('${repo.path}/conformance/fixtures');
      final names = AiuxFixtureCatalog.manifest(dir);
      expect(names.length, greaterThanOrEqualTo(20));
      final fixtures = AiuxFixtureCatalog.loadAll(dir);
      for (final fixture in fixtures) {
        expect(fixture.events, isNotEmpty, reason: fixture.name);
        // Every event encodes to a JSON object with an eventId.
        for (final eventJson in fixture.events) {
          expect((jsonDecode(eventJson) as Map)['eventId'], isA<String>(),
              reason: fixture.name);
        }
      }
    });
  });
}
