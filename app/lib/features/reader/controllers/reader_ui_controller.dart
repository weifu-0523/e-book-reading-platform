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

import '../../../core/platform_info.dart';
import 'fullscreen_controller.dart';

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

  /// T9：是否处于全屏模式。进入全屏时 [chromeVisible] 被置为 false；
  /// 退出全屏时按平台默认值（桌面=true，移动=false）恢复。
  final bool isFullscreen;

  const ReaderUiState({
    this.chromeVisible = false,
    this.tocDrawerOpen = false,
    this.typographyPanelOpen = false,
    this.activeDrawerTab = DrawerTab.toc,
    this.tocSidebarCollapsed = false,
    this.isFullscreen = false,
  });

  /// 平台相关的默认状态：桌面端 chrome 默认可见，移动端默认隐藏
  /// （移动端走全屏模式，由 T9 接管）。
  ///
  /// I2 (2026-07-11): 改用 [PlatformInfo.isDesktop] 替代 raw
  /// `defaultTargetPlatform` 比较。
  factory ReaderUiState.defaults() {
    return ReaderUiState(
      chromeVisible: PlatformInfo.isDesktop,
      tocDrawerOpen: false,
      typographyPanelOpen: false,
      activeDrawerTab: DrawerTab.toc,
      tocSidebarCollapsed: false,
      isFullscreen: false,
    );
  }

  /// 跨平台一致的初始化默认值（spec §2.2 UX-B）。
  ///
  /// chrome 在所有平台开局可见，确保用户打开书籍就能看到 AppBar（目录 /
  /// 排版 / AI 等入口）。移动端不再"开局全黑无提示"。移动端的 3s 自动隐藏
  /// 定时器（Task 6）会在用户无交互时把 chrome 收回隐藏态；桌面端保持可见。
  ///
  /// 与 [defaults] 的区别：[defaults] 用于桌面锚点 backward compat（仍按
  /// `defaultTargetPlatform` 区分，桌面=true / 移动=false）。新初始化路径
  /// （Task 4 readerUiControllerProvider）应改用本工厂。
  factory ReaderUiState.defaultsForPlatform() {
    return ReaderUiState.defaults().copyWith(chromeVisible: true);
  }

  ReaderUiState copyWith({
    bool? chromeVisible,
    bool? tocDrawerOpen,
    bool? typographyPanelOpen,
    DrawerTab? activeDrawerTab,
    bool? tocSidebarCollapsed,
    bool? isFullscreen,
  }) {
    return ReaderUiState(
      chromeVisible: chromeVisible ?? this.chromeVisible,
      tocDrawerOpen: tocDrawerOpen ?? this.tocDrawerOpen,
      typographyPanelOpen: typographyPanelOpen ?? this.typographyPanelOpen,
      activeDrawerTab: activeDrawerTab ?? this.activeDrawerTab,
      tocSidebarCollapsed:
          tocSidebarCollapsed ?? this.tocSidebarCollapsed,
      isFullscreen: isFullscreen ?? this.isFullscreen,
    );
  }

  /// I1 (2026-07-11): value equality so Riverpod StateNotifier can skip
  /// emitting when `copyWith` produces an identical state. Without this,
  /// every copyWith triggers a rebuild even when no field actually changed.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReaderUiState &&
          runtimeType == other.runtimeType &&
          chromeVisible == other.chromeVisible &&
          tocDrawerOpen == other.tocDrawerOpen &&
          typographyPanelOpen == other.typographyPanelOpen &&
          activeDrawerTab == other.activeDrawerTab &&
          tocSidebarCollapsed == other.tocSidebarCollapsed &&
          isFullscreen == other.isFullscreen;

  @override
  int get hashCode => Object.hash(
        chromeVisible,
        tocDrawerOpen,
        typographyPanelOpen,
        activeDrawerTab,
        tocSidebarCollapsed,
        isFullscreen,
      );
}

class ReaderUiController extends StateNotifier<ReaderUiState> {
  /// T9：注入平台全屏实现。生产环境由 provider 按 [defaultTargetPlatform]
  /// 选择，测试用 [NoopFullscreenController]。
  final FullscreenController fullscreenController;

  ReaderUiController({
    required this.fullscreenController,
    ReaderUiState? initialState,
  }) : super(initialState ?? ReaderUiState.defaults());

  void toggleChrome() => state = state.copyWith(chromeVisible: !state.chromeVisible);

  /// 无条件将 chromeVisible 置为 false。
  ///
  /// 用于 UX-B 移动端 3s 自动隐藏定时器：定时器到期必须总是隐藏，
  /// 而非 toggle 翻转。当已是 false 时为幂等 no-op（copyWith 不抛错）。
  void hideChrome() => state = state.copyWith(chromeVisible: false);

  void openTocDrawer() => state = state.copyWith(tocDrawerOpen: true);
  void closeTocDrawer() => state = state.copyWith(tocDrawerOpen: false);
  void openTypographyPanel() => state = state.copyWith(typographyPanelOpen: true);
  void closeTypographyPanel() => state = state.copyWith(typographyPanelOpen: false);
  void setActiveDrawerTab(DrawerTab tab) =>
      state = state.copyWith(activeDrawerTab: tab);

  /// T8：切换宽屏 sidebar 折叠/展开。仅对宽屏布局有意义。
  void toggleSidebarCollapsed() => state = state.copyWith(
      tocSidebarCollapsed: !state.tocSidebarCollapsed);

  /// T9：切换全屏模式。
  ///
  /// 进入全屏 → 调用 [FullscreenController.enter] 并隐藏 chrome。
  /// 退出全屏 → 调用 [FullscreenController.exit] 并按平台默认值恢复 chrome
  /// （桌面可见，移动隐藏）。
  void toggleFullscreen() {
    final next = !state.isFullscreen;
    if (next) {
      fullscreenController.enter();
      state = state.copyWith(isFullscreen: true, chromeVisible: false);
    } else {
      fullscreenController.exit();
      // I2 (2026-07-11): PlatformInfo.isDesktop respects
      // debugDefaultTargetPlatformOverride for tests.
      state = state.copyWith(
          isFullscreen: false, chromeVisible: PlatformInfo.isDesktop);
    }
  }
}

/// Provider：按 [defaultTargetPlatform] 注入对应 [FullscreenController]。
/// 测试可通过 [StateNotifierProvider.overrideWith] 替换为
/// [NoopFullscreenController]，断言纯状态机迁移。
final readerUiControllerProvider =
    StateNotifierProvider<ReaderUiController, ReaderUiState>((ref) {
  final platform = defaultTargetPlatform;
  final FullscreenController fc;
  if (platform == TargetPlatform.windows ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.linux) {
    fc = const DesktopFullscreenController();
  } else if (platform == TargetPlatform.android ||
      platform == TargetPlatform.iOS) {
    fc = const MobileFullscreenController();
  } else {
    fc = const NoopFullscreenController();
  }
  return ReaderUiController(
    fullscreenController: fc,
    initialState: ReaderUiState.defaultsForPlatform(),
  );
});
