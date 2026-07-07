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

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:reader_engine_epub_view/reader_engine_epub_view.dart';
import 'package:uuid/uuid.dart';

import '../data/local/file_storage.dart';
import '../data/models/book.dart';
import '../data/repositories/book_repository.dart';
import '../data/services/book_format_detector.dart';

class ImportResult {
  final Book book;
  final bool isNew;

  const ImportResult({required this.book, required this.isNew});
}

class BookImportService {
  final BookRepository _bookRepository;
  final FileStorage _fileStorage;
  final EpubCoverExtractor _coverExtractor;
  final Uuid _uuid;

  BookImportService({
    required BookRepository bookRepository,
    required FileStorage fileStorage,
    required EpubCoverExtractor coverExtractor,
    Uuid? uuid,
  })  : _bookRepository = bookRepository,
        _fileStorage = fileStorage,
        _coverExtractor = coverExtractor,
        _uuid = uuid ?? const Uuid();

  /// 导入 [source] 指向的电子书文件。
  ///
  /// 当 [format] 缺省时，由 [BookFormatDetector] 依据文件 magic bytes 推断；
  /// 推断失败抛 [ArgumentError]，调用方应提示用户文件不被支持。
  Future<ImportResult> importFile(
    File source, {
    BookFormat? format,
  }) async {
    final bytes = await source.readAsBytes();
    final hash = sha1.convert(bytes).toString();

    // 调用方未显式提供 format → 走 magic bytes 检测；失败则在 dedup 之后抛出，
    // 以保证同 hash 已入库记录的复用不被打断（dedup-first）。
    final effectiveFormat = format ?? BookFormatDetector.detect(source.path);

    // Dedup by hash（先快路径）
    final existing = await _bookRepository.findByHash(hash);
    if (existing != null) {
      return ImportResult(book: existing, isNew: false);
    }

    if (effectiveFormat == null) {
      throw ArgumentError(
        'Unsupported file format (no PDF/EPUB magic bytes): ${source.path}',
      );
    }

    // Store file（extension 在 null 检查后取，effectiveFormat 此处非空）
    // M4.6-fix11: 走 bytes 路径而非 source.copy，避免 Windows + Sync
    // 目录（坚果云等）的 reparse point 异常导致 PathNotFoundException。
    // bytes 已在 line 60 读出，这里复用零额外 I/O。
    final stored = await _fileStorage.storeLibraryFileFromBytes(
      bytes: bytes,
      fileHash: hash,
      extension: effectiveFormat.fileExtension,
    );

    final fileName = p.basenameWithoutExtension(source.path);
    final bookId = _uuid.v4();

    // 仅 EPUB 提取封面；失败 coverPath=null，import 不中断
    String? coverPath;
    if (effectiveFormat == BookFormat.epub) {
      try {
        coverPath = await _coverExtractor.extract(
          bookId: bookId,
          epubBytes: bytes,
        );
      } catch (_) {
        // 即使 extractor 抛错也不应阻断 import；coverPath 保持 null
        coverPath = null;
      }
    }

    final book = Book(
      id: bookId,
      title: fileName,
      author: null,
      format: effectiveFormat,
      filePath: stored.path,
      fileHash: hash,
      fileSizeBytes: bytes.length,
      coverPath: coverPath,
      addedAt: DateTime.now(),
      lastReadAt: null,
    );

    // 并发安全：upsert-on-hash；若并发下另一路已写入同 hash，
    // 唯一约束会触发冲突，回退查询返回已存在记录。
    try {
      await _bookRepository.save(book);
      return ImportResult(book: book, isNew: true);
    } on Exception catch (e) {
      // UNIQUE 约束：另一路并发已写入同 hash。fileHash 是内容哈希，
      // 同内容只存一份 → 别人写的 library 文件名也是 {hash}.{ext}，
      // 我们刚写的与之完全同名 → 删除只是删掉自己的覆盖（安全），
      // 然后走 findByHash 回退。
      if (e.toString().contains('UNIQUE constraint failed')) {
        final fallback = await _bookRepository.findByHash(hash);
        if (fallback != null) {
          // 顺手清理本次重复写入的 library 文件（幂等；fallback 的同名
          // 文件会保留）。失败也忽略——这只是 best-effort GC。
          try {
            await _fileStorage.deleteLibraryFile(
              hash: hash,
              extension: effectiveFormat.fileExtension,
            );
          } catch (_) {
            // best-effort；不影响主流程
          }
          return ImportResult(book: fallback, isNew: false);
        }
        // fallback 找不到（极少见）：library 文件保留（可能仍有人引用）。
        rethrow;
      }
      // 非 UNIQUE 异常（磁盘 I/O / OOM / UUID 冲突等）：
      // fileHash 是内容哈希，相同内容只存一份；既然 save 失败说明这条
      // book 记录没进 DB，没人会引用这个 library 文件，删除安全。同时
      // 清理本次提取出的 cover。所有清理 best-effort，失败不阻塞 rethrow。
      try {
        await _fileStorage.deleteLibraryFile(
          hash: hash,
          extension: effectiveFormat.fileExtension,
        );
        if (coverPath != null) {
          await _fileStorage.deleteCoverFile(coverPath);
        }
      } catch (_) {
        // best-effort；忽略清理失败
      }
      rethrow;
    }
  }
}
