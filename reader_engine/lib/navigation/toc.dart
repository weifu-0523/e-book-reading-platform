import 'package:meta/meta.dart';

import '../core/locator.dart';

/// 单个目录项。
///
/// 一个章节/子章节的标题 + 跳转目标。
@immutable
class TocEntry {
  final String title;
  final Locator locator;
  final List<TocEntry> children;

  const TocEntry({
    required this.title,
    required this.locator,
    this.children = const [],
  });
}

/// 整本书的目录。
@immutable
class TableOfContents {
  final List<TocEntry> entries;

  const TableOfContents({required this.entries});

  factory TableOfContents.empty() => const TableOfContents(entries: []);
}
