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

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/features/notes/services/markdown_exporter.dart';

void main() {
  final fixedNow = DateTime(2026, 6, 28, 9, 0, 0);

  Book makePdfBook() => Book(
        id: 'b-pdf',
        title: 'PDF 测试书',
        author: '某作者',
        format: BookFormat.pdf,
        filePath: '/tmp/doc.pdf',
        fileHash: 'cafe',
        fileSizeBytes: 2048,
        coverPath: null,
        addedAt: DateTime(2026, 1, 1),
        lastReadAt: null,
      );

  Annotation makePdfHighlight({
    required String id,
    required String quote,
    required int page,
    String? note,
    HighlightColor color = HighlightColor.yellow,
    List<String> tags = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Annotation(
      id: id,
      bookNoteId: 'b-pdf',
      locator: PdfRangeLocator(
        page: page,
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

  group('MarkdownExporter.export (PDF)', () {
    test('frontmatter contains format: pdf', () {
      final book = makePdfBook();
      final note = BookNote(
        id: 'bn',
        bookId: 'b-pdf',
        title: '《PDF 测试书》读书笔记',
        summary: '',
        keyTakeaways: const [],
        annotations: const [],
        createdAt: DateTime(2026, 6, 27),
        updatedAt: DateTime(2026, 6, 27),
      );
      final md =
          MarkdownExporter.export(book: book, bookNote: note, now: fixedNow);
      expect(md, contains('format: pdf'));
    });

    test('PDF highlight section uses 第 N 页 instead of 第 N 章', () {
      final book = makePdfBook();
      final note = BookNote(
        id: 'bn',
        bookId: 'b-pdf',
        title: '《PDF 测试书》读书笔记',
        summary: '',
        keyTakeaways: const [],
        annotations: [
          makePdfHighlight(id: 'a1', quote: 'page-five highlight', page: 5),
        ],
        createdAt: DateTime(2026, 6, 27),
        updatedAt: DateTime(2026, 6, 27),
      );
      final md =
          MarkdownExporter.export(book: book, bookNote: note, now: fixedNow);
      expect(md, contains('第 5 页'));
      // Must not accidentally emit "第 5 章" via the EPUB branch.
      expect(md, isNot(contains('第 5 章')));
      // The high-arity grouping marker — ensure EPUB's "第N章" template is not used.
      expect(md, isNot(contains('第五章')));
    });

    test('PDF frontmatter preserves per-highlight page metadata', () {
      final book = makePdfBook();
      final note = BookNote(
        id: 'bn',
        bookId: 'b-pdf',
        title: '《PDF 测试书》读书笔记',
        summary: '',
        keyTakeaways: const [],
        annotations: [
          makePdfHighlight(id: 'a1', quote: 'p7', page: 7),
          makePdfHighlight(id: 'a2', quote: 'p3', page: 3),
        ],
        createdAt: DateTime(2026, 6, 27),
        updatedAt: DateTime(2026, 6, 27),
      );
      final md =
          MarkdownExporter.export(book: book, bookNote: note, now: fixedNow);
      // Sorted ascending by page; p3 section precedes p7.
      final p3Idx = md.indexOf('第 3 页');
      final p7Idx = md.indexOf('第 7 页');
      expect(p3Idx, greaterThanOrEqualTo(0));
      expect(p7Idx, greaterThan(p3Idx));
    });

    test('EPUB path unchanged after PDF branch added', () {
      final book = Book(
        id: 'b-epub',
        title: 'EPUB 书',
        author: '作者',
        format: BookFormat.epub,
        filePath: '',
        fileHash: '',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: DateTime(2026, 1, 1),
        lastReadAt: null,
      );
      final note = BookNote(
        id: 'bn',
        bookId: 'b-epub',
        title: '《EPUB 书》读书笔记',
        summary: '',
        keyTakeaways: const [],
        annotations: [
          Annotation(
            id: 'a1',
            bookNoteId: 'b-epub',
            locator: const EpubRangeLocator(
              chapterIndex: 2,
              chapterTitle: '论证',
              startOffset: 0,
              endOffset: 4,
              quote: 'test',
            ),
            quote: 'test',
            note: null,
            color: HighlightColor.yellow,
            tags: const [],
            source: AnnotationSource.manual,
            createdAt: DateTime(2026, 6, 20),
            updatedAt: DateTime(2026, 6, 27),
          ),
        ],
        createdAt: DateTime(2026, 6, 27),
        updatedAt: DateTime(2026, 6, 27),
      );
      final md =
          MarkdownExporter.export(book: book, bookNote: note, now: fixedNow);
      expect(md, contains('format: epub'));
      // EPUB section header should use 第三章 (ordinal) not 第 3 页.
      expect(md, contains('第三章'));
      expect(md, isNot(contains('第 3 页')));
    });
  });
}
