import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/sync/conflict_sink.dart';
import 'package:zhiyue/services/sync/sync_record.dart';

void main() {
  group('NullConflictSink', () {
    test('record completes without throwing', () async {
      const sink = NullConflictSink();
      await expectLater(
        sink.record(
          recordId: 'a1',
          recordType: SyncRecordType.annotation,
          localMtime: DateTime.utc(2026, 6, 29),
          remoteMtime: DateTime.utc(2026, 6, 28),
          remoteDeviceId: 'device-B',
          remotePayload: const {'quote': 'foo'},
        ),
        completes,
      );
    });
  });

  group('ListConflictSink', () {
    test('appends each record to internal list', () async {
      final sink = ListConflictSink();
      await sink.record(
        recordId: 'a1',
        recordType: SyncRecordType.annotation,
        localMtime: DateTime.utc(2026, 6, 29),
        remoteMtime: DateTime.utc(2026, 6, 28),
        remoteDeviceId: 'device-B',
        remotePayload: const {'quote': 'foo'},
      );
      await sink.record(
        recordId: 'a2',
        recordType: SyncRecordType.bookNote,
        localMtime: DateTime.utc(2026, 6, 29),
        remoteMtime: DateTime.utc(2026, 6, 28),
        remoteDeviceId: 'device-C',
        remotePayload: const {'title': 'bar'},
      );
      expect(sink.records, hasLength(2));
      expect(sink.records.first.recordId, 'a1');
      expect(sink.records.last.recordId, 'a2');
    });
  });
}
