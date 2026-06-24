import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../../core/locator.dart';

enum HighlightColor { yellow, green, blue, red, purple }

enum AnnotationSource { manual, aiAssisted }

@immutable
class Annotation {
  final String id;
  final String bookNoteId;
  final Locator locator;
  final String quote;
  final String? note;
  final HighlightColor color;
  final List<String> _tags;
  final AnnotationSource source;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Annotation({
    required this.id,
    required this.bookNoteId,
    required this.locator,
    required this.quote,
    required this.note,
    required this.color,
    required List<String> tags,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  }) : _tags = tags;

  bool get isHighlightOnly => note == null;
  bool get hasNote => note != null && note!.isNotEmpty;

  List<String> get tags => UnmodifiableListView(_tags);

  Annotation copyWith({
    String? note,
    HighlightColor? color,
    List<String>? tags,
    DateTime? updatedAt,
  }) {
    return Annotation(
      id: id,
      bookNoteId: bookNoteId,
      locator: locator,
      quote: quote,
      note: note ?? this.note,
      color: color ?? this.color,
      tags: tags ?? _tags,
      source: source,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
