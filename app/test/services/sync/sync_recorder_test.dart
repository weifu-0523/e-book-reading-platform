import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/sync_recorder.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase db;
  late SyncOutboxDao outbox;
  late SyncRecorder recorder;

  setUp(() async {
    db = createTestDatabase();
    outbox = SyncOutboxDao(db);
    recorder = SyncRecorder(outbox);
  });
  tearDown(() async => db.close());

  test('recordAnnotation inserts outbox row with annotation payload', () async {
    await recorder.recordAnnotation(
      id: 'a1',
      bookNoteId: 'bn1',
      locatorJson: '{"type":"epubCfi","cfi":"x"}',
      quote: 'q',
      note: 'n',
      color: 'yellow',
      tagsJson: '["t"]',
      source: 'manual',
      deleted: false,
      mtime: DateTime.utc(2026, 6, 28, 10),
    );
    final pending = await outbox.getPending();
    expect(pending, hasLength(1));
    expect(pending.first.recordId, 'a1');
    expect(pending.first.recordType, 'annotation');
    expect(pending.first.payloadJson, contains('"quote":"q"'));
    expect(pending.first.payloadJson, contains('"bookNoteId":"bn1"'));
  });

  test('recordAnnotationDeletion enqueues tombstone', () async {
    await recorder.recordAnnotationDeletion(
      id: 'a1',
      mtime: DateTime.utc(2026, 6, 28, 10),
    );
    final pending = await outbox.getPending();
    expect(pending, hasLength(1));
    expect(pending.first.payloadJson, contains('"deleted":true'));
  });

  test('recordBookNote enqueues with summary + keyTakeaways', () async {
    await recorder.recordBookNote(
      id: 'bn1',
      bookId: 'b1',
      title: 'Book Notes',
      summary: 'A summary',
      keyTakeawaysJson: '["point1"]',
      mtime: DateTime.utc(2026, 6, 28, 10),
    );
    final pending = await outbox.getPending();
    expect(pending.first.recordType, 'bookNote');
    expect(pending.first.payloadJson, contains('"summary":"A summary"'));
  });

  test('recordReadingProgress enqueues locator + percent', () async {
    await recorder.recordReadingProgress(
      bookId: 'b1',
      locatorJson: '{"cfi":"x"}',
      percent: 0.42,
      mtime: DateTime.utc(2026, 6, 28, 10),
    );
    final pending = await outbox.getPending();
    expect(pending.first.recordId, 'b1');
    expect(pending.first.recordType, 'readingProgress');
    expect(pending.first.payloadJson, contains('"percent":0.42'));
  });

  test('recordBook enqueues book metadata', () async {
    await recorder.recordBook(
      id: 'b1',
      title: 'Title',
      author: 'Auth',
      format: 'epub',
      fileHash: 'h',
      fileSizeBytes: 1024,
      coverPath: '/covers/b1.png',
      mtime: DateTime.utc(2026, 6, 28, 10),
    );
    final pending = await outbox.getPending();
    expect(pending.first.recordType, 'book');
    expect(pending.first.payloadJson, contains('"title":"Title"'));
  });

  // M2.8 (2026-07-12): chat + tags sync scope expansion.

  test('recordChatSession enqueues chatSession type with payload', () async {
    await recorder.recordChatSession(
      id: 's1',
      bookId: 'b1',
      title: 'Chapter 1 Q&A',
      mode: 'normal',
      createdAt: DateTime.utc(2026, 7, 12, 10),
      updatedAt: DateTime.utc(2026, 7, 12, 11),
    );
    final pending = await outbox.getPending();
    expect(pending, hasLength(1));
    expect(pending.first.recordId, 's1');
    expect(pending.first.recordType, 'chatSession');
    final envelope =
        jsonDecode(pending.first.payloadJson) as Map<String, dynamic>;
    expect(envelope['type'], 'chatSession');
    expect(envelope['deleted'], false);
    expect(envelope['mtime'], '2026-07-12T11:00:00.000Z');
    final payload = envelope['payload'] as Map<String, dynamic>;
    expect(payload['bookId'], 'b1');
    expect(payload['title'], 'Chapter 1 Q&A');
    expect(payload['mode'], 'normal');
    expect(payload['createdAt'], '2026-07-12T10:00:00.000Z');
    expect(payload['deletedAt'], isNull);
  });

  test('recordChatSession with deletedAt carries soft-delete marker', () async {
    await recorder.recordChatSession(
      id: 's2',
      bookId: 'b1',
      title: 'stale',
      mode: 'normal',
      createdAt: DateTime.utc(2026, 7, 12, 10),
      updatedAt: DateTime.utc(2026, 7, 12, 11),
      deletedAt: DateTime.utc(2026, 7, 12, 12),
    );
    final pending = await outbox.getPending();
    final envelope =
        jsonDecode(pending.first.payloadJson) as Map<String, dynamic>;
    // Tombstone flag is NOT set — soft-delete lives in payload.deletedAt so
    // conflict resolution can compare timestamps even on deleted rows.
    expect(envelope['deleted'], false);
    final payload = envelope['payload'] as Map<String, dynamic>;
    expect(payload['deletedAt'], '2026-07-12T12:00:00.000Z');
  });

  test('recordChatMessage enqueues chatMessage type with full content', () async {
    await recorder.recordChatMessage(
      id: 'm1',
      sessionId: 's1',
      role: 'assistant',
      content: 'full accumulated content',
      presetSource: 'summarize',
      attachmentNoteId: 'n1',
      attachmentNoteSnapshot: 'snapshot text',
      createdAt: DateTime.utc(2026, 7, 12, 10),
      updatedAt: DateTime.utc(2026, 7, 12, 11),
    );
    final pending = await outbox.getPending();
    expect(pending, hasLength(1));
    expect(pending.first.recordId, 'm1');
    expect(pending.first.recordType, 'chatMessage');
    final envelope =
        jsonDecode(pending.first.payloadJson) as Map<String, dynamic>;
    expect(envelope['type'], 'chatMessage');
    expect(envelope['mtime'], '2026-07-12T11:00:00.000Z');
    final payload = envelope['payload'] as Map<String, dynamic>;
    expect(payload['sessionId'], 's1');
    expect(payload['role'], 'assistant');
    expect(payload['content'], 'full accumulated content');
    expect(payload['presetSource'], 'summarize');
    expect(payload['attachmentNoteId'], 'n1');
    expect(payload['attachmentNoteSnapshot'], 'snapshot text');
    expect(payload['createdAt'], '2026-07-12T10:00:00.000Z');
    expect(payload['deletedAt'], isNull);
  });

  test('recordChatMessage omits null optional fields from payload', () async {
    await recorder.recordChatMessage(
      id: 'm2',
      sessionId: 's1',
      role: 'user',
      content: 'hi',
      presetSource: null,
      attachmentNoteId: null,
      attachmentNoteSnapshot: null,
      createdAt: DateTime.utc(2026, 7, 12, 10),
      updatedAt: DateTime.utc(2026, 7, 12, 11),
    );
    final pending = await outbox.getPending();
    final envelope =
        jsonDecode(pending.first.payloadJson) as Map<String, dynamic>;
    final payload = envelope['payload'] as Map<String, dynamic>;
    expect(payload['presetSource'], isNull);
    expect(payload['attachmentNoteId'], isNull);
    expect(payload['attachmentNoteSnapshot'], isNull);
  });

  test('recordBookTag enqueues composite-id bookTag record', () async {
    await recorder.recordBookTag(bookId: 'b1', tag: '哲学');
    final pending = await outbox.getPending();
    expect(pending, hasLength(1));
    expect(pending.first.recordId, 'b1__哲学');
    expect(pending.first.recordType, 'bookTag');
    final envelope =
        jsonDecode(pending.first.payloadJson) as Map<String, dynamic>;
    expect(envelope['type'], 'bookTag');
    expect(envelope['deleted'], false);
    final payload = envelope['payload'] as Map<String, dynamic>;
    expect(payload['bookId'], 'b1');
    expect(payload['tag'], '哲学');
  });

  test('recordBookTagDeletion enqueues tombstone with same composite id', () async {
    await recorder.recordBookTagDeletion(bookId: 'b1', tag: '哲学');
    final pending = await outbox.getPending();
    expect(pending, hasLength(1));
    expect(pending.first.recordId, 'b1__哲学');
    expect(pending.first.recordType, 'bookTag');
    final envelope =
        jsonDecode(pending.first.payloadJson) as Map<String, dynamic>;
    expect(envelope['type'], 'bookTag');
    expect(envelope['deleted'], true);
    expect(envelope['payload'], isEmpty);
  });
}
