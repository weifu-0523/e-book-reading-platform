// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:reader_engine/rendering/highlight_range.dart';

/// Output of [HtmlToInlineSpanConverter.convert].
class ConvertedSpans {
  final InlineSpan root;
  final String plainText;
  final List<ParaRange> paragraphRanges;
  final List<InlineImage> images;

  const ConvertedSpans({
    required this.root,
    required this.plainText,
    required this.paragraphRanges,
    required this.images,
  });
}

class ParaRange {
  final int start;
  final int end;
  const ParaRange(this.start, this.end);
}

class InlineImage {
  final String src;
  final int width;
  final int height;
  const InlineImage(this.src, this.width, this.height);
}

/// Convert EPUB chapter HTML into an [InlineSpan] tree for use with
/// TextPainter (measurement) and SelectableText.rich (rendering).
///
/// Core invariant: TextPainter and SelectableText.rich share the same
/// InlineSpan input → identical layout output → zero drift (see spec §3.2).
class HtmlToInlineSpanConverter {
  const HtmlToInlineSpanConverter();

  ConvertedSpans convert(
    String chapterHtml, {
    required TextStyle baseStyle,
    required double imageMaxHeight,
    required double indentEm,
    required bool indentEnabled,
    required List<HighlightRange> highlights,
  }) {
    if (chapterHtml.isEmpty) {
      return ConvertedSpans(
        root: TextSpan(text: '', style: baseStyle),
        plainText: '',
        paragraphRanges: const [],
        images: const [],
      );
    }
    final doc = html_parser.HtmlParser(chapterHtml).parse();
    for (final e in doc.querySelectorAll('script, style')) {
      e.remove();
    }
    final buf = StringBuffer();
    final ranges = <ParaRange>[];
    final images = <InlineImage>[];
    final children = <InlineSpan>[];

    final blockTags = const {'p', 'div'};
    final bodyChildren = doc.body?.nodes ?? const <dom.Node>[];
    final blockElements = <dom.Element>[
      for (final n in bodyChildren)
        if (n is dom.Element && blockTags.contains(n.localName)) n,
    ];

    for (var i = 0; i < blockElements.length; i++) {
      final el = blockElements[i];
      final start = buf.length;
      final paraChildren = <InlineSpan>[];
      // Walk block element's child nodes directly (no wrapping span).
      final blockStyle = _inlineStyle(baseStyle, el.localName);
      for (final child in el.nodes) {
        _walkInline(child, blockStyle, buf, paraChildren, images);
      }
      final end = buf.length;
      ranges.add(ParaRange(start, end));
      children.add(TextSpan(style: blockStyle, children: paraChildren));
      if (i < blockElements.length - 1) {
        buf.write('\n\n');
        children.add(const TextSpan(text: '\n\n'));
      }
    }

    return ConvertedSpans(
      root: TextSpan(style: baseStyle, children: children),
      plainText: buf.toString(),
      paragraphRanges: ranges,
      images: images,
    );
  }

  void _walkInline(
    dom.Node node,
    TextStyle style,
    StringBuffer buf,
    List<InlineSpan> out,
    List<InlineImage> images,
  ) {
    if (node is dom.Text) {
      final text = node.text;
      if (text.isNotEmpty) {
        buf.write(text);
        out.add(TextSpan(text: text, style: style));
      }
      return;
    }
    if (node is! dom.Element) return;
    final tag = node.localName;
    final childStyle = _inlineStyle(style, tag);
    final childOut = <InlineSpan>[];
    for (final child in node.nodes) {
      _walkInline(child, childStyle, buf, childOut, images);
    }
    if (childOut.isNotEmpty) {
      if (childOut.length == 1) {
        out.add(childOut.single);
      } else {
        out.add(TextSpan(style: childStyle, children: childOut));
      }
    }
  }

  TextStyle _inlineStyle(TextStyle base, String? tag) {
    switch (tag) {
      case 'em':
      case 'i':
        return base.copyWith(fontStyle: FontStyle.italic);
      case 'strong':
      case 'b':
        return base.copyWith(fontWeight: FontWeight.bold);
      case 'u':
        return base.copyWith(
            decoration: TextDecoration.combine(
                [base.decoration ?? TextDecoration.none, TextDecoration.underline]));
      case 'a':
        return base.copyWith(
            color: Colors.blue,
            decoration: TextDecoration.combine(
                [base.decoration ?? TextDecoration.none, TextDecoration.underline]));
      case 'code':
      case 'pre':
        return base.copyWith(fontFamily: 'monospace');
      default:
        return base;
    }
  }
}
