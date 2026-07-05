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
import 'package:reader_engine/rendering/pagination_model.dart';
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
  // M4.5/M4.6-fix9: Markdown / TXT routing — 复用 EPUB 的 HTML 渲染管道。
  // 加载器把文件转成 List<HtmlChapterSource>（md→html / txt→<p>），喂给
  // ConcreteEpubReaderEngine.openChapters。
  //
  // **M4.6-fix9 关键分流**：MD 强制走 scroll 模式，TXT 保持 paged 模式。
  // 原因：EPUB 的 Paginator 按 plain text 偏移机械分页，对 MD 的 <br>
  // 强制换行（_forceVisibleLineBreaks）测量不准，导致段落被切到页中、
  // 内容溢出页面边界（fix2/3/5/7 共 4 次失败）。MD 走 scroll 后用
  // 既有 _buildScroll（SingleChildScrollView + HtmlWidget），段落完整、
  // 不溢出。TXT 段落是纯文本流，paged 模式正常工作（用户确认 TXT 正常），
  // 保持 paged + 双页。
  //
  // MD 不做双页（scroll 模式无双页）：fwfh 不支持 CSS column-count，
  // 双栏需自定义 RenderObject，收益低。MD 内容通常是技术文档/笔记，
  // 单列滚动阅读可接受（GitHub/VS Code 预览均单列）。
  if (bookRef.format == re.BookFormat.markdown) {
    final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
    final lastProgress = await progressRepo.get(bookId);
    final sources =
        await MarkdownBookLoader.loadFile(book.filePath, title: book.title);
    await engine.openChapters(
      sources,
      title: book.title,
      lastLocator: lastProgress?.locator,
    );
    // M4.6-fix9: MD 强制 scroll，跳过 Paginator。
    await engine.setPaginationMode(PaginationMode.scroll);
    return engine;
  }
  if (bookRef.format == re.BookFormat.text) {
    final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
    final lastProgress = await progressRepo.get(bookId);
    final sources =
        await TextBookLoader.loadFile(book.filePath, title: book.title);
    await engine.openChapters(
      sources,
      title: book.title,
      lastLocator: lastProgress?.locator,
    );
    // TXT 保持默认 paged + 双页（用户确认 TXT 正常，不改动）。
    return engine;
  }
  // 防御性兜底：未来新增格式若忘了在此路由，明确报错而非静默走 PDF。
  throw StateError('Unsupported book format: ${book.format}');
});
