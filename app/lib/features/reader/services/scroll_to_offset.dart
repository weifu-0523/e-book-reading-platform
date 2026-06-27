import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Scrolls a [Scrollable] to make the character at [targetOffset] visible.
///
/// Algorithm:
/// 1. Collect all [RenderParagraph] descendants of [scrollable] in DFS order.
/// 2. Accumulate each paragraph's `text.toPlainText().length` until cumulative
///    length exceeds targetOffset — that paragraph owns the offset.
/// 3. Compute the caret position within the owning paragraph via
///    `getOffsetForCaret(TextPosition(offset: localOffset), Rect.zero)`.
/// 4. Translate paragraph-local caret to scrollable-local via
///    `getTransformTo(scrollable.findRenderObject())`.
/// 5. `animateTo(y)` on scrollable.position.
///
/// Edge cases:
/// - targetOffset out of range: silent return (no scroll).
/// - Owner paragraph not found: silent return.
/// - Caller responsible for ensuring [scrollable] has been laid out —
///   typically call after `await WidgetsBinding.instance.endOfFrame`.
///
/// **Limitation (M3.3)**: Only works in `PaginationMode.scroll`. In
/// `PaginationMode.paged` (production default), the underlying `PageView`
/// only mounts the current page's [RenderParagraph]s, so cumulative
/// character offsets do not span the chapter. Pass [isPagedMode] = true
/// to short-circuit (caller still benefits from `gotoLocator` chapter
/// navigation). Full paged-mode support (Paginator breaks + jumpToPage)
/// is planned for M3.4.
class ScrollToOffsetService {
  static Future<void> scrollToCharacterOffset({
    required BuildContext context,
    required ScrollableState scrollable,
    required int targetOffset,
    Duration duration = const Duration(milliseconds: 300),
    bool isPagedMode = false,
  }) async {
    if (isPagedMode) {
      // Paged mode: ScrollToOffsetService cannot precisely target offsets
      // across page boundaries. Caller's gotoLocator has already navigated
      // to the correct chapter; user can switch to scroll mode for precise
      // scrolling. M3.4 will add Paginator-breaks-based paged mode support.
      debugPrint(
        '[ScrollToOffsetService] paged mode short-circuit (M3.3 limitation); '
        'targetOffset=$targetOffset ignored. Use scroll mode for precise scroll.',
      );
      return;
    }
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
    if (owner == null) return; // out of range

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

  /// Collect [RenderParagraph] descendants in document order (DFS).
  static List<RenderParagraph> _collectRenderParagraphs(RenderObject root) {
    final result = <RenderParagraph>[];
    void visit(RenderObject obj) {
      if (obj is RenderParagraph) {
        result.add(obj);
      }
      obj.visitChildren(visit);
    }
    visit(root);
    return result;
  }
}
