// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/material.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine_epub_view/inline_span_subtree_slicer.dart';

/// Renders [breaks] pages of [rootSpan] using a [PageView] of
/// [SelectableText.rich].
///
/// Each page item slices the chapter-level [rootSpan] to its break range via
/// [InlineSpanSubtreeSlicer]. When [dualPageMode] is true, each spread
/// renders two adjacent pages side-by-side in a [Row], separated by
/// [gutterPx] of horizontal space.
///
/// Core invariant (M4.8 spec §3.2): the InlineSpan sliced here is the same
/// one measured by [LineMetricsPaginator], so the rendered page height
/// matches the measured height — no drift.
class SelectablePageView extends StatelessWidget {
  const SelectablePageView({
    super.key,
    required this.rootSpan,
    required this.plainText,
    required this.breaks,
    required this.dualPageMode,
    this.initialPage = 0,
    this.controller,
    this.onPageChanged,
    this.gutterPx = 24,
  });

  /// Chapter-level root span (output of [HtmlToInlineSpanConverter.convert]).
  final InlineSpan rootSpan;

  /// Chapter plain text — currently unused by this widget but kept in the
  /// API for downstream consumers (e.g. selection emit) that need it.
  final String plainText;

  /// Per-page character ranges produced by [LineMetricsPaginator].
  final List<PageBreak> breaks;

  /// When true, each spread packs two pages side-by-side.
  final bool dualPageMode;

  /// Initial page index for the default [PageController].
  final int initialPage;

  /// Optional caller-supplied controller. When null, an internal
  /// [PageController] is created with [initialPage].
  final PageController? controller;

  /// Forwarded to [PageView.onPageChanged].
  final ValueChanged<int>? onPageChanged;

  /// Horizontal gutter between left/right pages in dual-page mode.
  final double gutterPx;

  @override
  Widget build(BuildContext context) {
    final itemCount =
        dualPageMode ? ((breaks.length + 1) ~/ 2) : breaks.length;
    return PageView.builder(
      controller: controller ?? PageController(initialPage: initialPage),
      itemCount: itemCount,
      onPageChanged: onPageChanged,
      itemBuilder: (ctx, spreadIdx) {
        if (dualPageMode) {
          return _buildSpread(spreadIdx);
        }
        return _buildSinglePage(spreadIdx);
      },
    );
  }

  Widget _buildSinglePage(int idx) {
    final b = breaks[idx];
    final span =
        InlineSpanSubtreeSlicer.slice(rootSpan, b.startOffset, b.endOffset);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SelectableText.rich(span),
    );
  }

  Widget _buildSpread(int spreadIdx) {
    final leftIdx = spreadIdx * 2;
    final rightIdx = leftIdx + 1;
    final right = rightIdx < breaks.length
        ? _buildSinglePage(rightIdx)
        : const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildSinglePage(leftIdx)),
        SizedBox(width: gutterPx),
        Expanded(child: right),
      ],
    );
  }
}
