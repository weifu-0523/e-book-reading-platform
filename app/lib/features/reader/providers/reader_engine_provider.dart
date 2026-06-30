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
