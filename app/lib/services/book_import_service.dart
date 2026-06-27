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
    final extension =
        effectiveFormat == BookFormat.epub ? 'epub' : 'pdf';

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

    // Store file
    final stored = await _fileStorage.storeLibraryFile(
      source: source,
      fileHash: hash,
      extension: extension,
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
    // 注意：若已提取封面但 save 失败（极少见），封面文件将残留——可接受，M3.1 不做 GC。
    try {
      await _bookRepository.save(book);
      return ImportResult(book: book, isNew: true);
    } on Exception catch (e) {
      // 仅捕获 SQLite 唯一约束冲突（idx_books_file_hash）；其他异常
      // （磁盘 I/O、OOM、UUID 冲突等）应直接抛出，避免吞掉真实错误。
      if (e.toString().contains('UNIQUE constraint failed')) {
        final fallback = await _bookRepository.findByHash(hash);
        if (fallback != null) {
          return ImportResult(book: fallback, isNew: false);
        }
      }
      rethrow;
    }
  }
}
