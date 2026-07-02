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

/// 注：T7 (M2.5) 起，抽屉由 [ReaderDrawer] 统一容器提供 `Drawer(...)` 外壳，
/// 这里的 wrapper 不再自行包裹 `Drawer(...)`，而是直接返回 tab body widget。
///
/// 历史上 `ReaderTocDrawerWrapper` 用于 reader 的 `Scaffold.drawer` 槽位，
/// 自带 `Drawer(...)` 包装；现在作为 [ReaderDrawer.tocBuilder] 的内容注入，
/// 外层 Drawer 由 [ReaderDrawer] 提供。
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
      return const LoadingView();
    }
    final preprocess = ref.watch(bookPreprocessControllerProvider(bookId));
    return TocDrawer(
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
    );
  }
}

/// 注：T7 (M2.5) 起，作为 [ReaderDrawer.notesBuilder] 的内容注入。
/// 外层 Drawer 由 [ReaderDrawer] 提供。
///
/// 历史上 `ReaderNotesDrawerWrapper` 用于 reader 的 `Scaffold.endDrawer`
/// 槽位，自带 `Drawer(...)` 包装；现已移除内部 `Drawer(...)` 外壳。
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
      loading: () => const LoadingView(),
      error: (e, _) =>
          ErrorView(message: AppLocalizations.of(context)!.notesLoadFailed),
    );
  }
}
