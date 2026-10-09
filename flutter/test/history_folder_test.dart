import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_client/data/local/rows.dart';
import 'package:hermes_client/data/models.dart';
import 'package:hermes_client/data/remote/dtos.dart';
import 'package:hermes_client/data/repository/history_folder.dart';

void main() {
  test('preserves local attachments across sync', () {
    const attachment = Attachment(
      id: 'a1',
      name: 'photo.png',
      mimeType: 'image/png',
      size: 12,
      uri: 'content://local/photo',
      kind: AttachmentKind.image,
    );
    final previous = [
      const LocalMessage(
        sessionId: 's',
        role: MessageRole.user,
        content: '看这个',
        attachments: [attachment],
      ),
    ];
    final data = [
      const ServerMessage(role: 'user', content: '看这个'),
      const ServerMessage(role: 'assistant', content: '好'),
    ];
    final entities = HistoryFolder.fold('s', data, previous: previous, now: 1);

    expect(entities[0].attachments.length, 1);
    expect(entities[0].attachments[0].uri, 'content://local/photo');
  });

  test('keeps slash command turn the server never persisted', () {
    final previous = [
      const LocalMessage(sessionId: 's', role: MessageRole.user, content: '/status'),
    ];
    final data = [
      const ServerMessage(role: 'user', content: 'hi'),
      const ServerMessage(role: 'assistant', content: 'hello'),
    ];
    final entities = HistoryFolder.fold('s', data, previous: previous, now: 1);

    // The server transcript (hi/hello) plus the local-only /status turn,
    // re-inserted in its original position.
    expect(entities.map((e) => e.content).toList(), ['/status', 'hi', 'hello']);
    expect(entities.map((e) => e.seq).toList(), [1, 2, 3]);
  });

  test('reuses local ids for unchanged messages', () {
    final previous = [
      const LocalMessage(id: 7, sessionId: 's', role: MessageRole.user, content: 'same', createdAt: 100),
      const LocalMessage(id: 8, sessionId: 's', role: MessageRole.assistant, content: 'reply', createdAt: 101),
    ];
    final data = [
      const ServerMessage(role: 'user', content: 'same'),
      const ServerMessage(role: 'assistant', content: 'reply'),
    ];
    final entities = HistoryFolder.fold('s', data, previous: previous, now: 1);

    expect(entities[0].id, 7);
    expect(entities[0].createdAt, 100);
    expect(entities[1].id, 8);
  });

  test('folds tool messages into segments with results', () {
    final data = [
      const ServerMessage(role: 'user', content: 'run it'),
      const ServerMessage(
        role: 'assistant',
        content: null,
        toolCalls: [
          {
            'id': 'call_1',
            'function': {'name': 'terminal', 'arguments': '{"cmd":"ls"}'},
          }
        ],
      ),
      const ServerMessage(role: 'tool', content: 'file.txt', toolCallId: 'call_1'),
      const ServerMessage(role: 'assistant', content: 'done'),
    ];
    final entities = HistoryFolder.fold('s', data, now: 1);

    expect(entities.length, 2); // user + single assistant turn
    final assistant = entities[1];
    expect(assistant.role, MessageRole.assistant);
    expect(assistant.content, 'done');
    // Two segments: tool-call-only, then the text answer.
    expect(assistant.segments.length, 2);
    expect(assistant.segments[0].tools.length, 1);
    expect(assistant.segments[0].tools[0].name, 'terminal');
    expect(assistant.segments[0].tools[0].preview, '{"cmd":"ls"}');
    expect(assistant.segments[0].tools[0].result, 'file.txt');
    expect(assistant.segments[0].tools[0].status, 'completed');
    expect(assistant.segments[1].text, 'done');
  });
}
