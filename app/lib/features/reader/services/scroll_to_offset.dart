import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/rendering/pagination_model.dart';

/// Scrolls a [Scrollable] to make the character at [targetOffset] visible.
///
/// Two modes:
/// - **scroll**: single [SingleChildScrollView] holding the whole chapter.
///   Collect all [RenderParagraph]s, accumulate text lengths to find owner,
///   compute caret via `getOffsetForCaret`, animate to that y.
/// - **paged**: [PageView] where each page is one viewport-sized [Text].
///   Find the page whose break range contains [targetOffset] and jumpToPage.
///   No in-page scroll (page IS viewport; target is naturally visible).
///
/// [targetOffset] is in the same plainText coordinate space as
/// `ReaderEngine.currentChapterPlainText` (post-T0 unification).
class ScrollToOffsetService {
  static Future<void> scrollToCharacterOffset({
    required ScrollableState scrollable,
    required int targetOffset,
    required PaginationMode paginationMode,
    List<PageBreak> pageBreaks = const [],
    PageController? pageController,
    Duration duration = const Duration(milliseconds: 300),
  }) async {
    if (paginationMode == PaginationMode.scroll) {
      await _scrollInScrollView(
        scrollable: scrollable,
        targetOffset: targetOffset,
        duration: duration,
      );
      return;
    }

    // paged mode
    if (pageController == null) {
      throw ArgumentError(
          'pageController is required when paginationMode is paged');
    }
    if (pageBreaks.isEmpty) return;

    final pageIdx = _findPageForOffset(pageBreaks, targetOffset);
    pageController.jumpToPage(pageIdx);
  }

  static int _findPageForOffset(List<PageBreak> breaks, int offset) {
    for (var i = 0; i < breaks.length; i++) {
      if (breaks[i].endOffset > offset) return i;
    }
    return breaks.length - 1;
  }

  static Future<void> _scrollInScrollView({
    required ScrollableState scrollable,
    required int targetOffset,
    required Duration duration,
  }) async {
    final scrollRenderObj = scrollable.context.findRenderObject();
    if (scrollRenderObj == null) return;

    final paragraphs = _collectRenderParagraphs(scrollRenderObj);
    if (paragraphs.isEmpty) return;

    int cumulative = 0;
    RenderParagraph? owner;
    int localOffset = 0;
    for (final p in paragraphs) {
      final len = p.text.toPlainText().length;
      if (cumulative + len > targetOffset) {
        owner = p;
        localOffset = targetOffset - cumulative;
        break;
      }
      cumulative += len;
    }
    if (owner == null) return;

    final caretLocal = owner.getOffsetForCaret(
      TextPosition(offset: localOffset),
      Rect.zero,
    );
    final transform = owner.getTransformTo(scrollRenderObj);
    final caretInScroll = MatrixUtils.transformPoint(transform, caretLocal);

    await scrollable.position.animateTo(
      caretInScroll.dy,
      duration: duration,
      curve: Curves.easeInOut,
    );
  }

  static List<RenderParagraph> _collectRenderParagraphs(RenderObject root) {
    final result = <RenderParagraph>[];
    void visit(RenderObject obj) {
      if (obj is RenderParagraph) result.add(obj);
      obj.visitChildren(visit);
    }
    visit(root);
    return result;
  }
}
