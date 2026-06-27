import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../models/library_mode.dart';
import '../models/library_state.dart';
import '../models/sort_by.dart';
import '../models/view_mode.dart';
import '../providers/cover_loader_provider.dart';
import '../providers/library_controller.dart';
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
    );
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
}
