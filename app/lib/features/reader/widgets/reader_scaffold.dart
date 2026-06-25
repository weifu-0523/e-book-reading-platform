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

  const ReaderScaffold({
    super.key,
    required this.content,
    required this.onTapPrev,
    required this.onTapNext,
    this.paginationMode = PaginationMode.paged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(readerUiControllerProvider);
    final size = MediaQuery.sizeOf(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _handleTap(details.localPosition.dx, size.width, ref),
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
                    title: const Text('阅读中'),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {},
                    ),
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
