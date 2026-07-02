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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reader drawer 统一抽屉的 tab 选项（T7 起 drawer/endDrawer 合并为单 Drawer）。
enum DrawerTab { toc, bookmarks, notes }

/// 阅读 UI 的瞬时状态（不持久化）：chrome 显隐、抽屉、排版面板。
@immutable
class ReaderUiState {
  final bool chromeVisible;
  final bool tocDrawerOpen;
  final bool typographyPanelOpen;
  final DrawerTab activeDrawerTab;

  /// T8：宽屏（>=1100px）下 TOC sidebar 是否折叠。`true` 表示当前为
  /// 40px 折叠态；`false`（默认）为 280px 展开态。窄屏路径不受此字段影响。
  final bool tocSidebarCollapsed;

  const ReaderUiState({
    this.chromeVisible = false,
    this.tocDrawerOpen = false,
    this.typographyPanelOpen = false,
    this.activeDrawerTab = DrawerTab.toc,
    this.tocSidebarCollapsed = false,
  });

  /// 平台相关的默认状态：桌面端 chrome 默认可见，移动端默认隐藏
  /// （移动端走全屏模式，由 T9 接管）。
  factory ReaderUiState.defaults() {
    final platform = defaultTargetPlatform;
    final isDesktop = platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
    return ReaderUiState(
      chromeVisible: isDesktop,
      tocDrawerOpen: false,
      typographyPanelOpen: false,
      activeDrawerTab: DrawerTab.toc,
      tocSidebarCollapsed: false,
    );
  }

  ReaderUiState copyWith({
    bool? chromeVisible,
    bool? tocDrawerOpen,
    bool? typographyPanelOpen,
    DrawerTab? activeDrawerTab,
    bool? tocSidebarCollapsed,
  }) {
    return ReaderUiState(
      chromeVisible: chromeVisible ?? this.chromeVisible,
      tocDrawerOpen: tocDrawerOpen ?? this.tocDrawerOpen,
      typographyPanelOpen: typographyPanelOpen ?? this.typographyPanelOpen,
      activeDrawerTab: activeDrawerTab ?? this.activeDrawerTab,
      tocSidebarCollapsed:
          tocSidebarCollapsed ?? this.tocSidebarCollapsed,
    );
  }
}

class ReaderUiController extends StateNotifier<ReaderUiState> {
  ReaderUiController() : super(ReaderUiState.defaults());

  void toggleChrome() => state = state.copyWith(chromeVisible: !state.chromeVisible);
  void openTocDrawer() => state = state.copyWith(tocDrawerOpen: true);
  void closeTocDrawer() => state = state.copyWith(tocDrawerOpen: false);
  void openTypographyPanel() => state = state.copyWith(typographyPanelOpen: true);
  void closeTypographyPanel() => state = state.copyWith(typographyPanelOpen: false);
  void setActiveDrawerTab(DrawerTab tab) =>
      state = state.copyWith(activeDrawerTab: tab);

  /// T8：切换宽屏 sidebar 折叠/展开。仅对宽屏布局有意义。
  void toggleSidebarCollapsed() => state = state.copyWith(
      tocSidebarCollapsed: !state.tocSidebarCollapsed);
}

final readerUiControllerProvider =
    StateNotifierProvider<ReaderUiController, ReaderUiState>((ref) {
  return ReaderUiController();
});
