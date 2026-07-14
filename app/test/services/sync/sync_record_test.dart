// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
        payload: const {'quote': '风险即未来', 'color': 'yellow'},
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

    // M2.8 (2026-07-12): chat + tags sync scope expansion.
    test('SyncRecordType includes M2.8 types', () {
      expect(SyncRecordType.values, contains(SyncRecordType.chatSession));
      expect(SyncRecordType.values, contains(SyncRecordType.chatMessage));
      expect(SyncRecordType.values, contains(SyncRecordType.bookTag));
    });

    test('SyncRecord.fromJson throws FormatException for unknown type', () {
      final json = <String, dynamic>{
        'id': 'x',
        'type': 'futureUnknownType',
        'mtime': '2026-07-12T00:00:00.000Z',
        'deleted': false,
        'payload': <String, dynamic>{},
      };
      expect(() => SyncRecord.fromJson(json), throwsA(isA<FormatException>()));
    });
  });
}
