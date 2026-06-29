import 'package:flutter/material.dart';

import '../../../services/ai/qa_citation_parser.dart';
import 'qa_citation_spans.dart';

/// Renders the LLM Q&A answer with [ch=N] markers as tappable citations.
///
/// Wraps [QaCitationParser.parse] + [buildQaCitationSpans] into a [RichText].
/// Plain text uses [plainStyle]; citations use [citationStyle] (blue underline
/// by default). Both styles are merged onto [DefaultTextStyle] so the answer
/// inherits the surrounding text scale + theme color when callers don't
/// override.
class QaAnswerView extends StatelessWidget {
  const QaAnswerView({
    super.key,
    required this.answer,
    required this.onCitationTap,
    this.plainStyle = const TextStyle(height: 1.5),
    this.citationStyle = const TextStyle(
      color: Color(0xFF1565C0),
      decoration: TextDecoration.underline,
    ),
  });

  final String answer;
  final void Function(int chapterIndex) onCitationTap;
  final TextStyle plainStyle;
  final TextStyle citationStyle;

  @override
  Widget build(BuildContext context) {
    final segments = QaCitationParser.parse(answer);
    final base = DefaultTextStyle.of(context).style;
    final spans = buildQaCitationSpans(
      segments,
      onCitationTap: onCitationTap,
      plainStyle: base.merge(plainStyle),
      citationStyle: base.merge(citationStyle),
    );
    return RichText(text: TextSpan(children: spans));
  }
}
