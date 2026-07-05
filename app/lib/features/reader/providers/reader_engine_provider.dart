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
import '../../../services/markdown_book_loader.dart';
import '../../../services/text_book_loader.dart';

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
    // M4.5: app BookFormat → reader_engine BookFormat 映射（两者同构）。
    format: switch (book.format) {
      BookFormat.epub => re.BookFormat.epub,
      BookFormat.pdf => re.BookFormat.pdf,
      BookFormat.markdown => re.BookFormat.markdown,
      BookFormat.text => re.BookFormat.text,
    },
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
  if (bookRef.format == re.BookFormat.pdf) {
    // M4: PDF routing — pdfrx 原生页渲染
    final engine = PdfReaderEngine(renderer: PdfRenderer());
    final lastProgress = await progressRepo.get(bookId);
    await engine.openWithLastProgress(
      book: bookRef,
      lastLocator: lastProgress?.locator,
    );
    return engine;
  }
  // M4.5: Markdown / TXT routing — 复用 EPUB 的 HTML 渲染管道。
  // 加载器把文件转成 List<HtmlChapterSource>（md→html / txt→<p>），喂给
  // ConcreteEpubReaderEngine.openChapters。复用同一引擎类型 → reader_body
  // 的 `is ConcreteEpubReaderEngine` 检查对 md/txt 也成立，双页/高亮/
  // 章节摘录等能力自动继承，零改 UI。
  if (bookRef.format == re.BookFormat.markdown ||
      bookRef.format == re.BookFormat.text) {
    final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
    final lastProgress = await progressRepo.get(bookId);
    final sources = bookRef.format == re.BookFormat.markdown
        ? await MarkdownBookLoader.loadFile(book.filePath, title: book.title)
        : await TextBookLoader.loadFile(book.filePath, title: book.title);
    await engine.openChapters(
      sources,
      title: book.title,
      lastLocator: lastProgress?.locator,
    );
    // M4.6-fix5: MD/TXT 走 paged 模式（与 EPUB 一致）。
    // 之前 fix3 误改为 scroll 模式以规避 paged + 双页 spread 的段落错位，
    // 但用户实测反馈 MD/TXT 也期望「类 EPUB 双页 + 段落流式」体验。
    // PaginationMode 默认即 paged（EpubxRenderer 字段初值），不显式 set
    // 即走 paged。Paginator 按 plain text 机械分页（与 EPUB 同款），宽屏
    // 双页 spread 取相邻两页配对，行为与 EPUB 完全一致。段落被切到页中
    // 是 paged 模式固有限制（EPUB 也有），用户接受。
    // 不再调 setPaginationMode(scroll)。
    return engine;
  }
  // 防御性兜底：未来新增格式若忘了在此路由，明确报错而非静默走 PDF。
  throw StateError('Unsupported book format: ${book.format}');
});
