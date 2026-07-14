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
