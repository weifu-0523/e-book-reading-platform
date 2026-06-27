import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/core/book_ref.dart' as re;
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';
import 'package:reader_engine_pdf_view/pdf_reader_engine.dart';
import 'package:reader_engine_pdf_view/pdf_renderer.dart';
import 'package:zhiyue/data/models/book.dart';

import '../../../core/providers.dart';

/// 给定 bookId，加载 BookRef、查询上次阅读位置，并打开 [ReaderEngine]。
///
/// Future 解析完成时引擎已 [ReaderEngine.openWithLastProgress]：
/// - 文件加载失败 → 引擎状态为 [ReaderEngineError]（不抛异常）。
/// - 成功且存在 [ReadingProgress.locator] → 尝试 gotoLocator，CFI 失败静默降级。
/// - 无历史进度 → 从第一章开始。
final readerEngineForBookProvider =
    FutureProvider.family<ReaderEngine, String>((ref, bookId) async {
  final bookRepo = ref.watch(bookRepositoryProvider);
  final progressRepo = ref.watch(readingProgressRepositoryProvider);

  final book = await bookRepo.getById(bookId);
  if (book == null) {
    throw StateError('Book not found: $bookId');
  }

  final bookRef = re.BookRef(
    id: book.id,
    title: book.title,
    format: book.format == BookFormat.epub
        ? re.BookFormat.epub
        : re.BookFormat.pdf,
    filePath: book.filePath,
  );

  if (bookRef.format == re.BookFormat.epub) {
    final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
    final lastProgress = await progressRepo.get(bookId);
    await engine.openWithLastProgress(
      book: bookRef,
      lastLocator: lastProgress?.locator,
    );
    return engine;
  }
  // M4: PDF routing
  final engine = PdfReaderEngine(renderer: PdfRenderer());
  final lastProgress = await progressRepo.get(bookId);
  await engine.openWithLastProgress(
    book: bookRef,
    lastLocator: lastProgress?.locator,
  );
  return engine;
});
