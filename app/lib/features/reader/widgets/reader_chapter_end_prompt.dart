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
import 'package:reader_engine_epub_view/reader_engine_epub_view.dart';

import '../../../core/providers.dart';
import '../providers/chapter_end_prompt_controller.dart';
import 'chapter_end_prompt_snackbar.dart';

/// Listener widget that owns [ChapterEndPromptController] lifecycle.
/// Renders nothing (`SizedBox.shrink()`); side effect is SnackBar emission
/// via [ScaffoldMessenger] when the source stream emits a visible event.
///
/// EPUB-only by type system: constructor requires [ConcreteEpubReaderEngine],
/// so the caller (ReaderBody) decides at build time whether to insert this
/// widget based on `engine is ConcreteEpubReaderEngine`.
///
/// Extracted from `reader_body.dart` (T2 of M2.4). Behavior identical to the
/// old in-state lazy-init block + listener + SnackBar helper trio.
class ReaderChapterEndPrompt extends ConsumerStatefulWidget {
  final ConcreteEpubReaderEngine engine;
  final String bookId;
  final void Function(int chapterIndex) onReview;
  final VoidCallback onNext;

  /// 2026-07-08 FEAT 3：章末卡片「上一章」回调。null 时不渲染左下卡片
  /// （如已经在第一章）。
  final VoidCallback? onPrev;

  const ReaderChapterEndPrompt({
    super.key,
    required this.engine,
    required this.bookId,
    required this.onReview,
    required this.onNext,
    this.onPrev,
  });

  @override
  ConsumerState<ReaderChapterEndPrompt> createState() =>
      _ReaderChapterEndPromptState();
}

class _ReaderChapterEndPromptState
    extends ConsumerState<ReaderChapterEndPrompt> {
  late final ChapterEndPromptController _controller;
  ChapterEndPromptVisibility _lastVisibility =
      ChapterEndPromptVisibility.hidden;

  @override
  void initState() {
    super.initState();
    _controller = ChapterEndPromptController(
      repo: ref.read(settingsRepositoryProvider),
      source: widget.engine.chapterEndEvents,
      bookId: widget.bookId,
    )..addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onStateChanged(ChapterEndPromptState state) {
    if (state.visibility == ChapterEndPromptVisibility.visible &&
        _lastVisibility != ChapterEndPromptVisibility.visible) {
      _lastVisibility = state.visibility;
      _showSnackBar(state);
      // 2026-07-08 FEAT 3：visible 时除了 SnackBar，还要 setState 让 build
      // 渲染章末卡片。原实现只发 SnackBar，build 永远 SizedBox.shrink。
      if (mounted) setState(() {});
    } else {
      // hidden / dismissed → setState 让卡片消失。
      final changed = _lastVisibility != state.visibility;
      _lastVisibility = state.visibility;
      if (changed && mounted) setState(() {});
    }
  }

  void _showSnackBar(ChapterEndPromptState s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        ChapterEndPromptSnackBar(
          context: context,
          hasNext: s.hasNext,
          onReview: () {
            _controller.dismiss();
            widget.onReview(s.chapterIndex);
          },
          onNext: () {
            _controller.dismiss();
            widget.onNext();
          },
          onDismiss: () {
            _controller.dismiss();
          },
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // 2026-07-08 FEAT 3：章末显示「上一章 / 下一章」两个卡片按钮，左下 / 右下。
    // 章末事件触发后 state.visible=true；用户翻页 / 切章 / dismiss 后回到 hidden。
    if (_lastVisibility != ChapterEndPromptVisibility.visible) {
      return const SizedBox.shrink();
    }
    // 用 IgnorePointer + Align + Row 让两个卡片分别贴 Stack 左下 / 右下，
    // 同时不阻挡 reader 区其他手势（Stack 子树级 IgnorePointer=false 让卡片
    // 自身可点，对其他区域透传）。
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (widget.onPrev != null)
              _ChapterNavCard(
                label: '上一章',
                icon: Icons.arrow_back_ios_new,
                onTap: widget.onPrev!,
              ),
            // 左卡片缺位时占位（无 onPrev 的第一章场景），保证右卡片贴右下。
            if (widget.onPrev == null) const Spacer(),
            _ChapterNavCard(
              label: '下一章',
              icon: Icons.arrow_forward_ios,
              onTap: widget.onNext,
            ),
          ],
        ),
      ),
    );
  }
}

/// 2026-07-08 FEAT 3：章末导航卡片。Material Card 风格，圆角 + 阴影 +
/// 半透明背景，与 reader chrome（底栏进度条等）层级一致。
class _ChapterNavCard extends StatelessWidget {
  const _ChapterNavCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface.withValues(alpha: 0.92),
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: theme.colorScheme.primary),
              const SizedBox(height: 6),
              Text(label, style: theme.textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}
