// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// M2.8 T9: tests for BookFileSyncService — coordinates binary file
// upload/download/delete via WebDAV. Uses in-memory AppDatabase +
// MockClient for deterministic HTTP behavior. Filesystem state is
// exercised against a real temp directory because the service reads
// and writes real binary files.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/book_file_sync_service.dart';
import 'package:zhiyue/services/sync/web_dav_client.dart';

AppDatabase _newDb() => AppDatabase.forTesting();

void main() {
  late AppDatabase db;
  late Directory tmpDir;
  late String booksDir;

  setUp(() async {
    db = _newDb();
    tmpDir = await Directory.systemTemp.createTemp('zhiyue_file_sync_test_');
    booksDir = '${tmpDir.path}/books';
    await Directory(booksDir).create();
  });

  tearDown(() async {
    await db.close();
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  /// Insert a book row. If [filePath] starts with `__needs_download__` no
  /// local file is created (matches production state on receiver side).
  /// Otherwise the local file is written with [content] (default
  /// `'EPUB-CONTENT'`) and the row's `file_size_bytes` is set to the
  /// content length.
  Future<void> insertBook({
    required String id,
    required String format, // 'epub' | 'pdf'
    String? filePath,
    int? fileSyncedAt,
    String content = 'EPUB-CONTENT',
  }) async {
    final path = filePath ?? '$booksDir/$id.$format';
    final isSentinel = path.startsWith('__');
    if (!isSentinel) {
      await File(path).writeAsString(content);
    }
    await db.customStatement(
      '''INSERT INTO books(id, title, format, file_path, file_hash, file_size_bytes, file_synced_at)
         VALUES(?, 't', ?, ?, ?, ?, ?)''',
      [id, format, path, 'h_$id', content.length, fileSyncedAt],
    );
  }

  Future<int?> fileSyncedAt(String bookId) async {
    final row = await db.customSelect(
      'SELECT file_synced_at FROM books WHERE id = ?',
      variables: [Variable.withString(bookId)],
    ).getSingle();
    return row.readNullable<int>('file_synced_at');
  }

  Future<String> filePathOf(String bookId) async {
    final row = await db.customSelect(
      'SELECT file_path FROM books WHERE id = ?',
      variables: [Variable.withString(bookId)],
    ).getSingle();
    return row.read<String>('file_path');
  }

  group('uploadBookFile', () {
    test('uploads local file + sets file_synced_at', () async {
      await insertBook(id: 'b1', format: 'epub');

      List<int>? uploadedBytes;
      String? uploadedPath;
      final webdav = WebDavClient(
        baseUrl: 'https://dav.example.com/dav',
        username: 'u',
        password: 'p',
        httpClient: MockClient((request) async {
          if (request.method == 'PUT') {
            uploadedBytes = request.bodyBytes;
            uploadedPath = request.url.path;
            return http.Response('', 201);
          }
          return http.Response('', 404);
        }),
      );
      final service = BookFileSyncService(
        database: db,
        webdav: webdav,
        localFilesDir: booksDir,
      );

      await service.uploadBookFile('b1');

      expect(uploadedPath, contains('/zhiyue/files/b1.epub'));
      expect(uploadedBytes, isNotNull);
      expect(await fileSyncedAt('b1'), isNotNull);
    });

    test('skips upload when file_path is __needs_download__', () async {
      await insertBook(
        id: 'b1',
        format: 'epub',
        filePath: BookFileSyncService.needsDownloadSentinel,
      );

      var uploadCalled = false;
      final webdav = WebDavClient(
        baseUrl: 'https://dav.example.com/dav',
        username: 'u',
        password: 'p',
        httpClient: MockClient((request) async {
          if (request.method == 'PUT') uploadCalled = true;
          return http.Response('', 201);
        }),
      );
      final service = BookFileSyncService(
        database: db,
        webdav: webdav,
        localFilesDir: booksDir,
      );

      await service.uploadBookFile('b1');

      expect(uploadCalled, isFalse);
      // file_synced_at should remain null — nothing was uploaded.
      expect(await fileSyncedAt('b1'), isNull);
    });

    test('throws on 507 Insufficient Storage', () async {
      await insertBook(id: 'b1', format: 'epub');

      final webdav = WebDavClient(
        baseUrl: 'https://dav.example.com/dav',
        username: 'u',
        password: 'p',
        httpClient: MockClient((request) async {
          return http.Response('quota exceeded', 507);
        }),
      );
      final service = BookFileSyncService(
        database: db,
        webdav: webdav,
        localFilesDir: booksDir,
      );

      expect(
        () => service.uploadBookFile('b1'),
        throwsA(isA<WebDavException>()
            .having((e) => e.statusCode, 'statusCode', 507)),
      );
      // Verify file_synced_at NOT set on failure.
      expect(await fileSyncedAt('b1'), isNull);
    });

    test('skips when book not found in DB', () async {
      final webdav = WebDavClient(
        baseUrl: 'https://dav.example.com/dav',
        username: 'u',
        password: 'p',
        httpClient: MockClient((request) async => http.Response('', 201)),
      );
      final service = BookFileSyncService(
        database: db,
        webdav: webdav,
        localFilesDir: booksDir,
      );

      // should not throw
      await service.uploadBookFile('nonexistent');
    });
  });

  group('uploadPendingFiles', () {
    test('scans books with file_synced_at IS NULL + uploads each', () async {
      await insertBook(id: 'b1', format: 'epub', fileSyncedAt: null);
      await insertBook(id: 'b2', format: 'pdf', fileSyncedAt: null);
      // already synced — should NOT be re-uploaded
      await insertBook(id: 'b3', format: 'epub', fileSyncedAt: 1700000000000);

      var uploadCount = 0;
      final webdav = WebDavClient(
        baseUrl: 'https://dav.example.com/dav',
        username: 'u',
        password: 'p',
        httpClient: MockClient((request) async {
          if (request.method == 'PUT') {
            uploadCount++;
            return http.Response('', 201);
          }
          return http.Response('', 404);
        }),
      );
      final service = BookFileSyncService(
        database: db,
        webdav: webdav,
        localFilesDir: booksDir,
      );

      await service.uploadPendingFiles();

      expect(uploadCount, 2); // b1 + b2, not b3
      expect(await fileSyncedAt('b1'), isNotNull);
      expect(await fileSyncedAt('b2'), isNotNull);
    });

    test('skips books whose file_path is __needs_download__', () async {
      await insertBook(id: 'b1', format: 'epub'); // local file present
      await insertBook(
        id: 'b2',
        format: 'epub',
        filePath: BookFileSyncService.needsDownloadSentinel,
      );

      var uploadCount = 0;
      final webdav = WebDavClient(
        baseUrl: 'https://dav.example.com/dav',
        username: 'u',
        password: 'p',
        httpClient: MockClient((request) async {
          if (request.method == 'PUT') {
            uploadCount++;
            return http.Response('', 201);
          }
          return http.Response('', 404);
        }),
      );
      final service = BookFileSyncService(
        database: db,
        webdav: webdav,
        localFilesDir: booksDir,
      );

      await service.uploadPendingFiles();

      expect(uploadCount, 1); // only b1
    });

    test('continues on individual upload failure (507)', () async {
      await insertBook(id: 'b1', format: 'epub');
      await insertBook(id: 'b2', format: 'pdf');

      var successCount = 0;
      var failCount = 0;
      final webdav = WebDavClient(
        baseUrl: 'https://dav.example.com/dav',
        username: 'u',
        password: 'p',
        httpClient: MockClient((request) async {
          if (request.url.path.contains('b1')) {
            failCount++;
            return http.Response('quota', 507);
          }
          successCount++;
          return http.Response('', 201);
        }),
      );
      final service = BookFileSyncService(
        database: db,
        webdav: webdav,
        localFilesDir: booksDir,
      );

      // should not throw — one failure must not block the other.
      await service.uploadPendingFiles();

      expect(failCount, 1);
      expect(successCount, 1);
      // b1 should still have null file_synced_at; b2 should be set.
      expect(await fileSyncedAt('b1'), isNull);
      expect(await fileSyncedAt('b2'), isNotNull);
    });
  });

  group('downloadBookFile', () {
    test('downloads + writes to local path + updates file_path', () async {
      await insertBook(
        id: 'b1',
        format: 'epub',
        filePath: BookFileSyncService.needsDownloadSentinel,
      );

      final webdav = WebDavClient(
        baseUrl: 'https://dav.example.com/dav',
        username: 'u',
        password: 'p',
        httpClient: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path.contains('/zhiyue/files/b1.epub')) {
            return http.Response.bytes([0x50, 0x4B, 0x03, 0x04], 200);
          }
          return http.Response('', 404);
        }),
      );
      final service = BookFileSyncService(
        database: db,
        webdav: webdav,
        localFilesDir: booksDir,
      );

      await service.downloadBookFile('b1');

      final localPath = '$booksDir/b1.epub';
      expect(await File(localPath).exists(), isTrue);
      expect(await File(localPath).readAsBytes(), [0x50, 0x4B, 0x03, 0x04]);

      expect(await filePathOf('b1'), localPath);
      // mark as synced after download so we don't re-download on next sync.
      expect(await fileSyncedAt('b1'), isNotNull);
    });

    test('throws on 404 (file not on remote)', () async {
      await insertBook(
        id: 'b1',
        format: 'epub',
        filePath: BookFileSyncService.needsDownloadSentinel,
      );

      final webdav = WebDavClient(
        baseUrl: 'https://dav.example.com/dav',
        username: 'u',
        password: 'p',
        httpClient: MockClient((request) async => http.Response('not found', 404)),
      );
      final service = BookFileSyncService(
        database: db,
        webdav: webdav,
        localFilesDir: booksDir,
      );

      expect(
        () => service.downloadBookFile('b1'),
        throwsA(isA<WebDavException>()),
      );
      // file_path should still be __needs_download__.
      expect(await filePathOf('b1'), BookFileSyncService.needsDownloadSentinel);
    });

    test('skips when book not found in DB', () async {
      final webdav = WebDavClient(
        baseUrl: 'https://dav.example.com/dav',
        username: 'u',
        password: 'p',
        httpClient: MockClient((request) async => http.Response('', 200)),
      );
      final service = BookFileSyncService(
        database: db,
        webdav: webdav,
        localFilesDir: booksDir,
      );

      // should not throw
      await service.downloadBookFile('nonexistent');
    });
  });

  group('deleteRemoteFile', () {
    test('DELETEs /zhiyue/files/<id>.<format>', () async {
      await insertBook(id: 'b1', format: 'epub');

      String? deletedPath;
      String? deletedMethod;
      final webdav = WebDavClient(
        baseUrl: 'https://dav.example.com/dav',
        username: 'u',
        password: 'p',
        httpClient: MockClient((request) async {
          if (request.method == 'DELETE') {
            deletedPath = request.url.path;
            deletedMethod = request.method;
            return http.Response('', 204);
          }
          return http.Response('', 404);
        }),
      );
      final service = BookFileSyncService(
        database: db,
        webdav: webdav,
        localFilesDir: booksDir,
      );

      await service.deleteRemoteFile('b1');

      expect(deletedMethod, 'DELETE');
      expect(deletedPath, contains('/zhiyue/files/b1.epub'));
    });

    test('ignores 404 (file already gone)', () async {
      await insertBook(id: 'b1', format: 'epub');

      final webdav = WebDavClient(
        baseUrl: 'https://dav.example.com/dav',
        username: 'u',
        password: 'p',
        httpClient: MockClient((request) async => http.Response('not found', 404)),
      );
      final service = BookFileSyncService(
        database: db,
        webdav: webdav,
        localFilesDir: booksDir,
      );

      // should not throw
      await service.deleteRemoteFile('b1');
    });

    test('skips when book not found in DB', () async {
      final webdav = WebDavClient(
        baseUrl: 'https://dav.example.com/dav',
        username: 'u',
        password: 'p',
        httpClient: MockClient((request) async => http.Response('', 204)),
      );
      final service = BookFileSyncService(
        database: db,
        webdav: webdav,
        localFilesDir: booksDir,
      );

      await service.deleteRemoteFile('nonexistent'); // should not throw
    });
  });

  group('localFileExists', () {
    test('returns true when local file present', () async {
      await insertBook(id: 'b1', format: 'epub');
      final service = BookFileSyncService(
        database: db,
        webdav: WebDavClient(
          baseUrl: 'https://x',
          username: 'u',
          password: 'p',
          httpClient: MockClient((_) async => http.Response('', 200)),
        ),
        localFilesDir: booksDir,
      );
      expect(await service.localFileExists('b1'), isTrue);
    });

    test('returns false when file_path is __needs_download__', () async {
      await insertBook(
        id: 'b1',
        format: 'epub',
        filePath: BookFileSyncService.needsDownloadSentinel,
      );
      final service = BookFileSyncService(
        database: db,
        webdav: WebDavClient(
          baseUrl: 'https://x',
          username: 'u',
          password: 'p',
          httpClient: MockClient((_) async => http.Response('', 200)),
        ),
        localFilesDir: booksDir,
      );
      expect(await service.localFileExists('b1'), isFalse);
    });

    test('returns false when local file has been deleted from disk',
        () async {
      await insertBook(id: 'b1', format: 'epub');
      // Delete the local file after insert (row still references it).
      final path = '$booksDir/b1.epub';
      await File(path).delete();
      final service = BookFileSyncService(
        database: db,
        webdav: WebDavClient(
          baseUrl: 'https://x',
          username: 'u',
          password: 'p',
          httpClient: MockClient((_) async => http.Response('', 200)),
        ),
        localFilesDir: booksDir,
      );
      expect(await service.localFileExists('b1'), isFalse);
    });

    test('returns false when book not found in DB', () async {
      final service = BookFileSyncService(
        database: db,
        webdav: WebDavClient(
          baseUrl: 'https://x',
          username: 'u',
          password: 'p',
          httpClient: MockClient((_) async => http.Response('', 200)),
        ),
        localFilesDir: booksDir,
      );
      expect(await service.localFileExists('nonexistent'), isFalse);
    });
  });

  group('getLocalPath', () {
    test('returns current file_path when not sentinel', () async {
      await insertBook(id: 'b1', format: 'epub');
      final service = BookFileSyncService(
        database: db,
        webdav: WebDavClient(
          baseUrl: 'https://x',
          username: 'u',
          password: 'p',
          httpClient: MockClient((_) async => http.Response('', 200)),
        ),
        localFilesDir: booksDir,
      );
      expect(await service.getLocalPath('b1'), '$booksDir/b1.epub');
    });

    test('returns computed local path when file_path is sentinel', () async {
      await insertBook(
        id: 'b1',
        format: 'pdf',
        filePath: BookFileSyncService.needsDownloadSentinel,
      );
      final service = BookFileSyncService(
        database: db,
        webdav: WebDavClient(
          baseUrl: 'https://x',
          username: 'u',
          password: 'p',
          httpClient: MockClient((_) async => http.Response('', 200)),
        ),
        localFilesDir: booksDir,
      );
      expect(await service.getLocalPath('b1'), '$booksDir/b1.pdf');
    });
  });
}
