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
import 'package:go_router/go_router.dart';

import '../../../core/responsive_layout_builder.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../sync/models/sync_status.dart';
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

  /// v1.11.9-alpha Bug 2: 当前同步状态。null 时不渲染同步按钮（调用方未
  /// 配置同步，如未登录）。提供时渲染 _SyncIconButton，状态自适应图标 +
  /// pushing/pulling 时旋转动画。
  final SyncStatus? syncStatus;

  /// v1.11.9-alpha Bug 2: 点击同步按钮的回调（通常调
  /// `syncControllerProvider.notifier.syncNow()`）。
  final VoidCallback? onSyncTap;

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
    this.syncStatus,
    this.onSyncTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final sizeClass = windowSizeClassOf(context);

    if (sizeClass == WindowSizeClass.compact) {
      return _buildCompactBar(context);
    }
    return _buildExpandedBar(context);
  }

  Widget _buildCompactBar(BuildContext context) {
    if (searching) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onExitSearch,
          tooltip: '退出搜索',
        ),
        title: TextField(
          controller: searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索书名/作者',
            border: InputBorder.none,
          ),
          onChanged: onSearch,
        ),
        actions: const [],
      );
    }
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu),
        tooltip: '菜单',
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
      title: const Text('智阅'),
      actions: [
        if (syncStatus != null)
          _SyncIconButton(status: syncStatus!, onPressed: onSyncTap),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: onImportTap,
          tooltip: '导入书籍',
        ),
        PopupMenuButton<_CompactAction>(
          icon: const Icon(Icons.more_vert),
          onSelected: (action) {
            switch (action) {
              case _CompactAction.search:
                onEnterSearch();
              case _CompactAction.tags:
                _showTagDialog(context);
              case _CompactAction.sort:
                _showSortDialog(context);
              case _CompactAction.toggleView:
                onViewModeChanged(
                  viewMode == ViewMode.grid ? ViewMode.list : ViewMode.grid,
                );
              case _CompactAction.batchExport:
                onBatchExport();
              case _CompactAction.aiSettings:
                context.push('/settings/ai');
              case _CompactAction.settings:
                context.push('/settings');
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: _CompactAction.search, child: Text('搜索')),
            PopupMenuItem(value: _CompactAction.tags, child: Text('标签筛选')),
            PopupMenuItem(value: _CompactAction.sort, child: Text('排序')),
            PopupMenuItem(value: _CompactAction.toggleView, child: Text('切换视图')),
            PopupMenuItem(value: _CompactAction.batchExport, child: Text('批量导出')),
            PopupMenuItem(value: _CompactAction.aiSettings, child: Text('AI 设置')),
            PopupMenuItem(value: _CompactAction.settings, child: Text('设置')),
          ],
        ),
      ],
    );
  }

  Widget _buildExpandedBar(BuildContext context) {
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
        if (syncStatus != null)
          _SyncIconButton(status: syncStatus!, onPressed: onSyncTap),
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
          icon: const Icon(Icons.smart_toy_outlined),
          tooltip: 'AI 设置',
          onPressed: () => context.push('/settings/ai'),
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

  void _showSortDialog(BuildContext context) {
    showDialog<SortBy>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('排序方式'),
        children: SortBy.values.map((s) {
          return SimpleDialogOption(
            onPressed: () {
              onSortChanged(s);
              Navigator.of(ctx).pop();
            },
            child: Text(
              _sortByLabel(s),
              style: TextStyle(
                fontWeight: s == sortBy ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _sortByLabel(SortBy s) {
    switch (s) {
      case SortBy.recentlyRead: return '最近阅读';
      case SortBy.addedDesc: return '添加时间';
      case SortBy.titleAsc: return '书名';
      case SortBy.authorAsc: return '作者';
      case SortBy.progressDesc: return '阅读进度';
      case SortBy.manual: return '手动排序';
    }
  }
}

enum _CompactAction { search, tags, sort, toggleView, batchExport, aiSettings, settings }

/// v1.11.9-alpha Bug 2: library AppBar 同步按钮。
///
/// 复用 SyncButton 的状态→图标 + 旋转动画逻辑，但渲染为 AppBar-friendly 的
/// IconButton（而非 FilledButton）。pushing/pulling 时旋转；offline/error
/// 禁用；success 显示 check；idle 显示 sync icon。
class _SyncIconButton extends StatefulWidget {
  const _SyncIconButton({required this.status, required this.onPressed});

  final SyncStatus status;
  final VoidCallback? onPressed;

  @override
  State<_SyncIconButton> createState() => _SyncIconButtonState();
}

class _SyncIconButtonState extends State<_SyncIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(covariant _SyncIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) _updateAnimation();
  }

  void _updateAnimation() {
    final isRunning = widget.status == SyncStatus.pushing ||
        widget.status == SyncStatus.pulling;
    if (isRunning) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = widget.status == SyncStatus.pushing ||
        widget.status == SyncStatus.pulling;
    final isDisabled = isRunning || widget.status == SyncStatus.offline;

    final icon = _iconForStatus(widget.status);
    return IconButton(
      tooltip: '立即同步',
      onPressed: isDisabled ? null : widget.onPressed,
      icon: isRunning
          ? RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0).animate(_controller),
              child: Icon(icon),
            )
          : Icon(icon),
    );
  }

  IconData _iconForStatus(SyncStatus status) {
    switch (status) {
      case SyncStatus.pushing:
      case SyncStatus.pulling:
        return Icons.sync;
      case SyncStatus.error:
        return Icons.error_outline;
      case SyncStatus.offline:
        return Icons.cloud_off;
      case SyncStatus.success:
        return Icons.check;
      case SyncStatus.idle:
        return Icons.sync;
    }
  }
}
