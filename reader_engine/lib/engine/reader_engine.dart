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

import 'package:flutter/widgets.dart';

import '../core/book_ref.dart';
import '../core/locator.dart';
import '../core/page_break.dart';
import '../core/typography_settings.dart';
import '../navigation/toc.dart';
import 'reader_engine_state.dart';
import '../rendering/pagination_model.dart';

/// 阅读引擎抽象 —— UI 层唯一入口，format-agnostic。
///
/// 不区分 EPUB / PDF；具体格式由 [open] 时选择的内部 Renderer 决定。
abstract interface class ReaderEngine {
  ReaderEngineState get state;
  Stream<ReaderEngineState> get state$;
  Stream<Locator> get currentLocation$;

  /// Plain text of the current spine item, parsed from the chapter's HTML.
  ///
  /// Used by app layer to compute character offsets for `EpubRangeLocator`.
  /// Implementation caches per `chapterIndex` for the engine's lifetime.
  Future<String> get currentChapterPlainText;

  /// Page breaks for the current chapter in plainText coordinates.
  ///
  /// Returns `const []` when:
  /// - Pagination mode is `scroll` (no pagination).
  /// - Chapter hasn't been laid out yet (paged mode build not run).
  ///
  /// In paged mode after first layout, returns the breaks from the
  /// Paginator. Length matches `PageController.itemCount` of the paged view.
  List<PageBreak> get currentChapterPageBreaks;

  /// PageController used by paged-mode PageView (M3.4).
  ///
  /// Returns null when this engine doesn't drive a paged view (e.g.,
  /// scroll-only renderers, test fakes). The concrete [EpubxRenderer]
  /// implementation returns a non-null controller for the engine's
  /// lifetime (constructed eagerly in the field initializer).
  PageController? get pageController;

  /// Returns a Future that completes when the current chapter switch has
  /// settled (page breaks computed, renderer ready). Callers awaiting this
  /// Future can safely read [currentChapterPageBreaks] without polling
  /// `endOfFrame`.
  ///
  /// Concrete implementations complete this Future on the post-frame callback
  /// following a chapter change ([setChapter], cross-chapter [gotoLocator],
  /// book switch). If no switch is in progress, the returned Future is
  /// already completed.
  Future<void> get chapterSwitchSettled;
  TableOfContents? get toc;
  TypographySettings get typography;
  PaginationMode get paginationMode;

  Future<void> open(BookRef book);
  Future<void> gotoLocator(Locator locator);
  Future<void> gotoTocEntry(TocEntry entry);
  Future<void> nextSpine();
  Future<void> previousSpine();
  Future<void> setTypography(TypographySettings settings);
  Future<void> setPaginationMode(PaginationMode mode);
  Future<void> close();

  /// 由 UI 层调用，构建实际阅读区。
  Widget build(BuildContext context);
}
