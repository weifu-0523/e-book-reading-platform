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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine_epub_view/reader_engine_epub_view.dart';

import '../../../core/providers.dart';
import '../providers/chapter_end_prompt_controller.dart';
import 'chapter_end_prompt_snackbar.dart';

/// Listener widget that owns [ChapterEndPromptController] lifecycle.
/// Renders nothing (`SizedBox.shrink()`); side effect is SnackBar emission
/// via [ScaffoldMessenger] when the source stream emits a visible event.
///
/// EPUB-only by type system: constructor requires [ConcreteEpubReaderEngine],
/// so the caller (ReaderBody) decides at build time whether to insert this
/// widget based on `engine is ConcreteEpubReaderEngine`.
///
/// Extracted from `reader_body.dart` (T2 of M2.4). Behavior identical to the
/// old in-state lazy-init block + listener + SnackBar helper trio.
class ReaderChapterEndPrompt extends ConsumerStatefulWidget {
  final ConcreteEpubReaderEngine engine;
  final String bookId;
  final void Function(int chapterIndex) onReview;
  final VoidCallback onNext;

  const ReaderChapterEndPrompt({
    super.key,
    required this.engine,
    required this.bookId,
    required this.onReview,
    required this.onNext,
  });

  @override
  ConsumerState<ReaderChapterEndPrompt> createState() =>
      _ReaderChapterEndPromptState();
}

class _ReaderChapterEndPromptState
    extends ConsumerState<ReaderChapterEndPrompt> {
  late final ChapterEndPromptController _controller;
  ChapterEndPromptVisibility _lastVisibility =
      ChapterEndPromptVisibility.hidden;

  @override
  void initState() {
    super.initState();
    _controller = ChapterEndPromptController(
      repo: ref.read(settingsRepositoryProvider),
      source: widget.engine.chapterEndEvents,
      bookId: widget.bookId,
    )..addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onStateChanged(ChapterEndPromptState state) {
    if (state.visibility == ChapterEndPromptVisibility.visible &&
        _lastVisibility != ChapterEndPromptVisibility.visible) {
      _lastVisibility = state.visibility;
      _showSnackBar(state);
    } else {
      _lastVisibility = state.visibility;
    }
  }

  void _showSnackBar(ChapterEndPromptState s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        ChapterEndPromptSnackBar(
          context: context,
          hasNext: s.hasNext,
          onReview: () {
            _controller.dismiss();
            widget.onReview(s.chapterIndex);
          },
          onNext: () {
            _controller.dismiss();
            widget.onNext();
          },
          onDismiss: () {
            _controller.dismiss();
          },
        ),
      );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
