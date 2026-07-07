// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/inline_span_subtree_slicer.dart';

void main() {
  group('InlineSpanSubtreeSlicer', () {
    test('plain text slice returns substring', () {
      final span = TextSpan(text: 'Hello world');
      final sliced = InlineSpanSubtreeSlicer.slice(span, 2, 7);
      // The slicer wraps the slice in a TextSpan whose children carry the
      // actual text; toPlainText() flattens it back to the substring.
      expect(sliced.toPlainText(), 'llo w');
    });

    test('nested spans preserve styles in slice', () {
      final span = TextSpan(children: [
        TextSpan(text: 'a'),
        TextSpan(
            text: 'bold', style: const TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: 'b'),
      ]);
      // Plain text layout: 'a'(0) 'bold'(1..5) 'b'(5). Total length 6.
      // Slice [2, 6) yields 'old' from 'bold' + final 'b' = 'oldb'.
      final sliced = InlineSpanSubtreeSlicer.slice(span, 2, 6);
      expect(sliced.toPlainText(), 'oldb');
      // Style preservation: the 'old' slice should carry the bold style.
      final root = sliced as TextSpan;
      final boldSlice = root.children!.first as TextSpan;
      expect(boldSlice.style?.fontWeight, FontWeight.bold);
      expect(boldSlice.text, 'old');
    });

    test('slice across nested spans preserves widget spans at boundaries', () {
      final span = TextSpan(children: [
        TextSpan(text: 'xy'),
        WidgetSpan(child: Container(), alignment: PlaceholderAlignment.middle),
        TextSpan(text: 'ab'),
      ]);
      final sliced = InlineSpanSubtreeSlicer.slice(span, 1, 4);
      expect(sliced.toPlainText(), 'y￼a');
    });
  });
}
