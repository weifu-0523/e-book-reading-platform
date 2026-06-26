import '../../../data/models/annotation.dart';

class AnnotationSearchQuery {
  final String keyword;
  final List<String> tags;
  final HighlightColor? color;

  const AnnotationSearchQuery({
    required this.keyword,
    this.tags = const [],
    this.color,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnnotationSearchQuery) return false;
    if (keyword != other.keyword || color != other.color) return false;
    if (tags.length != other.tags.length) return false;
    return tags.every(other.tags.contains);
  }

  @override
  int get hashCode =>
      Object.hash(keyword, Object.hashAllUnordered(tags), color);
}
