import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/sync/sync_record.dart';

void main() {
  group('SyncRecord', () {
    test('round-trip JSON preserves all fields', () {
      final record = SyncRecord(
        id: 'a1',
        type: SyncRecordType.annotation,
        mtime: DateTime.utc(2026, 6, 28, 10, 0, 0),
        deleted: false,
        payload: {'quote': '风险即未来', 'color': 'yellow'},
      );
      final json = jsonEncode(record.toJson());
      final restored = SyncRecord.fromJson(jsonDecode(json) as Map<String, dynamic>);
      expect(restored.id, 'a1');
      expect(restored.type, SyncRecordType.annotation);
      expect(restored.mtime, DateTime.utc(2026, 6, 28, 10, 0, 0));
      expect(restored.deleted, isFalse);
      expect(restored.payload['quote'], '风险即未来');
    });

    test('deleted record has empty payload', () {
      final record = SyncRecord.tombstone(
        id: 'a1',
        type: SyncRecordType.annotation,
        mtime: DateTime.utc(2026, 6, 28, 10, 0, 0),
      );
      expect(record.deleted, isTrue);
      expect(record.payload, isEmpty);
    });

    test('type serialization is stable string', () {
      for (final type in SyncRecordType.values) {
        final record = SyncRecord(
          id: 'x',
          type: type,
          mtime: DateTime.utc(2026, 1, 1),
          deleted: false,
          payload: const {},
        );
        final json = jsonEncode(record.toJson());
        expect(json, contains('"type":"${type.name}"'));
      }
    });
  });
}
