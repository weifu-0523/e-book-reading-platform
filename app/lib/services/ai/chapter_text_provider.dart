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

import 'package:epubx/epubx.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:reader_engine_epub_view/plain_text_utils.dart';

/// Provides chapter-scoped plain text for the AI guide.
///
/// EPUB: flatten chapters, take chapterIndex, strip HTML.
/// PDF: page-as-chapter mapping (page N = chapterIndex N).
abstract class ChapterTextProvider {
  /// Plain text for chapter at [chapterIndex] (0-based) in the book at [filePath].
  /// Returns null if index is out of range or chapter has no text.
  Future<String?> get(String filePath, int chapterIndex);

  /// Chapter title for prompt context, or null if unknown.
  Future<String?> title(String filePath, int chapterIndex);

  /// Total chapter count for the book at [filePath]. O(1) for EPUB (spine
  /// length) and PDF (page count). Replaces the O(N) linear probe.
  Future<int> count(String filePath);
}

class EpubChapterTextProvider implements ChapterTextProvider {
  EpubChapterTextProvider();

  Future<EpubBook> _read(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return EpubReader.readBook(bytes);
  }

  List<EpubChapter> _flatten(List<EpubChapter> chapters) {
    final result = <EpubChapter>[];
    for (final c in chapters) {
      result
        ..add(c)
        ..addAll(_flatten(c.SubChapters ?? const []));
    }
    return result;
  }

  @override
  Future<int> count(String filePath) async {
    final book = await _read(filePath);
    return _flatten(book.Chapters ?? const []).length;
  }

  @override
  Future<String?> get(String filePath, int chapterIndex) async {
    final book = await _read(filePath);
    final flat = _flatten(book.Chapters ?? const []);
    if (chapterIndex < 0 || chapterIndex >= flat.length) return null;
    final html = flat[chapterIndex].HtmlContent ?? '';
    final plain = PlainTextUtils.htmlToPlainWithOffsets(html).$1.trim();
    return plain.isEmpty ? null : plain;
  }

  @override
  Future<String?> title(String filePath, int chapterIndex) async {
    final book = await _read(filePath);
    final flat = _flatten(book.Chapters ?? const []);
    if (chapterIndex < 0 || chapterIndex >= flat.length) return null;
    return flat[chapterIndex].Title;
  }
}

class PdfChapterTextProvider implements ChapterTextProvider {
  PdfChapterTextProvider();

  @override
  Future<int> count(String filePath) async {
    final doc = await PdfDocument.openFile(filePath);
    try {
      return doc.pages.length;
    } finally {
      await doc.dispose();
    }
  }

  @override
  Future<String?> get(String filePath, int chapterIndex) async {
    final doc = await PdfDocument.openFile(filePath);
    try {
      if (chapterIndex < 0 || chapterIndex >= doc.pages.length) return null;
      final raw = await doc.pages[chapterIndex].loadText();
      final text = raw?.fullText.trim() ?? '';
      return text.isEmpty ? null : text;
    } finally {
      await doc.dispose();
    }
  }

  @override
  Future<String?> title(String filePath, int chapterIndex) async {
    // PDFs use page-as-chapter; per-page titles are not exposed.
    return null;
  }
}
