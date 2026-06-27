import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/models/book_note.dart';

/// Pure-function Markdown export.
///
/// Same inputs always produce the same output — there are no `DateTime.now()`
/// calls; the current time is injected via [MarkdownExporter.export]'s `now`
/// parameter so golden tests are deterministic.
///
/// Output is Obsidian-compatible Markdown: YAML frontmatter followed by
/// conditional sections (summary, key takeaways, highlights grouped by
/// chapter, tags). Empty sections are omitted entirely.
class MarkdownExporter {
  /// Render the entire [bookNote] (with [book] metadata) as Obsidian-compatible
  /// Markdown. Conditional sections are omitted when their source data is
  /// empty.
  static String export({
    required Book book,
    required BookNote bookNote,
    required DateTime now,
  }) {
    final annotations = bookNote.annotations.toList()
      ..sort((a, b) {
        final ai = _chapterIndexOf(a);
        final bi = _chapterIndexOf(b);
        if (ai != bi) return ai.compareTo(bi);
        return a.createdAt.compareTo(b.createdAt);
      });

    final totalHighlights = annotations.length;
    final totalNotes = annotations.where((a) => a.hasNote).length;
    final tags = _collectAllTags(annotations);

    final createdDates = annotations.map((a) => a.createdAt).toList()..sort();
    final updatedDates = annotations.map((a) => a.updatedAt).toList()..sort();
    final readingStarted = createdDates.isEmpty ? null : createdDates.first;
    final readingEnded = updatedDates.isEmpty ? null : updatedDates.last;

    // Frontmatter
    final buf = StringBuffer()
      ..writeln('---')
      ..writeln('title: "${_escapeYaml(book.title)}"');
    if (book.author != null && book.author!.isNotEmpty) {
      buf.writeln('author: "${_escapeYaml(book.author!)}"');
    }
    buf
      ..writeln('source: "${_sourceLabel(book.format)}"')
      // M4/T13: explicit lowercase format tag for machine-readable routing
      // (Obsidian/Bear plugins key off `format:` to switch renderers; `source:`
      // is kept as a human-readable alias for backward-compat with existing
      // fixtures).
      ..writeln('format: ${_formatKey(book.format)}')
      ..writeln('exported_at: ${_formatIso(now)}')
      ..writeln('total_highlights: $totalHighlights')
      ..writeln('total_notes: $totalNotes')
      ..writeln(
          'reading_started: ${readingStarted == null ? 'null' : _formatIso(readingStarted)}')
      ..writeln(
          'reading_ended: ${readingEnded == null ? 'null' : _formatIso(readingEnded)}')
      ..writeln('tags: [${tags.map(_escapeYaml).join(', ')}]')
      ..writeln('---')
      ..writeln()
      // Title
      ..writeln('# 《${book.title}》读书笔记')
      ..writeln();

    // Reading summary line
    final startedStr =
        readingStarted == null ? '（暂无）' : _formatDate(readingStarted);
    final endedStr = readingEnded == null ? '（暂无）' : _formatDate(readingEnded);
    buf
      ..writeln('> 阅读时间：$startedStr ~ $endedStr')
      ..writeln('> 共 $totalHighlights 条高亮 · $totalNotes 条笔记')
      ..writeln();

    // 核心摘要 (conditional)
    if (bookNote.summary.isNotEmpty) {
      buf
        ..writeln('## 核心摘要')
        ..writeln()
        ..writeln(bookNote.summary)
        ..writeln();
    }

    // 核心知识点 (conditional)
    if (bookNote.keyTakeaways.isNotEmpty) {
      buf
        ..writeln('## 核心知识点')
        ..writeln();
      for (final k in bookNote.keyTakeaways) {
        buf.writeln('- $k');
      }
      buf.writeln();
    }

    // 高亮与笔记 (always present)
    buf
      ..writeln('## 高亮与笔记')
      ..writeln();

    if (annotations.isEmpty) {
      buf
        ..writeln('（暂无高亮）')
        ..writeln();
    } else {
      for (final entry in _groupByChapter(annotations).entries) {
        buf
          ..writeln('### ${entry.key}')
          ..writeln();
        for (final a in entry.value) {
          buf.writeln('> ${_colorEmoji(a.color)} ${a.quote}');
          if (a.hasNote) {
            buf.writeln('- 💬 ${a.note}');
            // Tags are surfaced as a sibling bullet only on annotated
            // highlights — bare highlights expose their tags only via the
            // aggregated `## 标签` section at the bottom of the document.
            if (a.tags.isNotEmpty) {
              buf.writeln('- 🏷️ ${a.tags.map((t) => '#$t').join(' ')}');
            }
          }
          buf.writeln();
        }
      }
    }

    // 标签 (conditional) — emitted together with the `---` separator.
    // When tags are empty, the document ends with the highlight block's
    // trailing blank line (no separator, no tags section).
    if (tags.isNotEmpty) {
      buf
        ..writeln('---')
        ..writeln()
        ..writeln('## 标签')
        ..writeln()
        ..write(tags.map((t) => '#$t').join(' '))
        ..writeln();
    }

    return buf.toString();
  }

  /// Render a single annotation as a Markdown fragment (clipboard use).
  /// (T5 will add tests for this; implementation included now to avoid
  /// an extra round trip.)
  static String exportSingle(Annotation annotation, {String? chapterTitle}) {
    final buf = StringBuffer()
      ..writeln('> ${_colorEmoji(annotation.color)} ${annotation.quote}');
    if (annotation.hasNote) {
      buf.writeln('- 💬 ${annotation.note}');
      if (annotation.tags.isNotEmpty) {
        buf.writeln('- 🏷️ ${annotation.tags.map((t) => '#$t').join(' ')}');
      }
    }
    if (chapterTitle != null) {
      buf.writeln('- 📖 $chapterTitle');
    }
    return buf.toString().trimRight();
  }

  // ---- helpers ----

  static int _chapterIndexOf(Annotation a) {
    final loc = a.locator;
    if (loc is PdfRangeLocator) return loc.page;
    if (loc is EpubRangeLocator) return loc.chapterIndex;
    if (loc is EpubCfiLocator) return loc.chapterIndex;
    return 0;
  }

  static String _chapterKey(Annotation a) {
    final loc = a.locator;
    if (loc is PdfRangeLocator) {
      // PDF 高亮永远落在单页内，page 即为分组键；章节概念不适用。
      return '第 ${loc.page} 页';
    }
    int? chapterIndex;
    String? chapterTitle;
    if (loc is EpubRangeLocator) {
      chapterIndex = loc.chapterIndex;
      chapterTitle = loc.chapterTitle;
    } else if (loc is EpubCfiLocator) {
      chapterIndex = loc.chapterIndex;
      chapterTitle = loc.chapterTitle;
    } else {
      return '未分类';
    }
    final ordinal = _chineseOrdinal(chapterIndex + 1);
    if (chapterTitle != null && chapterTitle.isNotEmpty) {
      return '第$ordinal章 · $chapterTitle';
    }
    return '第$ordinal章';
  }

  /// 1→一, 2→二, …, 10→十, 11→十一, …, 20→二十, 21→二十一, …
  /// Supports 1-99 (sufficient for chapter ordinals). For ≥100 returns
  /// the decimal string (no chapter list will realistically reach 100).
  static String _chineseOrdinal(int n) {
    if (n >= 100) return n.toString();
    const digits = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
    if (n == 10) return '十';
    if (n < 10) return digits[n];
    final tens = n ~/ 10;
    final ones = n % 10;
    final tensStr = tens == 1 ? '十' : '${digits[tens]}十';
    final onesStr = ones == 0 ? '' : digits[ones];
    return '$tensStr$onesStr';
  }

  static Map<String, List<Annotation>> _groupByChapter(
      List<Annotation> annotations) {
    final map = <String, List<Annotation>>{};
    for (final a in annotations) {
      map.putIfAbsent(_chapterKey(a), () => []).add(a);
    }
    return map;
  }

  static List<String> _collectAllTags(List<Annotation> annotations) {
    final set = <String>{};
    for (final a in annotations) {
      set.addAll(a.tags);
    }
    return set.toList()..sort();
  }

  static String _colorEmoji(HighlightColor c) {
    switch (c) {
      case HighlightColor.yellow:
        return '🟡';
      case HighlightColor.green:
        return '🟢';
      case HighlightColor.blue:
        return '🔵';
      case HighlightColor.red:
        return '🔴';
      case HighlightColor.purple:
        return '🟣';
    }
  }

  static String _sourceLabel(BookFormat f) =>
      f == BookFormat.epub ? 'EPUB' : 'PDF';

  /// Lowercase machine-readable format tag (matches [BookFormat.name]).
  /// Distinct from [_sourceLabel] which is a human-readable alias.
  static String _formatKey(BookFormat f) =>
      f == BookFormat.epub ? 'epub' : 'pdf';

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// ISO-8601 without milliseconds and without trailing 'Z'.
  /// `DateTime(2026,6,27,14,32,0)` → `2026-06-27T14:32:00`.
  static String _formatIso(DateTime d) =>
      '${_formatDate(d)}T'
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}:'
      '${d.second.toString().padLeft(2, '0')}';

  /// Escape backslash first (so injected escapes aren't double-escaped), then
  /// double-quote. YAML double-quoted strings treat `\` as escape char.
  static String _escapeYaml(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}
