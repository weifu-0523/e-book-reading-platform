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
import '../../../gen_l10n/app_localizations.dart';
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
import '../../../data/local/daos/book_tags_dao.dart';
import '../models/book_filter.dart';
import '../pages/export_filter_page.dart';
import '../services/book_filter_applicator.dart';

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
  ///
  /// M2.7 (2026-07-07): BookPreprocessor 入口暂时禁用 per user decision.
  /// 用户决定 AI 只在主动调用时进入，不再"导入即批处理"。
  /// 表 `book_passages` 与代码 `book_preprocessor.dart` 保留以备未来恢复。
  /// 恢复方法：取消下方注释块即可，DAO/Provider/Controller 链路保持可用。
  static Future<void> handleImportResult(
    ProviderContainer container, {
    required String bookId,
    required bool isNew,
  }) async {
    // M2.7 (2026-07-07): BookPreprocessor disabled — keep body as no-op.
    // 当恢复"导入即批处理"时，把下面整块取消注释即可。
    // if (!isNew) return;
    // final db = container.read(appDatabaseProvider);
    // final row = await (db.select(db.books)
    //       ..where((t) => t.id.equals(bookId)))
    //     .getSingleOrNull();
    // if (row == null) return;
    // final book = Book.fromRow(row);
    // container
    //     .read(bookPreprocessControllerProvider(bookId).notifier)
    //     .start(book);
    await Future<void>.delayed(Duration.zero);
    return;
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

  /// ⋮ 菜单分发：read / details / notes 走路由，delete 跳详情页
  /// （删除 FAB 在那里）。
  ///
  /// M2.7 (2026-07-07): 原有 `case BookCellAction.aiGuide` 已移除 —— spec §5.7
  /// 决定 AI 入口统一到 reader 右侧抽屉。如需恢复，把对应 case 重新加回并
  /// 引回 `AiGuideSheet`/`AiGuideMode` import 即可。
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
      case BookCellAction.delete:
        // 删除入口在详情页 FAB（避免重复实现删除流程）。
        if (!mounted) return;
        unawaited(context.push('/book/${book.id}/details'));
    }
  }

  Future<void> _importBook() async {
    debugPrint('[import] _importBook: picker opening');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'pdf', 'md', 'markdown', 'txt'],
    );
    if (result == null) {
      debugPrint('[import] picker returned null (user canceled?)');
      return;
    }
    if (result.files.single.path == null) {
      debugPrint(
          '[import] picker returned file with null path: ${result.files.single}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件路径无效（path 为空）')),
      );
      return;
    }
    final path = result.files.single.path!;
    debugPrint('[import] picked path=$path');
    final importService = await ref.read(bookImportServiceProvider.future);
    if (!mounted) return;
    try {
      final importResult = await importService.importFile(File(path));
      debugPrint(
          '[import] importFile done: isNew=${importResult.isNew}, id=${importResult.book.id}, format=${importResult.book.format}');
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
    } on ArgumentError catch (e, st) {
      // 检测不到 PDF/EPUB magic bytes（可能文件损坏或扩展名被人为篡改）。
      debugPrint('[import] ArgumentError: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂不支持该文件格式')),
      );
    } catch (e, st) {
      // M4.6 instrument: 之前用户报告"TXT/MD 选完无反应"，原代码只 catch
      // ArgumentError，其他异常被静默吞掉。加宽 catch 捕获所有异常并打印
      // stack，下次复现时可通过 debugPrint 输出定位根因。
      debugPrint('[import] unexpected error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
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
  /// 流程（M2.3 新增筛选页）：
  /// 1. 拉取所有书 + 各书的 [BookNote]；若没有任何含内容的 note，弹「暂无
  ///    可导出内容」对话框并中止（避开 file_picker）。
  /// 2. 预取 tag 数据（allTags + per-book tags）。
  /// 3. 弹 [ExportFilterPage]；用户点底部按钮回 [BookFilter]，取消则回 null。
  /// 4. 应用 [applyBookFilter] → 子集；空子集静默中止。
  /// 5. [FilePicker.platform.getDirectoryPath] 选目标文件夹；用户取消即中止。
  /// 6. 弹 [BatchExportDialog] 跑 VaultExporter，完成后自动 pop。
  /// 7. SnackBar 反馈 + 「打开文件夹」action。
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

    // M2.3: 预取 tag 数据
    final db = ref.read(appDatabaseProvider);
    final bookTagsDao = BookTagsDao(db);
    final tagsByBookId = await bookTagsDao.allTagsByBook();
    final allTags = (await bookTagsDao.allTags()).toList()..sort();
    if (!mounted) return;

    // M2.3: 弹筛选页
    final filter = await showDialog<BookFilter?>(
      context: context,
      builder: (ctx) => ExportFilterPage(
        books: books,
        notesByBookId: notesByBookId,
        tagsByBookId: tagsByBookId,
        allTags: allTags,
        now: DateTime.now(),
        onApply: (f) => Navigator.of(ctx).pop(f),
      ),
    );
    if (filter == null) return;
    if (!mounted) return;

    final filteredBooks = applyBookFilter(
      books: books,
      filter: filter,
      tagsByBookId: tagsByBookId,
      now: DateTime.now(),
    );
    if (filteredBooks.isEmpty) return; // 筛选页已保证不会到这里，双保险

    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return;
    if (!mounted) return;

    VaultExportResult? result;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BatchExportDialog(
        targetDirPath: dirPath,
        books: filteredBooks,
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
