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
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../data/models/book.dart';
import '../../../data/models/book_note.dart';
import '../../../features/ai/providers/book_preprocess_controller.dart';
import '../../../features/ai/widgets/ai_guide_sheet.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../../services/ai/ai_guide.dart';
import '../../notes/services/vault_exporter.dart';
import '../models/library_mode.dart';
import '../models/library_state.dart';
import '../models/sort_by.dart';
import '../models/view_mode.dart';
import '../models/book_cell_action.dart';
import '../providers/cover_loader_provider.dart';
import '../providers/library_controller.dart';
import '../widgets/batch_export_dialog.dart';
import '../widgets/batch_selection_bar.dart';
import '../widgets/book_grid.dart';
import '../widgets/book_list_view.dart';
import '../widgets/empty_library_view.dart';
import '../widgets/library_app_bar.dart';

/// 书架主页：导入入口 + 浏览（grid/list） + 选择模式 + 排序/筛选。
///
/// 装配 M3.1 各组件：
/// - [LibraryAppBar]（搜索/排序/视图/标签/导入）→ [LibraryController] 状态变更
/// - 主体 [BookGrid] 或 [BookListView]：读取 state.books，按 bookId 解析封面
/// - 选择模式（长按进入）→ 底部 [BatchSelectionBar]
/// - 手动排序：sortBy == [SortBy.manual] 时启用 reorder
/// - 导入：[FilePicker] → [BookImportService] → snackbar 反馈
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  /// Called by the import flow after [BookImportService.importFile] completes.
  ///
  /// When [isNew] is true, kicks off background AI preprocessing for [bookId].
  /// Reads the [Book] row back from the database so the preprocessor sees the
  /// canonical record (including any fields the import service normalized).
  /// Static + [ProviderContainer]-based so unit tests can verify the trigger
  /// without pumping the full LibraryPage widget tree.
  ///
  /// No-op when:
  /// - [isNew] is false (dedup hit — book already exists in the library).
  /// - the row for [bookId] cannot be found (race with delete).
  static Future<void> handleImportResult(
    ProviderContainer container, {
    required String bookId,
    required bool isNew,
  }) async {
    if (!isNew) return;
    final db = container.read(appDatabaseProvider);
    final row = await (db.select(db.books)
          ..where((t) => t.id.equals(bookId)))
        .getSingleOrNull();
    if (row == null) return;
    final book = Book.fromRow(row);
    container
        .read(bookPreprocessControllerProvider(bookId).notifier)
        .start(book);
  }

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _enterSearch() {
    setState(() => _searching = true);
  }

  void _exitSearch() {
    setState(() => _searching = false);
    _searchController.clear();
    ref.read(libraryControllerProvider.notifier).setSearchQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryControllerProvider);
    final controller = ref.read(libraryControllerProvider.notifier);

    return Scaffold(
      appBar: LibraryAppBar(
        viewMode: state.viewMode,
        sortBy: state.sortBy,
        allTags: state.allTags,
        activeTagFilters: state.activeTagFilters,
        searching: _searching,
        searchController: _searchController,
        onViewModeChanged: controller.setViewMode,
        onSortChanged: controller.setSortBy,
        onSearch: controller.setSearchQuery,
        onTagFilterToggled: controller.toggleTagFilter,
        onImportTap: _importBook,
        onEnterSearch: _enterSearch,
        onExitSearch: _exitSearch,
        onBatchExport: _startBatchExport,
      ),
      body: _buildBody(context, state),
      bottomNavigationBar: state.mode == LibraryMode.selecting
          ? BatchSelectionBar(
              selectedCount: state.selectedIds.length,
              onDelete: _confirmBatchDelete,
              onSelectAll: () =>
                  controller.selectAll(state.books.map((b) => b.id)),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context, LibraryState state) {
    if (state.books.isEmpty) {
      return EmptyLibraryView(
        onImportTap: _importBook,
        mode: (state.searchQuery.isNotEmpty ||
                state.activeTagFilters.isNotEmpty)
            ? EmptyLibraryMode.noSearchResult
            : EmptyLibraryMode.empty,
      );
    }

    final controller = ref.read(libraryControllerProvider.notifier);
    final isSelecting = state.mode == LibraryMode.selecting;
    final manualSortEnabled = state.sortBy == SortBy.manual;

    File? coverResolver(String id) {
      final async = ref.watch(coverLoaderProvider(id));
      return async.maybeWhen(data: (f) => f, orElse: () => null);
    }

    PreprocessState? preprocessStateResolver(String id) {
      final s = ref.watch(bookPreprocessControllerProvider(id));
      return s.status == PreprocessStatus.idle ? null : s;
    }

    void onTap(String id) {
      if (isSelecting) {
        controller.toggleSelection(id);
      } else {
        context.push('/book/$id');
      }
    }

    Future<void> onLongPress(String id) async {
      if (isSelecting) {
        controller.toggleSelection(id);
        return;
      }
      // 非选择模式下，长按进入选择模式并选中该书
      controller.enterSelectionMode(id);
    }

    if (state.viewMode == ViewMode.grid) {
      return BookGrid(
        books: state.books,
        coverResolver: coverResolver,
        onTap: onTap,
        onLongPress: onLongPress,
        isSelectionMode: isSelecting,
        selectedIds: state.selectedIds,
        manualSortEnabled: manualSortEnabled,
        onReorder: controller.setManualSortOrder,
        onAction: _handleBookAction,
        preprocessStateResolver: preprocessStateResolver,
      );
    }
    return BookListView(
      books: state.books,
      coverResolver: coverResolver,
      onTap: onTap,
      onLongPress: onLongPress,
      isSelectionMode: isSelecting,
      selectedIds: state.selectedIds,
      manualSortEnabled: manualSortEnabled,
      onReorder: controller.setManualSortOrder,
      onAction: _handleBookAction,
      preprocessStateResolver: preprocessStateResolver,
    );
  }

  /// ⋮ 菜单分发：read / details / notes 走路由，aiGuide 弹 AiGuideSheet，
  /// delete 跳详情页（删除 FAB 在那里）。
  Future<void> _handleBookAction(BookCellAction action, Book book) async {
    switch (action) {
      case BookCellAction.read:
        if (!mounted) return;
        unawaited(context.push('/book/${book.id}'));
      case BookCellAction.details:
        if (!mounted) return;
        unawaited(context.push('/book/${book.id}/details'));
      case BookCellAction.notes:
        if (!mounted) return;
        unawaited(context.push('/book/${book.id}/notes'));
      case BookCellAction.aiGuide:
        if (!mounted) return;
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useRootNavigator: true,
          builder: (_) =>
              AiGuideSheet(book: book, initialMode: AiGuideMode.full),
        );
      case BookCellAction.delete:
        // 删除入口在详情页 FAB（避免重复实现删除流程）。
        if (!mounted) return;
        unawaited(context.push('/book/${book.id}/details'));
    }
  }

  Future<void> _importBook() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'pdf'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final importService = await ref.read(bookImportServiceProvider.future);
    if (!mounted) return;
    try {
      final importResult = await importService.importFile(File(path));
      if (!mounted) return;
      // Kick off background AI preprocessing for new books. Existing
      // duplicates are skipped so we don't redo completed work.
      await LibraryPage.handleImportResult(
        ProviderScope.containerOf(context),
        bookId: importResult.book.id,
        isNew: importResult.isNew,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(importResult.isNew
              ? '已导入：${importResult.book.title}'
              : '已在书库中：${importResult.book.title}'),
        ),
      );
    } on ArgumentError {
      // 检测不到 PDF/EPUB magic bytes（可能文件损坏或扩展名被人为篡改）。
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂不支持该文件格式')),
      );
    }
  }

  Future<void> _confirmBatchDelete() async {
    final controller = ref.read(libraryControllerProvider.notifier);
    final count = ref.read(libraryControllerProvider).selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量删除？'),
        content: Text('将删除 $count 本书，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '删除',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.batchDelete();
  }

  /// 批量导出整个书架的读书笔记为 Markdown 文件夹。
  ///
  /// 流程：
  /// 1. 拉取所有书 + 各书的 [BookNote]；若没有任何含内容的 note，弹「暂无
  ///    可导出内容」对话框并中止（避开 file_picker）。
  /// 2. 弹确认对话框（数量 + 取消/选择文件夹）。
  /// 3. [FilePicker.platform.getDirectoryPath] 选目标文件夹；用户取消即中止。
  /// 4. 弹 [BatchExportDialog] 跑 VaultExporter，完成后自动 pop。
  /// 5. SnackBar 反馈 + 「打开文件夹」action。
  Future<void> _startBatchExport() async {
    final books = await ref.read(bookRepositoryProvider).getAll();
    final notesByBookId = <String, BookNote>{};
    for (final book in books) {
      final note =
          await ref.read(notesRepositoryProvider).getNoteByBook(book.id);
      if (note != null) notesByBookId[book.id] = note;
    }
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    if (notesByBookId.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.batchExportNoNotesTitle),
          content: Text(l10n.batchExportNoNotesMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.reviewCancelButton),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.batchExportConfirmTitle),
        content: Text(l10n.batchExportConfirmMessage(notesByBookId.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.reviewCancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.batchExportOpenFolder),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return;
    if (!mounted) return;

    VaultExportResult? result;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BatchExportDialog(
        targetDirPath: dirPath,
        books: books,
        notesByBookId: notesByBookId,
        onCompleted: (r) {
          result = r;
          Navigator.of(ctx).pop();
        },
      ),
    );
    if (!mounted) return;
    final res = result;
    if (res == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_summarizeBatchResult(l10n, res, dirPath)),
        action: SnackBarAction(
          label: l10n.batchExportOpenFolder,
          onPressed: () => _openFolder(dirPath),
        ),
      ),
    );
  }

  String _summarizeBatchResult(
    AppLocalizations l10n,
    VaultExportResult result,
    String path,
  ) {
    if (result.wasCancelled) {
      return l10n.batchExportCancelled(result.booksExported, path);
    }
    if (result.failures.isEmpty) {
      return l10n.batchExportSuccess(result.booksExported, path);
    }
    return l10n.batchExportPartialFailure(
      result.booksExported,
      result.booksExported + result.failures.length,
      result.failures.length,
    );
  }

  Future<void> _openFolder(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {
      // 平台差异或路径缺失：失败静默，主流程已完成。
    }
  }
}
