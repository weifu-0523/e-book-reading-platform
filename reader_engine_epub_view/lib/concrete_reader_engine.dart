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

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:reader_engine/core/book_ref.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine/rendering/highlight_range.dart';

import 'epubx_renderer.dart';
import 'src/chapter_end_event.dart';

/// 包装 [EpubxRenderer] 的 [ReaderEngine] 具体实现。
///
/// 当 [BookRef.format] == epub 时由 provider 选择此实现。
class ConcreteEpubReaderEngine implements ReaderEngine {
  ConcreteEpubReaderEngine({required EpubxRenderer renderer})
      : _renderer = renderer;

  final EpubxRenderer _renderer;
  final _stateController = StreamController<ReaderEngineState>.broadcast();

  ReaderEngineState _state = const ReaderEngineUnloaded();
  TableOfContents? _toc;

  @override
  ReaderEngineState get state => _state;

  @override
  Stream<ReaderEngineState> get state$ => _stateController.stream;

  @override
  Stream<Locator> get currentLocation$ => _renderer.currentLocation$;

  @override
  Future<String> get currentChapterPlainText =>
      _renderer.currentChapterPlainText;

  @override
  List<PageBreak> get currentChapterPageBreaks =>
      _renderer.currentChapterPageBreaks;

  @override
  PageController? get pageController => _renderer.pageController;

  @override
  Future<void> get chapterSwitchSettled => _renderer.chapterSwitchSettled;

  /// Forward [EpubxRenderer.chapterEndEvents] so app layer can subscribe
  /// without casting to [EpubxRenderer].
  Stream<ChapterEndEvent> get chapterEndEvents => _renderer.chapterEndEvents;

  /// M2.5/T14: 暴露 renderer 引用以让 reader_body.dart 的 LayoutBuilder
  /// 设置 `dualPageMode`（与 PdfReaderEngine.rendererRef 模式一致）。
  EpubxRenderer get rendererRef => _renderer;

  @override
  TableOfContents? get toc => _toc;

  @override
  TypographySettings get typography => _renderer.typography;

  @override
  PaginationMode get paginationMode => PaginationMode.paged;

  @override
  Future<void> open(BookRef book) async {
    _setState(const ReaderEngineLoading());
    try {
      await _renderer.openFile(book.filePath);
      _toc = await _renderer.toc;
      _setState(const ReaderEngineReady());
    } catch (e, st) {
      _setState(ReaderEngineError(message: '打开书籍失败: $e', cause: e));
      debugPrint('$e\n$st');
    }
  }

  void _setState(ReaderEngineState s) {
    _state = s;
    _stateController.add(s);
  }

  @override
  Future<void> gotoLocator(Locator locator) => _renderer.gotoLocator(locator);

  /// 打开书籍并尝试恢复到上次位置（spec §6.3 CFI fallback）。
  ///
  /// CFI 解码失败时降级到第一章开头，不抛异常。
  Future<void> openWithLastProgress({
    required BookRef book,
    required Locator? lastLocator,
  }) async {
    await open(book);
    if (_state is ReaderEngineReady && lastLocator != null) {
      try {
        await gotoLocator(lastLocator);
      } catch (e, st) {
        // spec §6.3：CFI 解码失败降级到第一章
        debugPrint('CFI restore failed: $e\n$st');
      }
    }
  }

  @override
  Future<void> gotoTocEntry(TocEntry entry) =>
      _renderer.gotoLocator(entry.locator);

  @override
  Future<void> nextSpine() async {
    final renderer = _renderer;
    final currentIdx = renderer.currentChapterIndex;
    final nextIdx = currentIdx + 1;
    if (nextIdx < renderer.flatChapters.length) {
      renderer.setChapter(nextIdx);
    }
    // At end of book: no-op (could emit event later)
  }

  @override
  Future<void> previousSpine() async {
    final renderer = _renderer;
    final currentIdx = renderer.currentChapterIndex;
    if (currentIdx > 0) {
      renderer.setChapter(currentIdx - 1);
    }
    // At start of book: no-op
  }

  @override
  Future<void> setTypography(TypographySettings settings) =>
      _renderer.setTypography(settings);

  @override
  Future<void> setPaginationMode(PaginationMode mode) =>
      _renderer.setPaginationMode(mode);

  @override
  Future<void> close() async {
    await _renderer.dispose();
    await _stateController.close();
  }

  @override
  Widget build(BuildContext context) => _renderer.build(context);

  /// Bridge entrypoint for the highlight-injection pipeline.
  ///
  /// The app layer (e.g. `ReaderBody`) observes `NotesState.annotations` and
  /// forwards the mapped [HighlightRange] list here; this method forwards to
  /// the wrapped [EpubxRenderer], which keeps the call on its internal
  /// chapter revision at the time of invocation.
  Future<void> injectHighlights(List<HighlightRange> ranges) =>
      _renderer.injectHighlights(ranges);
}
