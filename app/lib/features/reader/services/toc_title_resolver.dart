import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/navigation/toc.dart';

/// Flattens a [TableOfContents] into a `{chapterIndex: title}` map.
///
/// Walk algorithm: depth-first traversal. For each [TocEntry]:
/// - If `entry.locator is EpubCfiLocator`, register
///   `loc.chapterIndex -> entry.title`.
/// - Skip non-EpubCfiLocator entries (e.g., EpubRangeLocator).
/// - Duplicate chapterIndex: depth-first first-wins (matches reader order).
class TocTitleResolver {
  static Map<int, String> resolve(TableOfContents? toc) {
    if (toc == null) return {};
    final map = <int, String>{};
    void walk(List<TocEntry> entries) {
      for (final e in entries) {
        final loc = e.locator;
        if (loc is EpubCfiLocator) {
          map.putIfAbsent(loc.chapterIndex, () => e.title);
        }
        walk(e.children);
      }
    }

    walk(toc.entries);
    return map;
  }
}
