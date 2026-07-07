// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/widgets.dart';

/// Extracts a sub-[InlineSpan] tree covering `[start, end)` character range
/// of the input span's plain text. Used to slice a per-page InlineSpan from
/// a chapter-level InlineSpan for [SelectableText.rich] rendering.
///
/// Algorithm: a recursive walker tracks the absolute offset (in the chapter's
/// plain text) of each visited span. For each [TextSpan], it slices the leaf
/// text portion overlapping `[start, end)` and recurses into children.
/// [WidgetSpan]s occupy exactly 1 char (U+FFFC) in plain text — if that char
/// falls within `[start, end)`, the [WidgetSpan] is preserved verbatim.
///
/// Return type is [TextSpan] (not [InlineSpan]) so callers can pass it
/// directly to [SelectableText.rich] without casting.
class InlineSpanSubtreeSlicer {
  const InlineSpanSubtreeSlicer();

  /// Returns a [TextSpan] whose plain text equals the substring of
  /// [root.toPlainText()] over `[start, end)`.
  ///
  /// Returns an empty [TextSpan] when `start >= end` (degenerate page).
  static TextSpan slice(InlineSpan root, int start, int end) {
    if (start >= end) return const TextSpan(text: '');
    final builder = _SliceBuilder(start, end);
    builder.visit(root, 0);
    return TextSpan(style: _styleOf(root), children: builder.out);
  }

  static TextStyle? _styleOf(InlineSpan span) {
    if (span is TextSpan) return span.style;
    return null;
  }
}

/// Mutable walker that accumulates the sliced child spans into [out].
///
/// `visit(span, offset)` returns the plain-text length consumed by [span]
/// (text length + recursive children length), so the caller can advance
/// the offset for the next sibling.
class _SliceBuilder {
  final int start;
  final int end;
  final List<InlineSpan> out = <InlineSpan>[];

  _SliceBuilder(this.start, this.end);

  int visit(InlineSpan span, int offset) {
    if (span is TextSpan) {
      return _visitTextSpan(span, offset);
    }
    if (span is WidgetSpan) {
      return _visitWidgetSpan(span, offset);
    }
    return 0;
  }

  int _visitTextSpan(TextSpan span, int offset) {
    var consumed = 0;
    final text = span.text ?? '';
    if (text.isNotEmpty) {
      final absEnd = offset + text.length;
      // Overlap test: [offset, absEnd) ∩ [start, end) ≠ ∅.
      if (absEnd > start && offset < end) {
        final localStart = (start - offset).clamp(0, text.length);
        final localEnd = (end - offset).clamp(0, text.length);
        if (localEnd > localStart) {
          out.add(TextSpan(
            text: text.substring(localStart, localEnd),
            style: span.style,
          ));
        }
      }
      consumed = text.length;
    }
    if (span.children != null) {
      var childOffset = offset + consumed;
      for (final child in span.children!) {
        childOffset += visit(child, childOffset);
      }
      consumed = childOffset - offset;
    }
    return consumed;
  }

  int _visitWidgetSpan(WidgetSpan span, int offset) {
    // WidgetSpan occupies exactly 1 char (U+FFFC) in plain text.
    if (offset >= start && offset < end) {
      out.add(span);
    }
    return 1;
  }
}
