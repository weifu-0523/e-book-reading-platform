// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../data/models/book.dart';
import '../../../data/models/book_note.dart';
import 'markdown_exporter.dart';
import 'note_file_writer.dart';

/// Outcome of a [VaultExporter.export] run.
///
/// - [booksExported]: count of books that produced a Markdown file (books
///   without notes / with empty notes are filtered out before the loop).
/// - [writtenFiles]: filenames (basenames, not absolute paths) written into
///   `targetDir`, in the order they were produced. Always ends with
///   `index.md`.
/// - [failures]: per-book errors caught during the loop — export continues
///   on error so a single bad book doesn't abort the whole batch.
/// - [wasCancelled]: true iff the user pressed cancel mid-export. When
///   true, [booksExported] reflects the partial count up to the cancel
///   point and `index.md` is still written (so partial output is usable).
///   Callers can use this to choose between "exported N books" and
///   "cancelled after N books" messaging.
class VaultExportResult {
  const VaultExportResult({
    required this.booksExported,
    required this.totalHighlights,
    required this.totalNotes,
    required this.writtenFiles,
    required this.failures,
    this.wasCancelled = false,
  });

  final int booksExported;
  final int totalHighlights;
  final int totalNotes;
  final List<String> writtenFiles;
  final List<VaultExportFailure> failures;
  final bool wasCancelled;
}

/// A single book that failed to export. The batch continues after recording.
class VaultExportFailure {
  const VaultExportFailure({
    required this.bookId,
    required this.bookTitle,
    required this.error,
  });

  final String bookId;
  final String bookTitle;
  final Object error;
}

/// Batch Markdown exporter for the entire library.
///
/// For each book with a non-empty [BookNote], writes a `<title> - 读书笔记.md`
/// file (delegating per-book rendering to [MarkdownExporter]) into `targetDir`,
/// then writes a single `index.md` with Obsidian wiki-links to every exported
/// note plus an aggregated tag cloud.
///
/// Design notes:
/// - Pure I/O: no `DateTime.now()` / `Directory.systemTemp` — both `now` and
///   `targetDir` are injected so the output is deterministic and testable.
/// - Overwrites existing files at the resolved path (the inverse of
///   [NoteFileWriter.saveMarkdownFile], which appends `(1)`/`(2)` to avoid
///   clobbering user-picked destinations). Batch export targets a dedicated
///   vault folder where idempotent overwrites are the desired behavior.
/// - Sorts by book title (ascending) so the index is stable across runs
///   regardless of insertion order.
class VaultExporter {
  /// Export [books] + [notesByBookId] into [targetDir].
  ///
  /// - Filters out books whose [BookNote] is missing or completely empty
  ///   (no summary, no key takeaways, no annotations).
  /// - Renders each surviving book via [MarkdownExporter.export] and writes
  ///   the result to `<targetDir>/<sanitized title> - 读书笔记.md`.
  /// - Writes `index.md` with frontmatter + wiki-links + tag cloud.
  /// - Reports progress via [onProgress] (1-based `current`, `total` equals
  ///   the post-filter book count, `bookTitle` is the raw title).
  static Future<VaultExportResult> export({
    required List<Book> books,
    required Map<String, BookNote> notesByBookId,
    required Directory targetDir,
    required DateTime now,
    void Function(int current, int total, String bookTitle)? onProgress,
  }) async {
    final filtered = books.where((b) {
      final n = notesByBookId[b.id];
      if (n == null) return false;
      final hasContent = n.summary.isNotEmpty ||
          n.keyTakeaways.isNotEmpty ||
          n.annotations.isNotEmpty;
      return hasContent;
    }).toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final writtenFiles = <String>[];
    final failures = <VaultExportFailure>[];
    var totalHighlights = 0;
    var totalNotes = 0;
    final allTags = <String>{};
    // Per-book deduped tag sets, computed once here and reused by
    // _buildIndex (which previously re-derived them per book).
    final bookTags = <String, Set<String>>{};

    for (var i = 0; i < filtered.length; i++) {
      final book = filtered[i];
      final note = notesByBookId[book.id]!;
      try {
        final markdown = MarkdownExporter.export(
          book: book,
          bookNote: note,
          now: now,
        );
        final filename =
            '${NoteFileWriter.sanitizeForFilename(book.title)} - 读书笔记.md';
        final filePath = p.join(targetDir.path, filename);
        await File(filePath).writeAsString(markdown);
        writtenFiles.add(filename);
        totalHighlights += note.annotations.length;
        totalNotes += note.annotations.where((a) => a.hasNote).length;
        final tags = note.annotations
            .expand((a) => a.tags)
            .toSet();
        bookTags[book.id] = tags;
        allTags.addAll(tags);
      } catch (e) {
        failures.add(VaultExportFailure(
          bookId: book.id,
          bookTitle: book.title,
          error: e,
        ));
      }
      onProgress?.call(i + 1, filtered.length, book.title);
    }

    final indexContent = _buildIndex(
      filtered: filtered,
      notesByBookId: notesByBookId,
      now: now,
      totalHighlights: totalHighlights,
      totalNotes: totalNotes,
      allTags: allTags,
      bookTags: bookTags,
    );
    final indexPath = p.join(targetDir.path, 'index.md');
    await File(indexPath).writeAsString(indexContent);
    writtenFiles.add('index.md');

    return VaultExportResult(
      booksExported: filtered.length,
      totalHighlights: totalHighlights,
      totalNotes: totalNotes,
      writtenFiles: writtenFiles,
      failures: failures,
    );
  }

  static String _buildIndex({
    required List<Book> filtered,
    required Map<String, BookNote> notesByBookId,
    required DateTime now,
    required int totalHighlights,
    required int totalNotes,
    required Set<String> allTags,
    required Map<String, Set<String>> bookTags,
  }) {
    final iso = _formatIso(now);
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final buf = StringBuffer()
      ..writeln('---')
      ..writeln('type: zhiyue-vault-index')
      ..writeln('exported_at: $iso')
      ..writeln('book_count: ${filtered.length}')
      ..writeln('total_highlights: $totalHighlights')
      ..writeln('total_notes: $totalNotes')
      ..writeln('---')
      ..writeln()
      ..writeln('# 我的智阅书架')
      ..writeln()
      ..writeln(
          '> 共 ${filtered.length} 本书 · $totalHighlights 条高亮 · $totalNotes 条笔记')
      ..writeln('> 导出时间：$dateStr')
      ..writeln()
      ..writeln('## 书目')
      ..writeln();

    for (final book in filtered) {
      final note = notesByBookId[book.id]!;
      final highlights = note.annotations.length;
      final notes = note.annotations.where((a) => a.hasNote).length;
      final fileBaseName =
          '${NoteFileWriter.sanitizeForFilename(book.title)} - 读书笔记';
      final tagsStr = (bookTags[book.id] ?? const <String>{})
          .map((t) => '#$t')
          .join(' ');
      final suffix = tagsStr.isEmpty ? '' : ' · $tagsStr';
      final noteLabel = highlights == 0 && notes == 0
          ? '（仅含 AI 回顾）'
          : '$highlights 高亮 / $notes 笔记';
      buf.writeln('- [[$fileBaseName|《${book.title}》]] — $noteLabel$suffix');
    }

    if (allTags.isNotEmpty) {
      final sortedTags = allTags.toList()..sort();
      buf
        ..writeln()
        ..writeln('## 标签云')
        ..writeln()
        ..writeln(sortedTags.map((t) => '#$t').join(' '));
    }

    return buf.toString();
  }

  static String _formatIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}'
      'T'
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}:'
      '${d.second.toString().padLeft(2, '0')}';
}
