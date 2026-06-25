import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/core/book_ref.dart' as re;
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';
import 'package:zhiyue/data/models/book.dart';

import '../../../core/providers.dart';

/// 给定 bookId，加载 BookRef 并创建对应 ReaderEngine。
final readerEngineForBookProvider =
    FutureProvider.family<ReaderEngine, String>((ref, bookId) async {
  final repo = ref.watch(bookRepositoryProvider);
  final book = await repo.getById(bookId);
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
    return ConcreteEpubReaderEngine(renderer: EpubxRenderer());
  }
  throw UnimplementedError('PDF engine is M4');
});
