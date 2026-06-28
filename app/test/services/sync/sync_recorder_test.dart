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
}
