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
}
