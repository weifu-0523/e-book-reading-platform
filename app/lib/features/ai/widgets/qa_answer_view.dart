import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../services/ai/qa_citation_parser.dart';

/// Renders the LLM Q&A answer with [ch=N] markers as tappable citations.
///
/// Stateful so the [TapGestureRecognizer]s attached to citation spans can be
/// disposed when the widget unmounts or when the answer text changes (streaming
/// updates). Stateless widgets leak recognizers per build because the framework
/// does not auto-dispose recognizers attached to TextSpan.recognizer.
class QaAnswerView extends StatefulWidget {
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
  State<QaAnswerView> createState() => _QaAnswerViewState();
}

class _QaAnswerViewState extends State<QaAnswerView> {
  final List<TapGestureRecognizer> _recognizers = [];
  List<InlineSpan> _children = const <InlineSpan>[];

  @override
  void initState() {
    super.initState();
    _rebuildSpans();
  }

  @override
  void didUpdateWidget(covariant QaAnswerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.answer != widget.answer) {
      _disposeRecognizers();
      _rebuildSpans();
    }
  }

  void _rebuildSpans() {
    final segments = QaCitationParser.parse(widget.answer);
    _recognizers.clear();
    final children = <InlineSpan>[];
    for (final s in segments) {
      switch (s) {
        case PlainSegment(:final text):
          children.add(TextSpan(text: text, style: widget.plainStyle));
        case CitationSegment(:final chapterIndex, :final marker):
          final rec = TapGestureRecognizer()
            ..onTap = () => widget.onCitationTap(chapterIndex);
          _recognizers.add(rec);
          children.add(TextSpan(
            text: marker,
            style: widget.citationStyle,
            recognizer: rec,
          ));
      }
    }
    _children = children;
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    // Merge base style on read so theme changes still propagate.
    final merged = _children
        .map((c) => c is TextSpan
            ? TextSpan(
                text: c.text,
                style: base.merge(c.style),
                recognizer: c.recognizer,
              )
            : c)
        .toList(growable: false);
    return RichText(text: TextSpan(children: merged));
  }
}
