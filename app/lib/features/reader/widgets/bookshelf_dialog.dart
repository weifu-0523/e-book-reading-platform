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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../data/models/book.dart';
import '../../library/providers/cover_loader_provider.dart';
import '../../library/widgets/book_cover.dart';

/// 弹出书架对话框（M3c/任务 6b）。
///
/// 全屏 `Dialog`：顶部标题「书架」+ 关闭按钮；主体为可滚动封面网格。
/// 当前阅读的书用主题色边框 + 「阅读中」标记。选书后 pop 对话框并
/// `pushReplacement` 到 `/book/$newId`（reader_engine 是 autoDispose
/// FutureProvider，pushReplacement 会 dispose 旧引擎、加载新引擎，自带
/// loading）。
///
/// **数据源**：复用全局 [libraryControllerProvider]（书架 books）+
/// [coverLoaderProvider]（按 bookId 解析封面）。这两个 provider 均为全局
/// 顶层定义，不依赖 LibraryPage 的作用域。
Future<void> showBookshelfDialog(
  BuildContext context, {
  required String currentBookId,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => BookshelfDialog(currentBookId: currentBookId),
  );
}

/// 书架对话框 widget。公开以便测试直接 pump 验证渲染。
class BookshelfDialog extends ConsumerWidget {
  /// 当前正在阅读的 bookId，用于高亮标记。
  final String currentBookId;

  const BookshelfDialog({super.key, required this.currentBookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryControllerProvider);
    final books = state.books;

    return Dialog(
      insetPadding: EdgeInsets.zero,
      child: Scaffold(
        appBar: AppBar(
          leading: const SizedBox.shrink(),
          title: const Text('书架'),
          centerTitle: true,
          actions: [
            IconButton(
              key: const Key('bookshelf_dialog_close'),
              icon: const Icon(Icons.close),
              tooltip: '关闭',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: books.isEmpty
            ? const Center(child: Text('书架还没有书籍'))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 140,
                  mainAxisExtent: 230,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: books.length,
                itemBuilder: (context, i) {
                  final book = books[i];
                  final isCurrent = book.id == currentBookId;
                  return _BookshelfCell(
                    book: book,
                    coverFile: _resolveCover(ref, book.id),
                    isCurrent: isCurrent,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.pushReplacement('/book/${book.id}');
                    },
                  );
                },
              ),
      ),
    );
  }

  File? _resolveCover(WidgetRef ref, String bookId) {
    final async = ref.watch(coverLoaderProvider(bookId));
    return async.maybeWhen(data: (f) => f, orElse: () => null);
  }
}

/// 书架对话框内的简化书卡：封面 + 标题，当前书用主题色边框标记。
class _BookshelfCell extends StatelessWidget {
  final Book book;
  final File? coverFile;
  final bool isCurrent;
  final VoidCallback onTap;

  const _BookshelfCell({
    required this.book,
    required this.coverFile,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      key: ValueKey('bookshelf-cell-${book.id}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: isCurrent
            ? BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  BookCover(coverFile: coverFile, title: book.title),
                  if (isCurrent)
                    Positioned(
                      left: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '阅读中',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
