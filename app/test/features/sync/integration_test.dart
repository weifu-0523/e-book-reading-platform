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

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/sync_record.dart';
import 'package:zhiyue/services/sync/sync_recorder.dart';
import 'package:zhiyue/services/sync/web_dav_client.dart';
import 'package:zhiyue/services/sync/web_dav_sync_engine.dart';

import '../../helpers/drift_test_helper.dart';

class _MockWebDavClient extends Mock implements WebDavClient {}

void main() {
  late AppDatabase dbA;
  late AppDatabase dbB;
  late _MockWebDavClient webdavA;
  late _MockWebDavClient webdavB;
  late WebDavSyncEngine engineA;
  late WebDavSyncEngine engineB;

  setUp(() async {
    dbA = createTestDatabase();
    dbB = createTestDatabase();
    webdavA = _MockWebDavClient();
    webdavB = _MockWebDavClient();
    engineA = WebDavSyncEngine(
      database: dbA,
      outbox: SyncOutboxDao(dbA),
      webdav: webdavA,
      deviceId: 'device-A',
      rateLimiterInterval: Duration.zero,
    );
    engineB = WebDavSyncEngine(
      database: dbB,
      outbox: SyncOutboxDao(dbB),
      webdav: webdavB,
      deviceId: 'device-B',
      rateLimiterInterval: Duration.zero,
    );
    registerFallbackValue(SyncRecordType.annotation);
  });
  tearDown(() async {
    await dbA.close();
    await dbB.close();
  });

  test('device A pushes annotation, device B pulls and sees it', () async {
    // 1. Seed dbA with FK + annotation row via direct SQL (mirrors what
    //    LocalNotesRepository.addAnnotation would write).
    await dbA.customInsert(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('b1'),
        Variable.withString('Book'),
        Variable.withString('epub'),
        Variable.withString('p'),
        Variable.withString('h'),
        Variable.withInt(0),
      ],
    );
    await dbA.customInsert(
      'INSERT INTO book_notes(id, book_id, title) VALUES(?, ?, ?)',
      variables: [
        Variable.withString('bn1'),
        Variable.withString('b1'),
        Variable.withString('Notes'),
      ],
    );
    await dbA.customInsert(
      'INSERT INTO annotations(id, book_note_id, locator, quote, color, tags, source, updated_at) VALUES(?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('a1'),
        Variable.withString('bn1'),
        Variable.withString('{}'),
        Variable.withString('highlight from A'),
        Variable.withString('yellow'),
        Variable.withString('[]'),
        Variable.withString('manual'),
        Variable.withDateTime(DateTime.utc(2026, 6, 28, 10)),
      ],
    );

    // 2. Enqueue via SyncRecorder (simulating the repo hook).
    final recorder = SyncRecorder(SyncOutboxDao(dbA));
    await recorder.recordAnnotation(
      id: 'a1',
      bookNoteId: 'bn1',
      locatorJson: '{}',
      quote: 'highlight from A',
      note: null,
      color: 'yellow',
      tagsJson: '[]',
      source: 'manual',
      mtime: DateTime.utc(2026, 6, 28, 10),
    );

    // 3. Simulate the cloud: device A's PUT body is captured, then served
    //    to device B's GET + listFiles.
    String? pushedBody;
    when(() => webdavA.getString(any())).thenAnswer((_) async => '');
    when(() => webdavA.putString(any(), any())).thenAnswer((inv) async {
      pushedBody = inv.positionalArguments[1] as String;
    });

    await engineA.pushOnly();
    expect(pushedBody, isNotNull);
    expect(pushedBody!, contains('"id":"a1"'));

    // 4. Device B sees only device-A.jsonl file; pulls it.
    //    Pre-seed dbB with parent rows: drift's in-memory DB enforces FK
    //    constraints, so the annotation INSERT inside the applier would
    //    otherwise fail (and pullOnly's catch-all swallows the error,
    //    yielding pulledCount=0). Mirror what device A wrote.
    await dbB.customInsert(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString('b1'),
        Variable.withString('Book'),
        Variable.withString('epub'),
        Variable.withString('p'),
        Variable.withString('h'),
        Variable.withInt(0),
      ],
    );
    await dbB.customInsert(
      'INSERT INTO book_notes(id, book_id, title) VALUES(?, ?, ?)',
      variables: [
        Variable.withString('bn1'),
        Variable.withString('b1'),
        Variable.withString('Notes'),
      ],
    );

    when(() => webdavB.listFiles('/zhiyue/snapshots/'))
        .thenAnswer((_) async => ['device-A.jsonl']);
    when(() => webdavB.getString('/zhiyue/snapshots/device-A.jsonl'))
        .thenAnswer((_) async => pushedBody!);
    when(() => webdavB.getString('/zhiyue/snapshots/device-B.jsonl'))
        .thenAnswer((_) async => '');

    final result = await engineB.pullOnly();
    expect(result.pulledCount, 1);

    // 5. Verify dbB has the annotation.
    final annotations = await dbB.customSelect(
      'SELECT quote FROM annotations WHERE id = ?',
      variables: [Variable.withString('a1')],
    ).get();
    expect(annotations, hasLength(1));
    expect(annotations.first.data['quote'], 'highlight from A');
  });
}
