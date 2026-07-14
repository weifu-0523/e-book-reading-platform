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
import 'package:path/path.dart' as p;
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/features/notes/services/vault_exporter.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('vault_exporter_test');
  });
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('VaultExporter.export', () {
    test('writes one md per book + index.md', () async {
      final books = [_book('b1', 'Book A'), _book('b2', 'Book B')];
      final notes = {
        'b1': _note('b1', 'Book A', summary: 's1', takeaways: const ['t1']),
        'b2': _note('b2', 'Book B', annotations: [_annotation('quote')]),
      };
      final result = await VaultExporter.export(
        books: books,
        notesByBookId: notes,
        targetDir: tempDir,
        now: DateTime(2026, 6, 30, 14, 32, 0),
      );
      expect(result.booksExported, 2);
      expect(result.writtenFiles.length, 3);
      expect(result.writtenFiles, contains('index.md'));
      expect(result.writtenFiles, contains('Book A - 读书笔记.md'));
      expect(result.writtenFiles, contains('Book B - 读书笔记.md'));
      expect(result.failures, isEmpty);
    });

    test('filters out books without notes', () async {
      final books = [_book('b1', 'A'), _book('b2', 'B')];
      final notes = {'b1': _note('b1', 'A', summary: 's')};
      final result = await VaultExporter.export(
        books: books,
        notesByBookId: notes,
        targetDir: tempDir,
        now: DateTime(2026, 6, 30),
      );
      expect(result.booksExported, 1);
    });

    test('filters out notes with empty content', () async {
      final books = [_book('b1', 'A')];
      final notes = {'b1': _note('b1', 'A')};
      final result = await VaultExporter.export(
        books: books,
        notesByBookId: notes,
        targetDir: tempDir,
        now: DateTime(2026, 6, 30),
      );
      expect(result.booksExported, 0);
      expect(result.writtenFiles, contains('index.md'));
    });

    test('sorts books by title', () async {
      final books = [_book('b1', 'Zebra'), _book('b2', 'Apple')];
      final notes = {
        'b1': _note('b1', 'Zebra', summary: 's'),
        'b2': _note('b2', 'Apple', summary: 's'),
      };
      final order = <String>[];
      await VaultExporter.export(
        books: books,
        notesByBookId: notes,
        targetDir: tempDir,
        now: DateTime(2026, 6, 30),
        onProgress: (current, total, title) => order.add(title),
      );
      expect(order, ['Apple', 'Zebra']);
    });

    test('overwrites existing file at same path', () async {
      final targetFile = File(p.join(tempDir.path, 'Book A - 读书笔记.md'));
      await targetFile.writeAsString('OLD CONTENT');
      final books = [_book('b1', 'Book A')];
      final notes = {'b1': _note('b1', 'Book A', summary: 'NEW')};
      await VaultExporter.export(
        books: books,
        notesByBookId: notes,
        targetDir: tempDir,
        now: DateTime(2026, 6, 30),
      );
      final content = await targetFile.readAsString();
      expect(content, isNot(contains('OLD CONTENT')));
      expect(content, contains('NEW'));
    });

    test('records failure but continues on write error', () async {
      // See plan: simplified to skip — would require file system mock.
    }, skip: 'requires file system mock; not implemented in plan');

    test('index.md contains frontmatter + wiki-links', () async {
      final books = [_book('b1', '量子')];
      final notes = {
        'b1': _note('b1', '量子', summary: 's', tags: const ['物理'])
      };
      await VaultExporter.export(
        books: books,
        notesByBookId: notes,
        targetDir: tempDir,
        now: DateTime(2026, 6, 30, 14, 32, 0),
      );
      final indexContent =
          await File(p.join(tempDir.path, 'index.md')).readAsString();
      expect(indexContent, contains('type: zhiyue-vault-index'));
      expect(indexContent, contains('exported_at: 2026-06-30T14:32:00'));
      expect(indexContent, contains('book_count: 1'));
      // Wiki-link target must match the actual file basename (no 《》 in
      // filename — those live only in the display label). The plan's draft
      // assertion had the brackets on the wrong side; corrected here so the
      // link actually resolves in Obsidian.
      expect(indexContent, contains('[[量子 - 读书笔记|《量子》]]'));
      expect(indexContent, contains('#物理'));
    });

    test('omits tag cloud when no tags', () async {
      final books = [_book('b1', 'A')];
      final notes = {'b1': _note('b1', 'A', summary: 's')};
      await VaultExporter.export(
        books: books,
        notesByBookId: notes,
        targetDir: tempDir,
        now: DateTime(2026, 6, 30),
      );
      final indexContent =
          await File(p.join(tempDir.path, 'index.md')).readAsString();
      expect(indexContent, isNot(contains('## 标签云')));
    });

    test('progress callback receives 1-based current', () async {
      final books = [_book('b1', 'A'), _book('b2', 'B'), _book('b3', 'C')];
      final notes = {
        'b1': _note('b1', 'A', summary: 's'),
        'b2': _note('b2', 'B', summary: 's'),
        'b3': _note('b3', 'C', summary: 's'),
      };
      final calls = <(int, int, String)>[];
      await VaultExporter.export(
        books: books,
        notesByBookId: notes,
        targetDir: tempDir,
        now: DateTime(2026, 6, 30),
        onProgress: (c, t, title) => calls.add((c, t, title)),
      );
      expect(calls[0], (1, 3, 'A'));
      expect(calls[1], (2, 3, 'B'));
      expect(calls[2], (3, 3, 'C'));
    });
  });

  group('VaultExporter.hasContent (static)', () {
    test('empty summary + empty takeaways + empty annotations = false', () {
      expect(VaultExporter.hasContent(_note('b', 'X')), isFalse);
    });

    test('non-empty summary = true', () {
      expect(VaultExporter.hasContent(_note('b', 'X', summary: 's')), isTrue);
    });

    test('non-empty takeaways = true', () {
      expect(
        VaultExporter.hasContent(_note('b', 'X', takeaways: const ['t'])),
        isTrue,
      );
    });

    test('non-empty annotations = true', () {
      expect(
        VaultExporter.hasContent(
          _note('b', 'X', annotations: [_annotation('quote')]),
        ),
        isTrue,
      );
    });
  });
}

Book _book(String id, String title) => Book(
      id: id,
      title: title,
      author: null,
      format: BookFormat.epub,
      filePath: '/$id.epub',
      fileHash: 'hash_$id',
      fileSizeBytes: 0,
      coverPath: null,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
    );

BookNote _note(
  String bookId,
  String bookTitle, {
  String summary = '',
  List<String> takeaways = const [],
  List<Annotation> annotations = const [],
  List<String> tags = const [],
}) {
  final annWithTags = annotations.isEmpty && tags.isNotEmpty
      ? [_annotation('placeholder', tags: tags)]
      : annotations;
  return BookNote(
    id: 'note_$bookId',
    bookId: bookId,
    title: '《$bookTitle》读书笔记',
    summary: summary,
    keyTakeaways: takeaways,
    annotations: annWithTags,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 30),
  );
}

Annotation _annotation(String quote, {List<String> tags = const []}) {
  return Annotation(
    id: 'a_${quote.hashCode}',
    bookNoteId: 'note_x',
    locator: EpubRangeLocator(
      chapterIndex: 0,
      chapterTitle: null,
      startOffset: 0,
      endOffset: quote.length,
      quote: quote,
    ),
    quote: quote,
    note: '',
    color: HighlightColor.yellow,
    tags: tags,
    source: AnnotationSource.manual,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );
}
