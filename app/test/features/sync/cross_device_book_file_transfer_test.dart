// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// M2.8 T12: end-to-end integration test for cross-device book binary
// transfer. Verifies the user story: "I imported a book on device A, sync,
// then on device B I see the book and can download its binary to read it."
//
// Strategy: simulate the WebDAV cloud as in-memory buffers (metadata
// snapshot body + bytes for the binary file). Device A pushes metadata +
// uploads the binary via BookFileSyncService.uploadPendingFiles; device B
// pulls metadata (file_path becomes '__needs_download__' sentinel), then
// downloads the binary via BookFileSyncService.downloadBookFile.
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zhiyue/data/local/daos/sync_outbox_dao.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/book_file_sync_service.dart';
import 'package:zhiyue/services/sync/sync_recorder.dart';
import 'package:zhiyue/services/sync/sync_record.dart';
import 'package:zhiyue/services/sync/web_dav_client.dart';
import 'package:zhiyue/services/sync/web_dav_sync_engine.dart';

import '../../helpers/drift_test_helper.dart';

class _MockWebDavClient extends Mock implements WebDavClient {}

void main() {
  late AppDatabase dbA;
  late AppDatabase dbB;
  late _MockWebDavClient webdavA;
  late _MockWebDavClient webdavB;
  late Directory tmpDir;
  late String dirA;
  late String dirB;
  late WebDavSyncEngine engineA;
  late WebDavSyncEngine engineB;
  late BookFileSyncService fileSyncA;
  late BookFileSyncService fileSyncB;

  setUp(() async {
    dbA = createTestDatabase();
    dbB = createTestDatabase();
    webdavA = _MockWebDavClient();
    webdavB = _MockWebDavClient();
    tmpDir = await Directory.systemTemp.createTemp('zhiyue_m28_book_xfer_');
    dirA = '${tmpDir.path}/a';
    dirB = '${tmpDir.path}/b';
    await Directory(dirA).create();
    await Directory(dirB).create();
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
    fileSyncA = BookFileSyncService(
      database: dbA,
      webdav: webdavA,
      localFilesDir: dirA,
    );
    fileSyncB = BookFileSyncService(
      database: dbB,
      webdav: webdavB,
      localFilesDir: dirB,
    );
    registerFallbackValue(SyncRecordType.annotation);
    // T2 (2026-07-13): uploadBookFile calls ensureAncestors before putBytes;
    // deleteRemoteFile calls delete for both binary + cover. Without these
    // stubs mocktail returns null which throws
    // `type 'Null' is not a subtype of type 'Future<void>'`.
    when(() => webdavA.ensureAncestors(any())).thenAnswer((_) async {});
    when(() => webdavB.ensureAncestors(any())).thenAnswer((_) async {});
    when(() => webdavA.delete(any())).thenAnswer((_) async {});
    when(() => webdavB.delete(any())).thenAnswer((_) async {});
  });
  tearDown(() async {
    await dbA.close();
    await dbB.close();
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  test(
      'cross-device book file transfer: A uploads, B pulls metadata, B downloads',
      () async {
    // 1. Device A: user imports a book. The book has a real local file path
    //    (binary on disk), file_synced_at = NULL (not yet uploaded).
    const bookId = 'b1';
    const format = 'epub';
    final localPathA = '$dirA/$bookId.$format';
    final bookBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0xAA, 0xBB]);
    await File(localPathA).writeAsBytes(bookBytes);

    await dbA.customInsert(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) '
      'VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(bookId),
        Variable.withString('Cross-device Book'),
        Variable.withString(format),
        Variable.withString(localPathA),
        Variable.withString('h-$bookId'),
        Variable.withInt(bookBytes.length),
      ],
    );

    // 2. Device A: enqueue book metadata record (BookImportService does this
    //    via LocalBookRepository.save → SyncRecorder.recordBook).
    final recorder = SyncRecorder(SyncOutboxDao(dbA));
    await recorder.recordBook(
      id: bookId,
      title: 'Cross-device Book',
      author: null,
      format: format,
      fileHash: 'h-$bookId',
      fileSizeBytes: bookBytes.length,
      hasCover: false,
      mtime: DateTime.utc(2026, 7, 12, 10),
    );

    // 3. Device A push (metadata). Capture body for B's pull.
    String? pushedMetadataBody;
    when(() => webdavA.getString(any())).thenAnswer((_) async => '');
    when(() => webdavA.putString(any(), any())).thenAnswer((inv) async {
      pushedMetadataBody = inv.positionalArguments[1] as String;
    });
    await engineA.pushOnly();
    expect(pushedMetadataBody, isNotNull);

    // 4. Device A upload binary via BookFileSyncService.uploadPendingFiles.
    //    Cloud-side: capture the bytes; B will GET them later.
    Uint8List? pushedBytes;
    when(() => webdavA.putBytes(any(), any())).thenAnswer((inv) async {
      pushedBytes = Uint8List.fromList(inv.positionalArguments[1] as List<int>);
    });
    await fileSyncA.uploadPendingFiles();
    expect(pushedBytes, isNotNull);
    expect(pushedBytes!.toList(), bookBytes);

    // file_synced_at on A should now be set.
    final rowA = await dbA.customSelect(
      'SELECT file_synced_at FROM books WHERE id = ?',
      variables: [Variable.withString(bookId)],
    ).getSingle();
    expect(rowA.readNullable<int>('file_synced_at'), isNotNull);

    // 5. Device B pull metadata.
    when(() => webdavB.listFiles(any()))
        .thenAnswer((_) async => ['device-A.jsonl']);
    when(() => webdavB.getString(any()))
        .thenAnswer((_) async => pushedMetadataBody!);
    final pullResult = await engineB.pullOnly();
    expect(pullResult.pulledCount, 1);

    // 6. Verify B received the book with file_path = sentinel (binary not
    //    yet downloaded). This is the M2.8 T10 contract.
    final rowB = await dbB.customSelect(
      'SELECT file_path, file_synced_at FROM books WHERE id = ?',
      variables: [Variable.withString(bookId)],
    ).getSingle();
    expect(rowB.read<String>('file_path'),
        BookFileSyncService.needsDownloadSentinel);
    expect(rowB.readNullable<int>('file_synced_at'), isNull);

    // 7. Device B: user taps the book in the library. LibraryPage detects
    //    the sentinel and triggers BookFileSyncService.downloadBookFile.
    //    Cloud-side: GET returns A's pushed bytes.
    when(() => webdavB.getBytes(any())).thenAnswer((_) async => pushedBytes!);
    await fileSyncB.downloadBookFile(bookId);

    // 8. Verify B now has the binary on disk + file_path updated.
    final localPathB = '$dirB/$bookId.$format';
    expect(await File(localPathB).exists(), isTrue);
    expect(await File(localPathB).readAsBytes(), bookBytes);

    final rowBAfter = await dbB.customSelect(
      'SELECT file_path, file_synced_at FROM books WHERE id = ?',
      variables: [Variable.withString(bookId)],
    ).getSingle();
    expect(rowBAfter.read<String>('file_path'), localPathB);
    expect(rowBAfter.readNullable<int>('file_synced_at'),
        isNotNull); // stamped after download
  });

  test('cross-device book delete: A deletes, B pulls tombstone + deletes row',
      () async {
    // 1. Both devices have the book.
    const bookId = 'b1';
    const format = 'epub';
    await dbA.customInsert(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) '
      'VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(bookId),
        Variable.withString('To Delete'),
        Variable.withString(format),
        Variable.withString('$dirA/$bookId.$format'),
        Variable.withString('h-$bookId'),
        Variable.withInt(0),
      ],
    );
    await dbB.customInsert(
      'INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes) '
      'VALUES(?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(bookId),
        Variable.withString('To Delete'),
        Variable.withString(format),
        Variable.withString('$dirB/$bookId.$format'),
        Variable.withString('h-$bookId'),
        Variable.withInt(0),
      ],
    );

    // 2. Device A: enqueue book tombstone (LocalBookRepository.delete does
    //    this via SyncRecorder.recordBook with deleted=true).
    final recorder = SyncRecorder(SyncOutboxDao(dbA));
    await recorder.recordBook(
      id: bookId,
      title: '',
      author: null,
      format: '',
      fileHash: '',
      fileSizeBytes: 0,
      hasCover: false,
      mtime: DateTime.utc(2026, 7, 12, 11),
      deleted: true,
    );

    // 3. A push.
    String? pushedBody;
    when(() => webdavA.getString(any())).thenAnswer((_) async => '');
    when(() => webdavA.putString(any(), any())).thenAnswer((inv) async {
      pushedBody = inv.positionalArguments[1] as String;
    });
    await engineA.pushOnly();

    // 4. B pull.
    when(() => webdavB.listFiles(any()))
        .thenAnswer((_) async => ['device-A.jsonl']);
    when(() => webdavB.getString(any()))
        .thenAnswer((_) async => pushedBody!);
    await engineB.pullOnly();

    // 5. Verify B's book row is gone (applier DELETEs on tombstone).
    final rows = await dbB.customSelect(
      'SELECT id FROM books WHERE id = ?',
      variables: [Variable.withString(bookId)],
    ).get();
    expect(rows, isEmpty);
  });
}
