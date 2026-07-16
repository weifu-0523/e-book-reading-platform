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

// T27 (2026-07-17): end-to-end integration test for cross-device
// `lastTtsPosition` sync.
//
// Unlike `remote_record_applier_book_test.dart` (which feeds hand-crafted
// `SyncRecord` objects directly to the applier — unit-level coverage for
// the receiver side), this file drives the full pipeline:
//
//   device A: BooksDao.setLastTtsPosition
//          -> SyncRecorder.recordBook
//          -> SyncOutboxDao.getPending
//          -> JSON envelope (the "wire format")
//
//   wire:    SyncRecord.fromJson (mimics what WebDavSyncEngine.pullOnly
//            does per-line on the receiver)
//
//   device B: RemoteRecordApplier.apply
//          -> BooksDao.getLastTtsPosition
//
// All three test cases use the in-memory drift test database
// (`createTestDatabase`) for both devices — no real SQLite file, no
// WebDAV server. The "wire" is just a `jsonEncode` -> `jsonDecode` hop
// to exercise the round-trip codec.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/models/last_tts_position.dart';
import 'package:zhiyue/services/sync/conflict_sink.dart';
import 'package:zhiyue/services/sync/remote_record_applier.dart';
import 'package:zhiyue/services/sync/sync_record.dart';
import 'package:zhiyue/services/sync/sync_recorder.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late AppDatabase deviceA;
  late AppDatabase deviceB;
  late SyncOutboxDao outboxA;
  late SyncRecorder recorderA;
  late RemoteRecordApplier applierB;

  setUp(() async {
    deviceA = createTestDatabase();
    deviceB = createTestDatabase();
    outboxA = SyncOutboxDao(deviceA);
    recorderA = SyncRecorder(outboxA);
    applierB = RemoteRecordApplier(deviceB, conflictSink: ListConflictSink())
      ..currentRemoteDeviceId = 'device-A';
  });
  tearDown(() async {
    await deviceA.close();
    await deviceB.close();
  });

  // Both devices start with no books. Most tests need a row to exist on A
  // so BooksDao.setLastTtsPosition's UPDATE hits a row — insert it here.
  Future<void> seedBookOnA({
    String id = 'b-sync',
    String title = 'Sync Test',
  }) async {
    await deviceA.customInsert(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(id),
        Variable.withString(title),
        Variable.withString('epub'),
        Variable.withString('p'),
        Variable.withString('h'),
        Variable.withInt(0),
      ],
    );
  }

  // Reads device A's outbox, grabs the single pending record, decodes its
  // JSON envelope, and reconstructs a SyncRecord exactly as the receiver
  // (WebDavSyncEngine.pullOnly) would do per line. This is the "wire hop".
  Future<SyncRecord> popWireRecord() async {
    final pending = await outboxA.getPending();
    expect(pending, hasLength(1),
        reason: 'recorder.recordBook should enqueue exactly one record');
    final envelope =
        jsonDecode(pending.first.payloadJson) as Map<String, dynamic>;
    return SyncRecord.fromJson(envelope);
  }

  test('lastTtsPosition syncs from device A to device B', () async {
    await seedBookOnA();

    // device A: user reached chapter 3, sentence 421.
    const expected = LastTtsPosition(
      chapterIdx: 3,
      sentenceIdx: 421,
      updatedAt: 1737000000000,
    );
    final daoA = BooksDao(deviceA);
    await daoA.setLastTtsPosition('b-sync', expected);
    expect(await daoA.getLastTtsPosition('b-sync'), expected,
        reason: 'device A round-trip baseline');

    // device A: record-book write hits the sync outbox with the cursor
    // embedded in the payload (T11 wiring).
    await recorderA.recordBook(
      id: 'b-sync',
      title: 'Sync Test',
      author: null,
      format: 'epub',
      fileHash: 'h',
      fileSizeBytes: 0,
      hasCover: false,
      mtime: DateTime.utc(2026, 7, 17, 10),
      lastTtsPosition: expected,
    );

    // wire hop: JSON envelope in outbox → SyncRecord reconstructed on receiver.
    final wire = await popWireRecord();
    expect(wire.id, 'b-sync');
    expect(wire.type, SyncRecordType.book);
    expect(wire.payload['lastTtsPosition'], isA<Map>());
    expect(wire.payload['lastTtsPosition']['chapterIdx'], 3);

    // device B: apply the wire record. B has no row for this book yet, so
    // _applyBook performs an INSERT (not the skip branch).
    final applied = await applierB.apply(wire);
    expect(applied, true);

    // device B: read back the cursor via the same DAO API the TTS reader
    // controller will use to offer "resume from chapter N".
    final restored = await BooksDao(deviceB).getLastTtsPosition('b-sync');
    expect(restored, expected);
  });

  test('legacy record without lastTtsPosition does not crash', () async {
    await seedBookOnA();

    // device A: legacy snapshot — caller didn't supply the cursor (e.g.
    // pre-T11 build, or a write path that doesn't carry TTS state).
    await recorderA.recordBook(
      id: 'b-legacy',
      title: 'Legacy Snapshot',
      author: null,
      format: 'epub',
      fileHash: 'h2',
      fileSizeBytes: 0,
      hasCover: false,
      mtime: DateTime.utc(2026, 7, 17, 10),
      // lastTtsPosition intentionally omitted — exercises the "field
      // absent" branch of _sanitizeLastTtsPosition (vs. explicit null).
    );

    final wire = await popWireRecord();
    // The wire payload (sync_recorder.dart line 163) ALWAYS contains the
    // `lastTtsPosition` key — its value is null when the caller omitted the
    // param. This distinguishes "explicitly cleared" from "field absent" at
    // the protocol level (older pre-T11 clients), but the receiver maps both
    // shapes to a NULL column (see _sanitizeLastTtsPosition).
    expect(wire.payload['lastTtsPosition'], isNull);

    // device B: apply must succeed without throwing.
    final applied = await applierB.apply(wire);
    expect(applied, true);

    // Column stays NULL → "never read aloud".
    final restored = await BooksDao(deviceB).getLastTtsPosition('b-legacy');
    expect(restored, isNull);
  });

  // Test 3 variant: wire codec round-trip preserves lastTtsPosition.
  //
  // The prompt's preferred test 3 ("device B overwrites its own lastTtsPosition
  // when device A's mtime is newer") is not expressible given the applier's
  // documented semantics: `_applyBook` (remote_record_applier.dart:377-388)
  // short-circuits whenever a book row already exists on the receiver —
  // books have no `updated_at` column, so there's no per-field LWW gate.
  // Therefore any device-B book row blocks the apply regardless of mtime.
  //
  // The alternate prompt variant ("B preserves its own cursor when A's
  // payload lacks it") is also blocked by the same skip-on-existing branch:
  // if B already has the row + cursor, A's apply is a no-op, so trivially
  // "preserved" — but that's tautological and adds no signal.
  //
  // Picking instead a wire-codec round-trip test: confirms the JSON envelope
  // produced by device A's recorder survives jsonEncode/jsonDecode (mimicking
  // actual file-based transport via WebDAV) and the lastTtsPosition Map is
  // byte-identical to what the receiver would re-serialize to the column.
  // This complements test 1 (which goes through the full pipeline including
  // _applyBook) by isolating the JSON codec layer.
  test('wire envelope round-trips lastTtsPosition without loss', () async {
    await seedBookOnA();

    const original = LastTtsPosition(
      chapterIdx: 12,
      sentenceIdx: 7,
      updatedAt: 1737000000123,
    );
    await recorderA.recordBook(
      id: 'b-codec',
      title: 'Codec Test',
      author: 'tester',
      format: 'epub',
      fileHash: 'h3',
      fileSizeBytes: 4096,
      hasCover: true,
      mtime: DateTime.utc(2026, 7, 17, 11),
      lastTtsPosition: original,
    );

    // Simulate the actual wire transport: outbox JSON string →
    // re-encoded (the snapshot file is one JSON per line, so the line is
    // exactly `payloadJson`) → parsed back on the receiver.
    final pending = await outboxA.getPending();
    expect(pending, hasLength(1));
    final wireString = pending.first.payloadJson;

    // Re-encode then re-decode to mimic file write + file read.
    final reEncoded = jsonEncode(jsonDecode(wireString));
    final wire = SyncRecord.fromJson(
        jsonDecode(reEncoded) as Map<String, dynamic>);

    // The Map inside payload must equal the original model's toJson.
    expect(wire.payload['lastTtsPosition'], original.toJson());

    // And the receiver's sanitizer must accept it: re-applying produces
    // a row whose column, when read back through BooksDao, equals the
    // original model. This is the same assertion as test 1 but with the
    // extra round-trip stress on the wire encoding.
    await applierB.apply(wire);
    final restored = await BooksDao(deviceB).getLastTtsPosition('b-codec');
    expect(restored, original);
  });
}
