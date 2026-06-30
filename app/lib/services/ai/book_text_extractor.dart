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

import '../../data/models/book.dart';

/// Raised when an extractor cannot produce any usable text
/// (e.g. EPUB with empty chapters, or a scanned/image-only PDF).
class EmptyTextException implements Exception {
  final String message;
  const EmptyTextException(this.message);
  @override
  String toString() => 'EmptyTextException: $message';
}

/// Strategy interface for pulling a flat plain-text blob out of a [Book].
///
/// The output is intended to feed downstream AI services
/// (tokenization, prompt building, summary generation) — it is NOT
/// a structured chapter representation (see T8 ChapterTextProvider
/// for chapter-scoped text).
abstract class BookTextExtractor {
  Future<String> extract(Book book);
}

/// EPUB implementation: reads the book with `epubx`, walks the chapter
/// tree (flattening sub-chapters), converts each chapter's HTML to plain
/// text via [PlainTextUtils.htmlToPlainWithOffsets], and joins with `\n`.
class EpubTextExtractor implements BookTextExtractor {
  EpubTextExtractor();

  @override
  Future<String> extract(Book book) async {
    final bytes = await File(book.filePath).readAsBytes();
    final epub = await EpubReader.readBook(bytes);
    final chapters = _flatten(epub.Chapters ?? const []);
    final buf = StringBuffer();
    for (final ch in chapters) {
      final html = ch.HtmlContent ?? '';
      if (html.isEmpty) continue;
      buf
        ..write(PlainTextUtils.htmlToPlainWithOffsets(html).$1)
        ..write('\n');
    }
    final text = buf.toString().trim();
    if (text.isEmpty) {
      throw const EmptyTextException('EPUB has no extractable text');
    }
    return text;
  }

  /// Depth-first flatten of the (potentially nested) chapter tree.
  List<EpubChapter> _flatten(List<EpubChapter> chapters) {
    final result = <EpubChapter>[];
    for (final c in chapters) {
      result
        ..add(c)
        ..addAll(_flatten(c.SubChapters ?? const []));
    }
    return result;
  }
}

/// PDF implementation: opens the file with pdfrx, loads each page's
/// text layer via `PdfPage.loadText()`, and joins with `\n`.
///
/// Image-only / scanned PDFs have no text layer and produce empty output,
/// in which case [EmptyTextException] is raised so callers can surface
/// a meaningful message to the user (mirrors the existing
/// `PdfScannedDetector` heuristic).
class PdfTextExtractor implements BookTextExtractor {
  PdfTextExtractor();

  @override
  Future<String> extract(Book book) async {
    final doc = await PdfDocument.openFile(book.filePath);
    try {
      final buf = StringBuffer();
      for (var i = 0; i < doc.pages.length; i++) {
        final raw = await doc.pages[i].loadText();
        buf
          ..write(raw?.fullText ?? '')
          ..write('\n');
      }
      final text = buf.toString().trim();
      if (text.isEmpty) {
        throw const EmptyTextException(
            'PDF has no text layer (likely a scan)');
      }
      return text;
    } finally {
      await doc.dispose();
    }
  }
}

/// Factory: returns the right extractor for the book's format.
BookTextExtractor extractorFor(Book book) {
  return book.format == BookFormat.epub
      ? EpubTextExtractor()
      : PdfTextExtractor();
}
