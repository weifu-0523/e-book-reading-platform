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

    final blockTags = const {'p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li'};
    final bodyChildren = doc.body?.nodes ?? const <dom.Node>[];
    final blockElements = <dom.Element>[
      for (final n in bodyChildren)
        if (n is dom.Element && blockTags.contains(n.localName)) n,
    ];
    // Also flatten <ul>/<ol> direct children into the block list.
    final listTags = const {'ul', 'ol'};
    final listElements = <dom.Element>[
      for (final n in bodyChildren)
        if (n is dom.Element && listTags.contains(n.localName)) n,
    ];
    for (final list in listElements) {
      final items = list.querySelectorAll('li');
      for (final li in items) {
        blockElements.add(li);
      }
    }

    for (var i = 0; i < blockElements.length; i++) {
      final el = blockElements[i];
      final tag = el.localName;
      final start = buf.length;

      // Prefix for list items.
      String? prefix;
      TextStyle? headingStyle;
      if (tag == 'li') {
        // Determine parent <ol>/<ul> and index.
        final parent = el.parent;
        if (parent?.localName == 'ol') {
          final siblings = parent!.querySelectorAll('li');
          final idx = siblings.indexOf(el) + 1;
          prefix = '$idx. ';
        } else {
          prefix = '• ';
        }
      } else if (tag != null && tag.startsWith('h')) {
        final level = int.tryParse(tag.substring(1)) ?? 1;
        final sizeScale = switch (level) {
          1 => 1.5,
          2 => 1.3,
          3 => 1.15,
          4 => 1.0,
          5 => 0.95,
          _ => 0.85,
        };
        headingStyle = baseStyle.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: (baseStyle.fontSize ?? 16) * sizeScale,
        );
      }

      if (prefix != null) {
        buf.write(prefix);
      }
      final effectiveStyle = headingStyle ?? _inlineStyle(baseStyle, tag);
      final paraChildren = <InlineSpan>[];
      if (prefix != null) {
        paraChildren.add(TextSpan(text: prefix, style: effectiveStyle));
      }
      // Walk block element's child nodes directly (no wrapping span).
      for (final child in el.nodes) {
        _walkInline(child, effectiveStyle, buf, paraChildren, images, imageMaxHeight);
      }
      final end = buf.length;
      ranges.add(ParaRange(start, end));
      children.add(TextSpan(style: effectiveStyle, children: paraChildren));
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
    double imageMaxHeight,
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
    if (tag == 'img') {
      final src = node.attributes['src'] ?? '';
      final w = int.tryParse(node.attributes['width'] ?? '') ?? 0;
      final h = int.tryParse(node.attributes['height'] ?? '') ?? 0;
      images.add(InlineImage(src, w, h));
      buf.write('￼'); // OBJECT REPLACEMENT CHARACTER (U+FFFC)
      out.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: imageMaxHeight),
          child: Image.network(
            src,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ));
      return;
    }
    final childStyle = _inlineStyle(style, tag);
    final childOut = <InlineSpan>[];
    for (final child in node.nodes) {
      _walkInline(child, childStyle, buf, childOut, images, imageMaxHeight);
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
