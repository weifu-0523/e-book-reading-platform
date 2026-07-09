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
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';
import 'package:reader_engine_pdf_view/pdf_reader_engine.dart';
import 'package:reader_engine_pdf_view/pdf_renderer.dart';
import 'package:zhiyue/data/models/book.dart';

import '../../../core/providers.dart';
import '../../../data/repositories/book_typography_repository.dart';
import '../../../services/markdown_book_loader.dart';
import '../../../services/text_book_loader.dart';

/// 给定 bookId，加载 BookRef、查询上次阅读位置，并打开 [ReaderEngine]。
///
/// Future 解析完成时引擎已 [ReaderEngine.openWithLastProgress]：
/// - 文件加载失败 → 引擎状态为 [ReaderEngineError]（不抛异常）。
/// - 成功且存在 [ReadingProgress.locator] → 尝试 gotoLocator，CFI 失败静默降级。
/// - 无历史进度 → 从第一章开始。
// 2026-07-08 Review P0: 使用 autoDispose + ref.onDispose 让 engine 在
// 没有任何 watcher 时自动 close。原来 FutureProvider.family 缓存 closed
// engine，下次打开同一本书时 ref.watch 返回已 close 的实例（stateController
// 已 close），页面卡死。autoDispose 在 ReaderPage unmount 后释放 cache，
// onDispose 负责调用 engine.close() 释放底层资源（pdfrx PdfDocument /
// html chapter cache）。
final readerEngineForBookProvider =
    FutureProvider.autoDispose.family<ReaderEngine, String>((ref, bookId) async {
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
    final typographyRepo = ref.watch(bookTypographyRepositoryProvider);
    ref.onDispose(engine.close);
    final lastProgress = await progressRepo.get(bookId);
    await engine.openWithLastProgress(
      book: bookRef,
      lastLocator: lastProgress?.locator,
    );
    await _applyPersistedTypography(engine, bookId, typographyRepo);
    return engine;
  }
  if (bookRef.format == re.BookFormat.pdf) {
    // M4: PDF routing — pdfrx 原生页渲染
    final engine = PdfReaderEngine(renderer: PdfRenderer());
    final typographyRepo = ref.watch(bookTypographyRepositoryProvider);
    ref.onDispose(engine.close);
    final lastProgress = await progressRepo.get(bookId);
    await engine.openWithLastProgress(
      book: bookRef,
      lastLocator: lastProgress?.locator,
    );
    await _applyPersistedTypography(engine, bookId, typographyRepo);
    return engine;
  }
  // M4.5/M4.6-fix10: Markdown / TXT routing — 复用 EPUB 的 HTML 渲染管道。
  // 加载器把文件转成 List<HtmlChapterSource>（md→每行<p> / txt→每行<p>），
  // 喂给 ConcreteEpubReaderEngine.openChapters。
  //
  // **M4.6-fix10/A2: MD 与 TXT 完全同构**——两者都走默认 paged + 双页。
  // MD 的 _markdownBodyToHtml 改为仿 TextBookLoader：每行独立成 `<p>`，
  // 无 `<br>`，Paginator 按 plain text 偏移测高精准（与 TXT 一致）。
  // 历史：fix2/3/5/7/9 共 5 次失败的根因是 markdown 标准库产 `<br>`，
  // fix10 用"仿 TXT 每行成 `<p>`"彻底绕开。详见 markdown_book_loader.dart。
  if (bookRef.format == re.BookFormat.markdown) {
    final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
    final typographyRepo = ref.watch(bookTypographyRepositoryProvider);
    ref.onDispose(engine.close);
    final lastProgress = await progressRepo.get(bookId);
    final sources =
        await MarkdownBookLoader.loadFile(book.filePath, title: book.title);
    await engine.openChapters(
      sources,
      title: book.title,
      lastLocator: lastProgress?.locator,
    );
    // M4.6-fix10: 删除 setPaginationMode(scroll)——MD 走默认 paged + 双页，
    // 与 TXT 完全一致。章节切分（# / ##）仍由 MarkdownBookLoader 处理，
    // TOC 自动生成，章节跳转/高亮全部继承。
    await _applyPersistedTypography(engine, bookId, typographyRepo);
    return engine;
  }
  if (bookRef.format == re.BookFormat.text) {
    final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
    final typographyRepo = ref.watch(bookTypographyRepositoryProvider);
    ref.onDispose(engine.close);
    final lastProgress = await progressRepo.get(bookId);
    final sources =
        await TextBookLoader.loadFile(book.filePath, title: book.title);
    await engine.openChapters(
      sources,
      title: book.title,
      lastLocator: lastProgress?.locator,
    );
    // TXT 保持默认 paged + 双页（用户确认 TXT 正常，不改动）。
    await _applyPersistedTypography(engine, bookId, typographyRepo);
    return engine;
  }
  // 防御性兜底：未来新增格式若忘了在此路由，明确报错而非静默走 PDF。
  throw StateError('Unsupported book format: ${book.format}');
});

/// T2: 打开引擎后从 [BookTypographyRepository] 读该书最后一次保存的
/// 排版并应用到 engine；无记录则保留引擎默认（`TypographySettings.defaults`）。
Future<void> _applyPersistedTypography(
  ReaderEngine engine,
  String bookId,
  BookTypographyRepository repo,
) async {
  // Only apply typography if engine successfully opened (Ready state).
  // If engine is in Error state, calling setTypography would fail with
  // "Cannot add new events after calling close" when engine gets disposed.
  if (engine.state is! ReaderEngineReady) return;

  final saved = await repo.getForBook(bookId);
  if (saved != null) {
    await engine.setTypography(saved);
  }
}
