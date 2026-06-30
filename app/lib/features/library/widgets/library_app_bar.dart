import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../gen_l10n/app_localizations.dart';
import '../models/sort_by.dart';
import '../models/view_mode.dart';

/// Library 主 AppBar。
/// 集成搜索、排序、视图切换、标签筛选、导入入口、批量 Markdown 导出。
/// [searching] 为 true 时 title 区显示搜索框，否则显示应用名。
class LibraryAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ViewMode viewMode;
  final SortBy sortBy;
  final Set<String> allTags;
  final Set<String> activeTagFilters;
  final ValueChanged<ViewMode> onViewModeChanged;
  final ValueChanged<SortBy> onSortChanged;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onTagFilterToggled;
  final VoidCallback onImportTap;
  final VoidCallback onEnterSearch;
  final VoidCallback onExitSearch;
  final VoidCallback onBatchExport;
  final bool searching;
  final TextEditingController? searchController;

  const LibraryAppBar({
    super.key,
    required this.viewMode,
    required this.sortBy,
    required this.allTags,
    required this.activeTagFilters,
    required this.onViewModeChanged,
    required this.onSortChanged,
    required this.onSearch,
    required this.onTagFilterToggled,
    required this.onImportTap,
    required this.onEnterSearch,
    required this.onExitSearch,
    required this.onBatchExport,
    this.searching = false,
    this.searchController,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: searching
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onExitSearch,
              tooltip: '退出搜索',
            )
          : null,
      title: searching
          ? TextField(
              controller: searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '搜索书名/作者',
                border: InputBorder.none,
              ),
              onChanged: onSearch,
            )
          : const Text('智阅'),
      actions: [
        if (!searching)
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: onEnterSearch,
            tooltip: '搜索',
          ),
        if (allTags.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.label_outline),
            onPressed: () => _showTagDialog(context),
            tooltip: '标签筛选',
          ),
        PopupMenuButton<SortBy>(
          icon: const Icon(Icons.sort),
          onSelected: onSortChanged,
          itemBuilder: (_) => const [
            PopupMenuItem(value: SortBy.recentlyRead, child: Text('最近阅读')),
            PopupMenuItem(value: SortBy.addedDesc, child: Text('添加时间')),
            PopupMenuItem(value: SortBy.titleAsc, child: Text('书名')),
            PopupMenuItem(value: SortBy.authorAsc, child: Text('作者')),
            PopupMenuItem(value: SortBy.progressDesc, child: Text('阅读进度')),
            PopupMenuItem(value: SortBy.manual, child: Text('手动排序')),
          ],
        ),
        IconButton(
          icon: Icon(viewMode == ViewMode.grid
              ? Icons.grid_view
              : Icons.view_list),
          onPressed: () => onViewModeChanged(
            viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid,
          ),
          tooltip: '切换视图',
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: onImportTap,
          tooltip: '导入书籍',
        ),
        IconButton(
          icon: const Icon(Icons.folder_zip_outlined),
          onPressed: onBatchExport,
          tooltip: AppLocalizations.of(context)!.batchExportMenuLabel,
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: '设置',
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }

  void _showTagDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            children: allTags.map((t) {
              final selected = activeTagFilters.contains(t);
              return FilterChip(
                label: Text(t),
                selected: selected,
                onSelected: (_) => onTagFilterToggled(t),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
