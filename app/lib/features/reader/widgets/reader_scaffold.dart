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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/rendering/pagination_model.dart';

import '../../../gen_l10n/app_localizations.dart';
import '../controllers/reader_ui_controller.dart';

/// 沉浸式阅读容器：多输入翻页 + chrome 显隐。
///
/// **翻页输入（所有模式均生效，M2.6/T1 lift 了 paginationMode 门控）：**
/// - **键盘**：←/→/↑/↓/PgUp/PgDn
/// - **水平拖拽**：左滑（负速度）→ next；右滑（正速度）→ prev
/// - **点击区域（M2.6/T9 book-like model）**：
///   - 左侧空白边（width = [marginPx]）tap → prev
///   - 右侧空白边（width = [marginPx]）tap → next
///   - 中央内容区 tap → 纯选择（不翻页），double-tap → chrome 切换
///
/// **scroll 模式仍保留：**
/// - **鼠标滚轮**：scroll 模式下不拦截（让内容 ScrollView 自然滚动）；
///   paged 模式下滚轮 = 上下翻页。
///
/// chrome 的显隐不再由中央 tap 控制（T6/T9 接管 chrome 默认值与切换 UI）。
///
/// **M2.6/T10 Focus 动态**：State 持有 [FocusNode]，所有 AppBar IconButton
/// onPressed 后调 [_reclaimFocus] 重新获焦，确保键盘事件（特别是 ESC 退出全屏）
/// 不会被按钮节点吞掉。
class ReaderScaffold extends ConsumerStatefulWidget {
  final Widget content;
  final VoidCallback onTapPrev;
  final VoidCallback onTapNext;
  final PaginationMode paginationMode;

  /// 显示在 chrome AppBar 中的标题（通常是书名）。
  final String title;

  /// 返回按钮回调（通常是 `Navigator.maybePop`）。
  final VoidCallback? onBack;

  /// 点击 TOC 图标回调（由父组件触发抽屉打开）。
  final VoidCallback? onOpenToc;

  /// 点击排版图标回调（由父组件触发 bottom sheet 打开）。
  final VoidCallback? onOpenTypography;

  /// 点击笔记图标回调（由父组件触发 endDrawer 打开）。
  final VoidCallback? onOpenNotes;

  /// 点击 AI 导读图标回调（由父组件触发 AiGuideSheet 弹出，章节模式）。
  final VoidCallback? onOpenAiGuide;

  /// 点击「问答」图标回调（由父组件触发 QaAskDialog 弹出）。
  final VoidCallback? onOpenQa;

  /// 点击「回顾本章」菜单项回调（由父组件触发 ReviewPreviewSheet 弹出）。
  ///
  /// 为 null 时不渲染溢出菜单。父组件（ReaderBody）对 PDF 书传入 null，
  /// 对 EPUB 书传入非空回调，从而实现「PDF 跳过」语义。
  final VoidCallback? onOpenReview;

  /// 点击「添加书签」图标回调（M2.5/T12）。弹出 ReaderBookmarkDialog，
  /// 用户确认后由本回调把 BookmarkEntry 写入数据库。为 null 时不渲染图标。
  final VoidCallback? onAddBookmark;

  /// M2.6/T9 (Bug #5a)：左右空白边的像素宽度，作为翻页 tap zone。
  ///
  /// 取自当前 `engine.typography.pageMargin.pixelValue`，由父组件
  /// reader_body 传入。M2.6/T4 后默认值 normal=32 / wide=48 / extraWide=64
  /// / compact=8。Normal 及以上满足 WCAG 最小 tap target。
  ///
  /// 边距同时承担两个职责：视觉留白 + 翻页命中区域。文字内容区（中央）
  /// 完全归 SelectableRegion 独享，不再与翻页手势竞争。
  final int marginPx;

  /// M2.6/T2 (Bug #4)：双页布局切换回调。仅 PDF 引擎提供（EPUB 渲染层
  /// 推到 v1.6）。null 时不渲染双页按钮。
  final VoidCallback? onToggleDualPage;

  /// M2.6/T2：当前是否处于双页模式（用于切换图标 + tooltip）。
  final bool isDualPageMode;

  /// 触发水平滑动翻页的最小速度阈值（px/s）。
  ///
  /// 测试中 `timedDrag(Offset(±300, 0), 200ms)` 的速度约为 1500 px/s，
  /// 远高于此阈值；用户实际滑动一般也 ≥ 300 px/s。
  static const double dragVelocityThreshold = 200.0;

  const ReaderScaffold({
    super.key,
    required this.content,
    required this.onTapPrev,
    required this.onTapNext,
    required this.title,
    this.paginationMode = PaginationMode.paged,
    this.marginPx = 32,
    this.onBack,
    this.onOpenToc,
    this.onOpenTypography,
    this.onOpenNotes,
    this.onOpenAiGuide,
    this.onOpenQa,
    this.onOpenReview,
    this.onAddBookmark,
    this.onToggleDualPage,
    this.isDualPageMode = false,
  });

  @override
  ConsumerState<ReaderScaffold> createState() => _ReaderScaffoldState();
}

class _ReaderScaffoldState extends ConsumerState<ReaderScaffold> {
  /// M2.6/T10 (Bug #9)：State 持有的 FocusNode，确保 AppBar IconButton
  /// 点击后能 [_reclaimFocus] 重新获焦，避免 ESC/F11/方向键被按钮节点吞掉。
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'ReaderScaffold');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// M2.6/T10：所有 AppBar IconButton onPressed 完成主操作后调本方法，
  /// 把焦点从按钮拉回到 ReaderScaffold，确保后续键盘事件可达。
  void _reclaimFocus() {
    if (mounted) _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(readerUiControllerProvider);
    final size = MediaQuery.sizeOf(context);
    // Tap zone width clamped to [0, half of screen] so a misconfigured
    // marginPx (e.g., > screen/2) doesn't cause the two zones to overlap.
    final zoneWidth = widget.marginPx.clamp(0, (size.width / 2).toInt());

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) => _handleKeyEvent(event),
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: Stack(
          children: [
            // 底层：内容（SelectableRegion 独享手势）
            widget.content,

            // T9 左空白边：tap = prev；水平拖拽同。
            if (zoneWidth > 0)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: zoneWidth.toDouble(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (_) => widget.onTapPrev(),
                  onHorizontalDragEnd: _handleDragEnd,
                ),
              ),

            // T9 右空白边：tap = next；水平拖拽同。
            if (zoneWidth > 0)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: zoneWidth.toDouble(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (_) => widget.onTapNext(),
                  onHorizontalDragEnd: _handleDragEnd,
                ),
              ),

            // T9 中央 double-tap（chrome 切换）：translucent，不消费 single tap，
            // 让 SelectableRegion 在文字选择时独享手势。
            Positioned(
              left: zoneWidth.toDouble(),
              right: zoneWidth.toDouble(),
              top: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTap: _toggleChrome,
              ),
            ),

            // Chrome 覆盖层（AppBar + actions）。
            if (ui.chromeVisible) _buildChrome(context),
          ],
        ),
      ),
    );
  }

  /// M2.6/T9：中央 double-tap 触发的 chrome 切换。
  ///
  /// 仅在全屏模式下生效：全屏时 chrome 默认隐藏，double-tap 临时唤出/隐藏；
  /// 非全屏时 chrome 由平台默认值（桌面 true / 移动 false）+ AppBar 全屏图标
  /// 接管，double-tap 不干预（保留 T9-5 测试期望的"非全屏 no-op"语义）。
  void _toggleChrome() {
    final ui = ref.read(readerUiControllerProvider);
    if (ui.isFullscreen) {
      ref.read(readerUiControllerProvider.notifier).toggleChrome();
    }
  }

  Widget _buildChrome(BuildContext context) {
    final ui = ref.watch(readerUiControllerProvider);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        key: const Key('reader_app_bar'),
        color: Colors.black54,
        child: SafeArea(
          child: AppBar(
            title: Text(widget.title),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                (widget.onBack ?? () => Navigator.maybePop(context))();
                _reclaimFocus();
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.list),
                tooltip: '目录',
                onPressed: widget.onOpenToc == null
                    ? null
                    : () {
                        widget.onOpenToc!.call();
                        _reclaimFocus();
                      },
              ),
              IconButton(
                icon: const Icon(Icons.text_fields),
                tooltip: '排版',
                onPressed: widget.onOpenTypography == null
                    ? null
                    : () {
                        widget.onOpenTypography!.call();
                        _reclaimFocus();
                      },
              ),
              IconButton(
                icon: const Icon(Icons.menu_book),
                tooltip: '笔记',
                onPressed: widget.onOpenNotes == null
                    ? null
                    : () {
                        widget.onOpenNotes!.call();
                        _reclaimFocus();
                      },
              ),
              // T12：添加书签。v1 不做「当前页已加书签」检测，统一显示
              // bookmark_add_outlined 图标，点击弹 dialog 录入 label + note。
              IconButton(
                key: const Key('toggle_bookmark'),
                icon: const Icon(Icons.bookmark_add_outlined),
                tooltip: '添加书签',
                onPressed: widget.onAddBookmark == null
                    ? null
                    : () {
                        widget.onAddBookmark!.call();
                        _reclaimFocus();
                      },
              ),
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                tooltip: 'AI 导读',
                onPressed: widget.onOpenAiGuide == null
                    ? null
                    : () {
                        widget.onOpenAiGuide!.call();
                        _reclaimFocus();
                      },
              ),
              IconButton(
                icon: const Icon(Icons.quiz_outlined),
                tooltip: '问答',
                onPressed: widget.onOpenQa == null
                    ? null
                    : () {
                        widget.onOpenQa!.call();
                        _reclaimFocus();
                      },
              ),
              // T9：全屏模式切换。全屏下 chrome 默认隐藏，需先通过中央
              // double-tap 唤出 chrome 才能点击此图标退出。
              IconButton(
                key: const Key('toggle_fullscreen'),
                icon: Icon(ui.isFullscreen
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen),
                tooltip: ui.isFullscreen ? '退出全屏' : '全屏',
                onPressed: () {
                  ref
                      .read(readerUiControllerProvider.notifier)
                      .toggleFullscreen();
                  _reclaimFocus();
                },
              ),
              // M2.6/T2 (Bug #4): PDF 双页独立切换按钮。仅 PDF 引擎时父组件
              // 传入回调；null 时不渲染。v1.5.1 不持久化，每次启动默认 false。
              if (widget.onToggleDualPage != null)
                IconButton(
                  key: const Key('toggle_dual_page'),
                  icon: Icon(widget.isDualPageMode
                      ? Icons.menu_book_outlined
                      : Icons.menu_book),
                  tooltip: widget.isDualPageMode ? '切到单页' : '切到双页',
                  onPressed: () {
                    widget.onToggleDualPage!();
                    _reclaimFocus();
                  },
                ),
              if (widget.onOpenReview != null)
                PopupMenuButton<String>(
                  key: const Key('reader_overflow_menu'),
                  icon: const Icon(Icons.more_vert),
                  tooltip:
                      AppLocalizations.of(context)!.reviewCurrentChapterMenuLabel,
                  onSelected: (value) {
                    if (value == 'review_current') {
                      widget.onOpenReview!();
                    }
                    _reclaimFocus();
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem<String>(
                      value: 'review_current',
                      child: ListTile(
                        leading: const Icon(Icons.rate_review_outlined),
                        title: Text(
                            AppLocalizations.of(ctx)!.reviewCurrentChapterMenuLabel),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// T9/T10：键盘事件处理。在全屏/翻页输入间协调：
  /// - **Esc**：若处于全屏，则退出全屏（任何 paginationMode，T9）。
  /// - **F11**：切换全屏（任何 paginationMode，T9）。
  /// - 方向键 / PgUp / PgDn：M2.6/T1 起，所有 paginationMode 均生效（不再
  ///   gated on paged 模式）。Engine.nextSpine/previousSpine 自己知道
  ///   scroll vs paged 模式下该如何步进。
  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // T9：F11 全屏切换（所有模式可用，便于 scroll 模式也能切换）。
    if (key == LogicalKeyboardKey.f11) {
      ref.read(readerUiControllerProvider.notifier).toggleFullscreen();
      return KeyEventResult.handled;
    }

    // T9：Esc 退出全屏（所有模式可用）。
    if (key == LogicalKeyboardKey.escape) {
      final ui = ref.read(readerUiControllerProvider);
      if (ui.isFullscreen) {
        ref.read(readerUiControllerProvider.notifier).toggleFullscreen();
        return KeyEventResult.handled;
      }
    }

    // M2.6/T1：移除 paginationMode gate。原先 PDF（scroll）模式下方向键被
    // 静默吞掉，用户报告"键盘左右键不能翻页"。
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.arrowDown) {
      widget.onTapNext();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.arrowUp) {
      widget.onTapPrev();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// T9：滚轮事件。**保留** paginationMode gate —— scroll 模式下应让内容
  /// ScrollView 自然滚动（用户的预期行为），不应转换为翻页。
  /// paged 模式下滚轮才翻页。
  void _handlePointerSignal(PointerSignalEvent signal) {
    if (widget.paginationMode != PaginationMode.paged) return;
    if (signal is! PointerScrollEvent) return;
    if (signal.scrollDelta.dy > 0) {
      widget.onTapNext();
    } else if (signal.scrollDelta.dy < 0) {
      widget.onTapPrev();
    }
  }

  /// M2.6/T1：水平拖拽翻页。**移除** paginationMode gate —— scroll 模式下
  /// 水平拖拽也应翻页（垂直滚动由内容 ScrollView 处理，不冲突）。
  void _handleDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity;
    if (v == null) return;
    // Swipe left (negative velocity) → next page.
    // Swipe right (positive velocity) → prev page.
    if (v < -ReaderScaffold.dragVelocityThreshold) {
      widget.onTapNext();
    } else if (v > ReaderScaffold.dragVelocityThreshold) {
      widget.onTapPrev();
    }
  }
}
