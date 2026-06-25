import 'package:meta/meta.dart';

import '../../core/locator.dart';

@immutable
class SearchResult {
  final String bookId;
  final String bookTitle;
  final Locator locator;
  final String snippet;
  final int matchCount;

  const SearchResult({
    required this.bookId,
    required this.bookTitle,
    required this.locator,
    required this.snippet,
    required this.matchCount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResult &&
          runtimeType == other.runtimeType &&
          bookId == other.bookId &&
          bookTitle == other.bookTitle &&
          locator == other.locator &&
          snippet == other.snippet &&
          matchCount == other.matchCount;

  @override
  int get hashCode =>
      Object.hash(bookId, bookTitle, locator, snippet, matchCount);
}
