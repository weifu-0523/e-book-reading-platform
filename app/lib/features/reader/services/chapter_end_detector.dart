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

import 'dart:async';

import 'package:reader_engine_epub_view/reader_engine_epub_view.dart';

/// Per-session dedup wrapper around the renderer's chapter-end stream.
///
/// First visit to a (bookId, chapterIndex) pair emits a [PromptRequest];
/// subsequent visits in the same app session are suppressed. The Set is
/// process-lifetime (cleared on app restart, not on book close).
///
/// Detector takes the source stream as constructor arg (dependency injection)
/// so it doesn't need to know about PdfReaderEngine vs ConcreteEpubReaderEngine.
/// reader_body decides whether to create a detector at all (PDF: no detector).
class ChapterEndDetector {
  ChapterEndDetector({
    required Stream<ChapterEndEvent> source,
    required String bookId,
  })  : _source = source,
        _bookId = bookId;

  final Stream<ChapterEndEvent> _source;
  final String _bookId;
  final Set<String> _shownKeys = <String>{};
  final StreamController<PromptRequest> _controller =
      StreamController<PromptRequest>.broadcast();
  StreamSubscription<ChapterEndEvent>? _sub;

  Stream<PromptRequest> get promptRequests => _controller.stream;

  /// Idempotent: first call subscribes; subsequent calls are no-ops.
  void start() {
    _sub ??= _source.listen(_onEvent);
  }

  void _onEvent(ChapterEndEvent event) {
    final key = '$_bookId:${event.chapterIndex}';
    if (_shownKeys.contains(key)) return;
    _shownKeys.add(key);
    _controller.add(PromptRequest(
      bookId: _bookId,
      chapterIndex: event.chapterIndex,
      hasNext: !event.isLastChapter,
    ));
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}

/// Emitted by [ChapterEndDetector] when a chapter-end event passes dedup.
class PromptRequest {
  const PromptRequest({
    required this.bookId,
    required this.chapterIndex,
    required this.hasNext,
  });

  final String bookId;
  final int chapterIndex;
  final bool hasNext;
}
