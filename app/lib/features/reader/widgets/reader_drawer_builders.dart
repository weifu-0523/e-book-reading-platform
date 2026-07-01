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
import 'package:reader_engine/engine/reader_engine.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../../features/ai/providers/book_preprocess_controller.dart';
import '../providers/notes_controller.dart';
import 'notes_drawer.dart';
import 'toc_drawer.dart' show TocDrawer, defaultTocChapterIndex;

/// Drawer that wraps [TocDrawer] for the reader's `Scaffold.drawer` slot.
///
/// Extracted from `reader_body.dart` `_buildTocDrawer` so the host file
/// doesn't need to know about preprocess controller wiring or the
/// `closeDrawer` plumbing. The reader passes [onReviewChapter] only for
/// EPUB books (PDF callers pass null to suppress the review button).
class ReaderTocDrawerWrapper extends ConsumerWidget {
  const ReaderTocDrawerWrapper({
    super.key,
    required this.engine,
    required this.bookId,
    this.onReviewChapter,
  });

  final ReaderEngine engine;
  final String bookId;
  final ValueChanged<int>? onReviewChapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toc = engine.toc;
    if (toc == null) {
      return const Drawer(child: LoadingView());
    }
    final preprocess = ref.watch(bookPreprocessControllerProvider(bookId));
    return Drawer(
      child: TocDrawer(
        toc: toc,
        preprocessState: preprocess,
        chapterIndexResolver: defaultTocChapterIndex,
        onSelect: (entry) async {
          await engine.gotoTocEntry(entry);
          if (context.mounted) {
            Scaffold.of(context).closeDrawer();
          }
        },
        onReviewChapter: onReviewChapter,
      ),
    );
  }
}

/// Drawer that wraps [NotesDrawer] for the reader's `Scaffold.endDrawer`
/// slot. Reads from [notesControllerProvider] and forwards tap/long-press
/// callbacks to the host (the host owns the navigation + sheet logic).
class ReaderNotesDrawerWrapper extends ConsumerWidget {
  const ReaderNotesDrawerWrapper({
    super.key,
    required this.chapterTitles,
    required this.onAnnotationTap,
    required this.onAnnotationLongPress,
  });

  final Map<int, String> chapterTitles;
  final ValueChanged<String> onAnnotationTap;
  final ValueChanged<String> onAnnotationLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesControllerProvider);
    return notesAsync.when(
      data: (s) => NotesDrawer(
        annotations: s.annotations,
        chapterTitles: chapterTitles,
        onTap: onAnnotationTap,
        onLongPress: onAnnotationLongPress,
        onClose: () => Navigator.of(context).maybePop(),
      ),
      loading: () => const Drawer(child: LoadingView()),
      error: (e, _) => Drawer(
        child: ErrorView(message: AppLocalizations.of(context)!.notesLoadFailed),
      ),
    );
  }
}
