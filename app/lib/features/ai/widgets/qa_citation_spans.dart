import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../services/ai/qa_citation_parser.dart';

/// Convert [segments] into a list of InlineSpans for use in RichText or
/// Text.rich. PlainSegments become plain TextSpans with [plainStyle];
/// CitationSegments become TextSpans with [citationStyle] and a
/// TapGestureRecognizer that calls [onCitationTap] with the cited chapter
/// index.
///
/// Callers must dispose gesture recognizers when the widget is unmounted
/// — wrap RichText in a StatefulWidget and dispose in dispose, or use
/// Text.rich inside a builder that recreates the spans each build.
List<InlineSpan> buildQaCitationSpans(
  List<TextSegment> segments, {
  required void Function(int chapterIndex) onCitationTap,
  required TextStyle plainStyle,
  required TextStyle citationStyle,
}) {
  return [
    for (final s in segments)
      switch (s) {
        PlainSegment(:final text) => TextSpan(text: text, style: plainStyle),
        CitationSegment(:final chapterIndex, :final marker) => TextSpan(
            text: marker,
            style: citationStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => onCitationTap(chapterIndex),
          ),
      },
  ];
}
