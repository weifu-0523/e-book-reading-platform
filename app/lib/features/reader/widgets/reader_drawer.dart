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

import '../../../data/local/database.dart';
import '../controllers/reader_ui_controller.dart';
import 'reader_bookmark_list.dart';

/// 统一的 3-tab 抽屉（目录 / 书签 / 笔记）。T7 起替代旧的
/// `Scaffold.drawer` (TOC) + `Scaffold.endDrawer` (Notes) 分体结构。
///
/// 设计要点：
/// - 通过 [tocBuilder] / [notesBuilder] 注入 tab body，避免本 widget 依赖
///   `ReaderEngine` 和 annotation 回调（让 reader_body 继续持有）。
/// - [onSwitchTab] 在用户点击 tab 时通知宿主，宿主应同时调用
///   `ref.read(readerUiControllerProvider.notifier).setActiveDrawerTab(tab)`
///   以更新规范状态（通常 onSwitchTab 就是该调用的转发）。
/// - 选中 tab 的真实源是 [ReaderUiState.activeDrawerTab]，[initialTab]
///   仅作为 controller 不可用时的兜底（极少见，比如单元测试）。
/// - 使用自定义 TextButton 行而非 [TabBar]+[TabController]，避免在 Drawer
///   里嵌套 DefaultTabController 带来的 animation/vsync 复杂度。
/// - [standalone]：默认 `false`，本 widget 返回 [Drawer] widget（用于
///   `Scaffold.drawer` 槽）。当 `true` 时返回 Column 主体（不包 Drawer），
///   供 T8 宽屏永久 sidebar 直接嵌入侧栏列（避免 Drawer 的宽度约束）。
class ReaderDrawer extends ConsumerWidget {
  const ReaderDrawer({
    super.key,
    required this.bookId,
    this.initialTab,
    required this.tocBuilder,
    required this.notesBuilder,
    required this.onSwitchTab,
    required this.onBookmarkJump,
    this.standalone = false,
  });

  final String bookId;
  final DrawerTab? initialTab;
  final WidgetBuilder tocBuilder;
  final WidgetBuilder notesBuilder;
  final ValueChanged<DrawerTab> onSwitchTab;

  /// 用户在书签 tab 内点击书签条目时的回调。透传给 [ReaderBookmarkList.onJump]。
  /// reader_body 通过此回调拿到 [BookmarkEntry] 后反序列化 locator 并调用
  /// `engine.gotoLocator` + 关闭抽屉。
  final ValueChanged<BookmarkEntry> onBookmarkJump;
  final bool standalone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(readerUiControllerProvider);
    final tab = initialTab ?? ui.activeDrawerTab;

    final Widget body;
    switch (tab) {
      case DrawerTab.toc:
        body = tocBuilder(context);
        break;
      case DrawerTab.bookmarks:
        body = ReaderBookmarkList(bookId: bookId, onJump: onBookmarkJump);
        break;
      case DrawerTab.notes:
        body = notesBuilder(context);
        break;
    }

    final Widget child = Column(
      children: [
        _DrawerTabBar(current: tab, onTap: onSwitchTab),
        Expanded(child: body),
      ],
    );

    if (standalone) {
      // 宽屏 sidebar 路径：直接返回 Column 主体。外层 sidebar 容器
      // （Material + 主题 surface 色）由调用方负责。
      return child;
    }
    return Drawer(width: 280, child: child);
  }
}

class _DrawerTabBar extends StatelessWidget {
  const _DrawerTabBar({required this.current, required this.onTap});

  final DrawerTab current;
  final ValueChanged<DrawerTab> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          for (final tab in DrawerTab.values)
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: current == tab
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
                onPressed: () => onTap(tab),
                child: Text(_tabLabel(tab)),
              ),
            ),
        ],
      ),
    );
  }
}

String _tabLabel(DrawerTab tab) {
  switch (tab) {
    case DrawerTab.toc:
      return '目录';
    case DrawerTab.bookmarks:
      return '书签';
    case DrawerTab.notes:
      return '笔记';
  }
}
