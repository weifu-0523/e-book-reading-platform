import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/rendering/pagination_model.dart';

import '../controllers/reader_ui_controller.dart';

/// 沉浸式阅读容器：tap 区域分派 + chrome 显隐。
///
/// - **paged 模式**：tap 左 1/3 → onTapPrev；右 1/3 → onTapNext；中央 → toggle chrome
/// - **scroll 模式**：tap 左右无效（用户用滚动手势）；中央 → toggle chrome
class ReaderScaffold extends ConsumerWidget {
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
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(readerUiControllerProvider);
    final size = MediaQuery.sizeOf(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) =>
          _handleTap(details.localPosition.dx, size.width, ref),
      child: Stack(
        children: [
          content,
          if (ui.chromeVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                key: const Key('reader_app_bar'),
                color: Colors.black54,
                child: SafeArea(
                  child: AppBar(
                    title: Text(title),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: onBack ?? () => Navigator.maybePop(context),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.list),
                        tooltip: '目录',
                        onPressed: onOpenToc,
                      ),
                      IconButton(
                        icon: const Icon(Icons.text_fields),
                        tooltip: '排版',
                        onPressed: onOpenTypography,
                      ),
                      IconButton(
                        icon: const Icon(Icons.menu_book),
                        tooltip: '笔记',
                        onPressed: onOpenNotes,
                      ),
                      IconButton(
                        icon: const Icon(Icons.auto_awesome),
                        tooltip: 'AI 导读',
                        onPressed: onOpenAiGuide,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleTap(double dx, double width, WidgetRef ref) {
    if (paginationMode == PaginationMode.scroll) {
      ref.read(readerUiControllerProvider.notifier).toggleChrome();
      return;
    }
    final third = width / 3;
    if (dx < third) {
      onTapPrev();
    } else if (dx > width - third) {
      onTapNext();
    } else {
      ref.read(readerUiControllerProvider.notifier).toggleChrome();
    }
  }
}
