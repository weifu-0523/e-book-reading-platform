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
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine_pdf_view/pdf_reader_engine.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../../features/ai/providers/book_preprocess_controller.dart';
import '../providers/notes_controller.dart';
import 'notes_drawer.dart';
import 'pdf_thumbnail_grid.dart';
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

    // M4.6/T5：PDF 无目录时改用缩略图 grid 导航（替代「本书无目录」空文案）。
    // 仅当 engine 是 PdfReaderEngine、TOC 为空且 doc 已打开时构造；
    // EPUB / PDF 有目录场景保持 null，沿用原 ListView 目录渲染。
    Widget? pdfThumbnails;
    if (engine is PdfReaderEngine && toc.entries.isEmpty) {
      final pdfEngine = engine as PdfReaderEngine;
      final doc = pdfEngine.rendererRef.doc;
      if (doc != null) {
        pdfThumbnails = PdfThumbnailGrid(
          document: doc,
          currentPage: pdfEngine.rendererRef.currentPage,
          onPageSelected: (idx) async {
            // idx 是 0-based；PdfPageLocator.page 是 1-based（pdfrx 约定）。
            await pdfEngine.gotoLocator(PdfPageLocator(
              page: idx + 1,
              offsetX: 0,
              offsetY: 0,
            ));
            // 对齐 onSelect 行为：跳转后关闭抽屉。PDF 无 chapterSwitchSettled
            // 语义（setPage 同步），无需 await。
            if (context.mounted) {
              Scaffold.of(context).closeDrawer();
            }
          },
        );
      }
    }

    return TocDrawer(
      toc: toc,
      preprocessState: preprocess,
      chapterIndexResolver: defaultTocChapterIndex,
      onSelect: (entry) async {
        await engine.gotoTocEntry(entry);
        // M2.10/Bug B2: 双页模式下 rebuild 触发 _buildPaged 的 LayoutBuilder
        // 重跑算新章分页；若不等 chapterSwitchSettled 就 closeDrawer，drawer
        // 提前关闭 + PageView 尚未完成新章布局 → TOC 跳转视觉卡住或 spread
        // 越界。reader_body 的 _awaitChapterSettledAndLayout 同理（它是私有
        // 方法，wrapper 拿不到，用公开 Future chapterSwitchSettled）。
        // TOC 跳转不像笔记那样需要 jumpToPage（落在首页即可），故不需
        // 额外 endOfFrame。
        await engine.chapterSwitchSettled;
        if (context.mounted) {
          Scaffold.of(context).closeDrawer();
        }
      },
      onReviewChapter: onReviewChapter,
      pdfThumbnails: pdfThumbnails,
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
    this.onAnnotationSecondaryTapDown,
    this.onAnnotationEdit,
    this.onAnnotationExport,
    this.onAnnotationDelete,
  });

  final Map<int, String> chapterTitles;
  final ValueChanged<String> onAnnotationTap;
  final ValueChanged<String> onAnnotationLongPress;

  /// M3e/Q7：摘录右键 + 可见操作按钮（按 id 委托回 reader_body）。
  final void Function(String id, Offset globalPosition)?
      onAnnotationSecondaryTapDown;
  final ValueChanged<String>? onAnnotationEdit;
  final ValueChanged<String>? onAnnotationExport;
  final ValueChanged<String>? onAnnotationDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesControllerProvider);
    return notesAsync.when(
      data: (s) => NotesDrawerContent(
        annotations: s.annotations,
        chapterTitles: chapterTitles,
        onTap: onAnnotationTap,
        onLongPress: onAnnotationLongPress,
        onClose: () => Navigator.of(context).maybePop(),
        onSecondaryTapDown: onAnnotationSecondaryTapDown,
        onEdit: onAnnotationEdit,
        onExport: onAnnotationExport,
        onDelete: onAnnotationDelete,
      ),
      loading: () => const LoadingView(),
      error: (e, _) =>
          ErrorView(message: AppLocalizations.of(context)!.notesLoadFailed),
    );
  }
}
