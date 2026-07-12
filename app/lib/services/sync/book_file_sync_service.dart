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

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/services/sync/web_dav_client.dart';

/// Coordinates binary file sync (upload / download / delete) for books via
/// WebDAV.
///
/// Remote path scheme: `/zhiyue/files/<bookId>.<format>`
/// Local path: `<localFilesDir>/<bookId>.<format>`
///
/// Sentinel: `books.file_path = '__needs_download__'` means metadata has
/// been synced from another device but the binary file itself has not yet
/// been downloaded locally. The receiver should call [downloadBookFile]
/// when the user opens the book (T11 will wire this into the reader open
/// bridge).
///
/// Caller contract:
/// - On book import (local file present): `file_path = <absolute>`,
///   `file_synced_at = NULL`. The next [uploadPendingFiles] pass uploads
///   the binary + stamps `file_synced_at`.
/// - On remote-apply of a book record (received from another device):
///   `file_path = __needs_download__`, `file_synced_at = NULL`. Reader
///   open triggers [downloadBookFile], which writes the binary + updates
///   `file_path` + stamps `file_synced_at`.
/// - On book delete: caller invokes [deleteRemoteFile] before deleting the
///   local DB row so we still know the format (extension).
class BookFileSyncService {
  BookFileSyncService({
    required AppDatabase database,
    required WebDavClient webdav,
    required String localFilesDir,
  })  : _db = database,
        _webdav = webdav,
        _localFilesDir = localFilesDir;

  final AppDatabase _db;
  final WebDavClient _webdav;
  final String _localFilesDir;

  /// Sentinel value placed in `books.file_path` when the book's metadata
  /// has been received via sync but the binary file has not yet been
  /// downloaded locally. Reader-open should trigger [downloadBookFile].
  static const String needsDownloadSentinel = '__needs_download__';

  /// Remote directory under which all book binary files are stored. Each
  /// file is named `<bookId>.<format>` (e.g. `b1.epub`).
  static const String remoteFilesDir = '/zhiyue/files';

  /// Upload a single book's binary file to WebDAV.
  ///
  /// - Skips silently if the book is not in the DB.
  /// - Skips silently if `file_path` is [needsDownloadSentinel] (no local
  ///   file to upload — this is a receiver-side placeholder row).
  /// - Throws [FileSystemException] if `file_path` points at a file that
  ///   no longer exists on disk (caller should treat as data integrity
  ///   error, not retry).
  /// - Throws [WebDavException] on any non-2xx HTTP status (e.g. 507
  ///   Insufficient Storage). Caller decides retry / user messaging.
  /// - On success, stamps `books.file_synced_at` with current time (ms
  ///   since epoch) so [uploadPendingFiles] won't re-upload on the next
  ///   sync cycle.
  Future<void> uploadBookFile(String bookId) async {
    final row = await _db.customSelect(
      'SELECT format, file_path FROM books WHERE id = ?',
      variables: [Variable.withString(bookId)],
    ).getSingleOrNull();
    if (row == null) return; // book not in DB — nothing to upload.

    final format = row.read<String>('format');
    final filePath = row.read<String>('file_path');

    if (filePath == needsDownloadSentinel) return; // nothing local to upload.

    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Local file not found', filePath);
    }

    final bytes = await file.readAsBytes();
    final remotePath = '$remoteFilesDir/$bookId.$format';

    // Bug A fix (2026-07-12): jianguoyun WebDAV does NOT auto-create parent
    // directories on PUT — without this MKCOL, PUT to
    // /zhiyue/files/<bookId>.<format> returns 409 AncestorsNotFound and the
    // upload is silently swallowed by uploadPendingFiles' per-book catch.
    // ensureAncestors MKCOLs /zhiyue and /zhiyue/files idempotently (405 =
    // already exists is fine).
    await _webdav.ensureAncestors(remotePath);

    // Throws WebDavException on failure — caller (or uploadPendingFiles)
    // decides what to do. We intentionally do NOT special-case 507 here.
    await _webdav.putBytes(remotePath, bytes);

    await _db.customStatement(
      'UPDATE books SET file_synced_at = ? WHERE id = ?',
      [DateTime.now().millisecondsSinceEpoch, bookId],
    );
  }

  /// Scan all books where `file_synced_at IS NULL` AND `file_path` is not
  /// the [needsDownloadSentinel], and upload each.
  ///
  /// Continues on individual upload failure — one book failing (e.g. 507
  /// quota) must NOT block the rest. Failures are logged via stderr (the
  /// project currently has no structured logger; T10/T11 will surface
  /// these via SyncController conflictSink if needed).
  ///
  /// Used by the sync engine on each cycle (T10 wires this in).
  Future<void> uploadPendingFiles() async {
    final rows = await _db.customSelect(
      'SELECT id FROM books WHERE file_synced_at IS NULL AND file_path != ?',
      variables: [Variable.withString(needsDownloadSentinel)],
    ).get();

    for (final row in rows) {
      final bookId = row.read<String>('id');
      try {
        await uploadBookFile(bookId);
      } on WebDavException catch (e) {
        // Log + continue. Other books may still fit within quota.
        // TODO(M2.8 T10/T11): surface to UI via SyncController when wired.
        stderr.writeln('BookFileSyncService.uploadPendingFiles: '
            'upload failed for $bookId: $e');
      } on FileSystemException catch (e) {
        // Local file missing — log + continue. Should not happen in normal
        // operation but can if user manually deleted the file.
        stderr.writeln('BookFileSyncService.uploadPendingFiles: '
            'local file missing for $bookId: $e');
      }
    }
  }

  /// Download a single book's binary file from WebDAV.
  ///
  /// - Skips silently if the book is not in the DB.
  /// - Writes the binary to `<localFilesDir>/<bookId>.<format>`.
  /// - Updates `books.file_path` from [needsDownloadSentinel] (or any
  ///   prior value) to the actual local path.
  /// - Stamps `books.file_synced_at` so we don't re-download on the next
  ///   sync cycle.
  /// - Throws [WebDavException] on any non-2xx HTTP status (e.g. 404 = the
  ///   file isn't on remote yet; the sender may not have uploaded it).
  Future<void> downloadBookFile(String bookId) async {
    final row = await _db.customSelect(
      'SELECT format FROM books WHERE id = ?',
      variables: [Variable.withString(bookId)],
    ).getSingleOrNull();
    if (row == null) return;

    final format = row.read<String>('format');
    final remotePath = '$remoteFilesDir/$bookId.$format';
    final localPath = '$_localFilesDir/$bookId.$format';

    // Throws WebDavException on failure — file_path stays as sentinel so
    // the next attempt can retry.
    final bytes = await _webdav.getBytes(remotePath);

    final file = File(localPath);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);

    await _db.customStatement(
      'UPDATE books SET file_path = ?, file_synced_at = ? WHERE id = ?',
      [localPath, DateTime.now().millisecondsSinceEpoch, bookId],
    );
  }

  /// Delete a book's remote binary file. Idempotent — 404 (file already
  /// gone) is silently swallowed.
  ///
  /// Caller should invoke this BEFORE deleting the local DB row, so we
  /// can still look up `format` (the remote path extension).
  ///
  /// - Skips silently if the book is not in the DB.
  /// - Rethrows any non-404 [WebDavException] (e.g. 401, 500).
  Future<void> deleteRemoteFile(String bookId) async {
    final row = await _db.customSelect(
      'SELECT format FROM books WHERE id = ?',
      variables: [Variable.withString(bookId)],
    ).getSingleOrNull();
    if (row == null) return;

    final format = row.read<String>('format');
    final remotePath = '$remoteFilesDir/$bookId.$format';

    try {
      await _webdav.delete(remotePath);
    } on WebDavException catch (e) {
      // 404 = file already gone — idempotent success. The webdav.delete
      // already swallows 404 internally, but defensive: if a future
      // refactor changes that contract, we still want this method to be
      // idempotent.
      if (e.statusCode != 404) rethrow;
    }
  }

  /// Does the local file exist for this book?
  ///
  /// Returns false when:
  /// - Book is not in the DB.
  /// - `file_path` is [needsDownloadSentinel] (binary not downloaded yet).
  /// - File path is set but the file has been deleted from disk (data
  ///   integrity issue — caller may want to offer re-download).
  Future<bool> localFileExists(String bookId) async {
    final row = await _db.customSelect(
      'SELECT file_path FROM books WHERE id = ?',
      variables: [Variable.withString(bookId)],
    ).getSingleOrNull();
    if (row == null) return false;

    final path = row.read<String>('file_path');
    if (path == needsDownloadSentinel) return false;
    return File(path).existsSync();
  }

  /// Compute the local file path for a book.
  ///
  /// - If `file_path` is already an absolute path (not the sentinel),
  ///   returns it as-is.
  /// - If `file_path` is [needsDownloadSentinel], returns the deterministic
  ///   `<localFilesDir>/<bookId>.<format>` path that [downloadBookFile]
  ///   would write to.
  ///
  /// Throws if the book is not in the DB (StateError) — this is a
  /// programming error, callers should check existence first.
  Future<String> getLocalPath(String bookId) async {
    final row = await _db.customSelect(
      'SELECT format, file_path FROM books WHERE id = ?',
      variables: [Variable.withString(bookId)],
    ).getSingle();
    final format = row.read<String>('format');
    final currentPath = row.read<String>('file_path');
    if (currentPath == needsDownloadSentinel) {
      return '$_localFilesDir/$bookId.$format';
    }
    return currentPath;
  }
}
