import 'package:flutter/foundation.dart';
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

  /// Revision counter that bumps every time the current chapter changes
  /// (M3.4: paged-mode cache invalidation signal).
  ///
  /// Paged-mode page breaks are only repopulated when the engine's
  /// LayoutBuilder re-runs, which is the **caller's** responsibility.
  /// App-layer widgets should listen to this notifier (e.g. via
  /// `ValueListenableBuilder` or `addListener` + `setState`) and trigger a
  /// rebuild so that [currentChapterPageBreaks] returns fresh data for the
  /// new chapter.
  ///
  /// Default value is a never-bumping notifier; concrete implementations
  /// that actually navigate chapters override this.
  ValueListenable<int> get chapterRevisionNotifier;
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
