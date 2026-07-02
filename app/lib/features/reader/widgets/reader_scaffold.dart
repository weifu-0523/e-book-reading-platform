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
/// **paged 模式**支持四种翻页输入：
/// - **键盘**：←/→/↑/↓/PgUp/PgDn
/// - **鼠标滚轮**：向下滚动 → next；向上 → prev
/// - **水平拖拽**：左滑（负速度）→ next；右滑（正速度）→ prev
/// - **点击区域**：tap 左 1/3 → prev；右 1/3 → next；中央 → double-tap 检测
///
/// **scroll 模式**：所有翻页输入均被禁用（用户用滚动手势滚动内容）。
///
/// chrome 的显隐不再由中央 tap 控制（T6/T9 接管 chrome 默认值与切换 UI）。
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
    this.onBack,
    this.onOpenToc,
    this.onOpenTypography,
    this.onOpenNotes,
    this.onOpenAiGuide,
    this.onOpenQa,
    this.onOpenReview,
  });

  @override
  ConsumerState<ReaderScaffold> createState() => _ReaderScaffoldState();
}

class _ReaderScaffoldState extends ConsumerState<ReaderScaffold> {
  /// T9：手动 double-tap 检测的上一次中央 tap 时间戳。
  ///
  /// 不使用 [GestureDetector.onDoubleTap]：该回调会强制 GestureDetector
  /// 等待 double-tap 超时（~300ms）才识别为 single tap，破坏翻页响应。
  /// 这里在 [onTapUp] 内手动判断两次 tap 的时间差，仅影响中央 1/3 区域。
  DateTime? _lastCenterTap;

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(readerUiControllerProvider);
    final size = MediaQuery.sizeOf(context);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) => _handleKeyEvent(event),
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) =>
              _handleTap(details.localPosition.dx, size.width),
          onHorizontalDragEnd: _handleDragEnd,
          child: Stack(
            children: [
              widget.content,
              // T9：全屏模式下 chrome 默认隐藏；中央 double-tap 可临时唤出
              // （chromeVisible 由 [toggleChrome] 单独控制）。
              if (ui.chromeVisible) _buildChrome(context),
            ],
          ),
        ),
      ),
    );
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
              onPressed: widget.onBack ?? () => Navigator.maybePop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.list),
                tooltip: '目录',
                onPressed: widget.onOpenToc,
              ),
              IconButton(
                icon: const Icon(Icons.text_fields),
                tooltip: '排版',
                onPressed: widget.onOpenTypography,
              ),
              IconButton(
                icon: const Icon(Icons.menu_book),
                tooltip: '笔记',
                onPressed: widget.onOpenNotes,
              ),
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                tooltip: 'AI 导读',
                onPressed: widget.onOpenAiGuide,
              ),
              IconButton(
                icon: const Icon(Icons.quiz_outlined),
                tooltip: '问答',
                onPressed: widget.onOpenQa,
              ),
              // T9：全屏模式切换。全屏下 chrome 默认隐藏，需先通过中央
              // double-tap 唤出 chrome 才能点击此图标退出。
              IconButton(
                key: const Key('toggle_fullscreen'),
                icon: Icon(ui.isFullscreen
                    ? Icons.fullscreen_exit
                    : Icons.fullscreen),
                tooltip: ui.isFullscreen ? '退出全屏' : '全屏',
                onPressed: () => ref
                    .read(readerUiControllerProvider.notifier)
                    .toggleFullscreen(),
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

  /// T9：键盘事件处理。在全屏/翻页输入间协调：
  /// - **Esc**：若处于全屏，则退出全屏（任何 paginationMode）。
  /// - **F11**：切换全屏（任何 paginationMode）。
  /// - 方向键 / PgUp / PgDn：仅在 paged 模式下翻页（T5）。
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

    if (widget.paginationMode != PaginationMode.paged) {
      return KeyEventResult.ignored;
    }
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

  /// T9：中央 double-tap。全屏模式下临时切换 chromeVisible；非全屏模式下
  /// 空操作（chrome 显隐由 AppBar 全屏图标 + 平台默认值接管）。
  ///
  /// 在 [_handleTap] 内手动检测：连续两次中央区域 tap 间隔 < 300ms 即视为
  /// double-tap。不依赖 [GestureDetector.onDoubleTap] 以避免 single-tap
  /// 延迟（破坏翻页响应）。
  void _maybeHandleCenterDoubleTap() {
    final now = DateTime.now();
    final last = _lastCenterTap;
    _lastCenterTap = now;
    if (last == null) return;
    final delta = now.difference(last);
    if (delta.inMilliseconds > 300) return;

    final ui = ref.read(readerUiControllerProvider);
    if (ui.isFullscreen) {
      ref.read(readerUiControllerProvider.notifier).toggleChrome();
    }
  }

  void _handlePointerSignal(PointerSignalEvent signal) {
    if (widget.paginationMode != PaginationMode.paged) return;
    if (signal is! PointerScrollEvent) return;
    if (signal.scrollDelta.dy > 0) {
      widget.onTapNext();
    } else if (signal.scrollDelta.dy < 0) {
      widget.onTapPrev();
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (widget.paginationMode != PaginationMode.paged) return;
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

  void _handleTap(double dx, double width) {
    final third = width / 3;
    final isCenter = dx >= third && dx <= width - third;

    // T9：无论 paginationMode，中央 tap 都参与 double-tap 检测。
    if (isCenter) {
      _maybeHandleCenterDoubleTap();
    }

    if (widget.paginationMode == PaginationMode.scroll) {
      // Scroll mode: tap does nothing else (no paging, no chrome toggle).
      // Chrome visibility is controlled by the AppBar fullscreen icon (T9).
      return;
    }
    if (dx < third) {
      widget.onTapPrev();
    } else if (dx > width - third) {
      widget.onTapNext();
    }
    // Center third: only double-tap detection above. Single-tap no-op.
  }
}
