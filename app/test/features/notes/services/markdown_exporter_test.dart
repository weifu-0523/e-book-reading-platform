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

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/features/notes/services/markdown_exporter.dart';

void main() {
  // Use a fixed "now" for deterministic exported_at.
  final fixedNow = DateTime(2026, 6, 27, 14, 32, 0);

  Book makeBook() => Book(
        id: 'b1',
        title: '测试书名',
        author: '测试作者',
        format: BookFormat.epub,
        filePath: '/tmp/book.epub',
        fileHash: 'deadbeef',
        fileSizeBytes: 1024,
        coverPath: null,
        addedAt: DateTime(2026, 1, 1),
        lastReadAt: null,
      );

  Annotation makeHighlight({
    required String id,
    required String quote,
    String? note,
    HighlightColor color = HighlightColor.yellow,
    List<String> tags = const [],
    int chapterIndex = 0,
    String? chapterTitle,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Annotation(
      id: id,
      bookNoteId: 'b1',
      locator: EpubRangeLocator(
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        startOffset: 0,
        endOffset: quote.length,
        quote: quote,
      ),
      quote: quote,
      note: note,
      color: color,
      tags: tags,
      source: AnnotationSource.manual,
      createdAt: createdAt ?? DateTime(2026, 6, 20, 10, 0, 0),
      updatedAt: updatedAt ?? DateTime(2026, 6, 27, 14, 32, 0),
    );
  }

  group('MarkdownExporter.export', () {
    test('full template matches golden fixture', () {
      final book = makeBook();
      final note = BookNote(
        id: 'bn1',
        bookId: 'b1',
        title: '《测试书名》读书笔记',
        summary: '这是一段核心摘要。',
        keyTakeaways: const ['要点一', '要点二'],
        annotations: [
          makeHighlight(
            id: 'a1',
            quote: '第一条高亮原文。',
            note: '笔记内容',
            color: HighlightColor.yellow,
            tags: const ['心理学', '认知'],
            chapterIndex: 0,
            chapterTitle: '引言',
            createdAt: DateTime(2026, 6, 20, 10, 0, 0),
            updatedAt: DateTime(2026, 6, 27, 14, 32, 0),
          ),
          makeHighlight(
            id: 'a2',
            quote: '第二条高亮原文。',
            color: HighlightColor.red,
            tags: const [],
            chapterIndex: 1,
            chapterTitle: '论证',
            updatedAt: DateTime(2026, 6, 27, 14, 32, 0),
          ),
        ],
        createdAt: DateTime(2026, 6, 20),
        updatedAt: DateTime(2026, 6, 27, 14, 32, 0),
      );
      final markdown =
          MarkdownExporter.export(book: book, bookNote: note, now: fixedNow);
      final fixture =
          File('test/fixtures/markdown/full_template.md').readAsStringSync();
      expect(markdown, fixture);
    });

    test('empty summary omits 核心摘要 section', () {
      final book = makeBook();
      final note = BookNote(
        id: 'bn1',
        bookId: 'b1',
        title: '《测试书名》读书笔记',
        summary: '',
        keyTakeaways: const ['要点一'],
        annotations: [
          makeHighlight(
              id: 'a1',
              quote: '第一条高亮原文。',
              chapterTitle: '引言',
              tags: const ['认知']),
        ],
        createdAt: DateTime(2026, 6, 20),
        updatedAt: DateTime(2026, 6, 27),
      );
      final markdown =
          MarkdownExporter.export(book: book, bookNote: note, now: fixedNow);
      final fixture =
          File('test/fixtures/markdown/empty_summary.md').readAsStringSync();
      expect(markdown, fixture);
    });

    test('empty keyTakeaways omits 核心知识点 section', () {
      final book = makeBook();
      final note = BookNote(
        id: 'bn1',
        bookId: 'b1',
        title: '《测试书名》读书笔记',
        summary: '摘要内容。',
        keyTakeaways: const [],
        annotations: [
          makeHighlight(
              id: 'a1',
              quote: '第一条高亮原文。',
              chapterTitle: '引言',
              tags: const ['认知']),
        ],
        createdAt: DateTime(2026, 6, 20),
        updatedAt: DateTime(2026, 6, 27),
      );
      final markdown =
          MarkdownExporter.export(book: book, bookNote: note, now: fixedNow);
      final fixture = File('test/fixtures/markdown/empty_key_takeaways.md')
          .readAsStringSync();
      expect(markdown, fixture);
    });

    test('empty tags omits 标签 section and frontmatter tags', () {
      final book = makeBook();
      final note = BookNote(
        id: 'bn1',
        bookId: 'b1',
        title: '《测试书名》读书笔记',
        summary: '',
        keyTakeaways: const ['要点一'],
        annotations: [
          makeHighlight(
              id: 'a1',
              quote: '第一条高亮原文。',
              chapterTitle: '引言',
              tags: const []),
        ],
        createdAt: DateTime(2026, 6, 20),
        updatedAt: DateTime(2026, 6, 27),
      );
      final markdown =
          MarkdownExporter.export(book: book, bookNote: note, now: fixedNow);
      final fixture =
          File('test/fixtures/markdown/empty_tags.md').readAsStringSync();
      expect(markdown, fixture);
    });

    test('empty annotations renders minimal body', () {
      final book = makeBook();
      final note = BookNote(
        id: 'bn1',
        bookId: 'b1',
        title: '《测试书名》读书笔记',
        summary: '',
        keyTakeaways: const [],
        annotations: const [],
        createdAt: DateTime(2026, 6, 27),
        updatedAt: DateTime(2026, 6, 27),
      );
      final markdown =
          MarkdownExporter.export(book: book, bookNote: note, now: fixedNow);
      final fixture =
          File('test/fixtures/markdown/empty_annotations.md').readAsStringSync();
      expect(markdown, fixture);
    });

    test('no chapterTitle falls back to 第 N 章', () {
      final book = makeBook();
      final note = BookNote(
        id: 'bn1',
        bookId: 'b1',
        title: '《测试书名》读书笔记',
        summary: '',
        keyTakeaways: const [],
        annotations: [
          makeHighlight(
              id: 'a1', quote: 'X', chapterTitle: null, chapterIndex: 2),
        ],
        createdAt: DateTime(2026, 6, 27),
        updatedAt: DateTime(2026, 6, 27),
      );
      final markdown =
          MarkdownExporter.export(book: book, bookNote: note, now: fixedNow);
      expect(markdown, contains('### 第三章'));
    });

    test('escapes backslash and double-quote in YAML frontmatter', () {
      final book = Book(
        id: 'b1',
        title: r'Test "C:\Path"',
        author: r'Author "X"\Y',
        format: BookFormat.epub,
        filePath: '',
        fileHash: '',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: DateTime(2026, 1, 1),
        lastReadAt: null,
      );
      final note = BookNote(
        id: 'bn1',
        bookId: 'b1',
        title: 't',
        summary: '',
        keyTakeaways: const [],
        annotations: const [],
        createdAt: DateTime(2026, 6, 27),
        updatedAt: DateTime(2026, 6, 27),
      );
      final md = MarkdownExporter.export(
          book: book, bookNote: note, now: DateTime(2026, 6, 27));
      // Backslash escaped first, then quote.
      expect(md, contains(r'title: "Test \"C:\\Path\""'));
      expect(md, contains(r'author: "Author \"X\"\\Y"'));
    });

    test('color emoji mapping covers all 5 colors', () {
      for (final c in HighlightColor.values) {
        final book = makeBook();
        final note = BookNote(
          id: 'bn1',
          bookId: 'b1',
          title: 't',
          summary: '',
          keyTakeaways: const [],
          annotations: [
            makeHighlight(id: 'a1', quote: 'Q', color: c, chapterTitle: 'ch'),
          ],
          createdAt: DateTime(2026, 6, 27),
          updatedAt: DateTime(2026, 6, 27),
        );
        final md =
            MarkdownExporter.export(book: book, bookNote: note, now: fixedNow);
        final expectedEmoji = const {
          HighlightColor.yellow: '🟡',
          HighlightColor.green: '🟢',
          HighlightColor.blue: '🔵',
          HighlightColor.red: '🔴',
          HighlightColor.purple: '🟣',
        }[c]!;
        expect(md, contains(expectedEmoji));
      }
    });
  });

  group('MarkdownExporter.exportSingle', () {
    test('renders quote with color emoji + note + tags', () {
      final a = makeHighlight(
        id: 'a1',
        quote: '原文引用',
        note: '我的笔记',
        tags: const ['标签1', '标签2'],
        color: HighlightColor.blue,
      );
      final md = MarkdownExporter.exportSingle(a);
      expect(md, contains('> 🔵 原文引用'));
      expect(md, contains('- 💬 我的笔记'));
      expect(md, contains('- 🏷️ #标签1 #标签2'));
    });

    test('omits note and tags lines when not present', () {
      final a = makeHighlight(id: 'a1', quote: 'Q');
      final md = MarkdownExporter.exportSingle(a);
      expect(md, '> 🟡 Q');
      expect(md.contains('💬'), isFalse);
      expect(md.contains('🏷️'), isFalse);
    });

    test('chapterTitle renders as 📖 line', () {
      final a = makeHighlight(id: 'a1', quote: 'Q');
      final md = MarkdownExporter.exportSingle(a, chapterTitle: '第一章');
      expect(md, contains('- 📖 第一章'));
    });
  });
}
