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

import '../../../data/models/book.dart';
import '../../../services/sync/book_file_sync_service.dart';
import '../../ai/providers/book_preprocess_controller.dart';
import '../models/book_cell_action.dart';
import 'book_cell_action_menu.dart';
import 'book_cover.dart';
import 'preprocess_chip.dart';

/// 书架列表视图的列表项。
/// 由 [BookListView]（T17）渲染；trailing 在选择模式下显示 Checkbox，
/// 否则按以下优先级显示：[onAction]（更多操作菜单）→ [onReorderHandle]
/// （手动排序的 drag handle）→ null。
///
/// 当 [preprocessState] 处于 chunking/summarizing/error 时，在 leading 缩略图
/// 左上角叠加状态 chip。
class BookListTile extends StatelessWidget {
  final Book book;
  final File? coverFile;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onReorderHandle;
  final ValueChanged<BookCellAction>? onAction;
  final PreprocessState? preprocessState;

  const BookListTile({
    super.key,
    required this.book,
    required this.coverFile,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    required this.onLongPress,
    this.onReorderHandle,
    this.onAction,
    this.preprocessState,
  });

  @override
  Widget build(BuildContext context) {
    final preprocess = preprocessState;
    return ListTile(
      leading: SizedBox(
        width: 48,
        child: Stack(
          children: [
            BookCover(
              coverFile: coverFile,
              title: book.title,
              aspectRatio: 0.7,
            ),
            // M4.5: 所有非 EPUB 格式都显示格式标签。
            if (book.format != BookFormat.epub)
              Positioned(
                right: 0,
                bottom: 0,
                child: _FormatChip(format: book.format),
              ),
            // M2.8 T11: needs-download overlay (see BookCard._NeedsDownloadBadge).
            if (book.filePath ==
                BookFileSyncService.needsDownloadSentinel)
              const Positioned(
                left: 0,
                top: 0,
                child: _NeedsDownloadBadge(),
              ),
            if (preprocess != null &&
                (preprocess.status == PreprocessStatus.chunking ||
                    preprocess.status == PreprocessStatus.summarizing))
              const Positioned(
                left: 0,
                top: 0,
                child: _ListChip(label: 'AI'),
              )
            else if (preprocess != null &&
                preprocess.status == PreprocessStatus.error)
              const Positioned(
                left: 0,
                top: 0,
                child: PreprocessFailedChip(),
              ),
          ],
        ),
      ),
      title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: book.author == null ? null : Text(book.author!),
      trailing: _buildTrailing(),
      onTap: onTap,
      onLongPress: onLongPress,
      selected: isSelected,
    );
  }

  Widget? _buildTrailing() {
    if (isSelectionMode) {
      return Checkbox(value: isSelected, onChanged: (_) => onTap());
    }
    // 非选择模式：操作菜单优先于 drag handle；二者可同框（Row）。
    final menu = onAction == null
        ? null
        : BookCellActionMenu(onSelected: onAction!);
    final handle = onReorderHandle == null
        ? null
        : IconButton(
            icon: const Icon(Icons.drag_handle),
            onPressed: onReorderHandle,
          );
    if (menu == null && handle == null) return null;
    if (menu == null) return handle;
    if (handle == null) return menu;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [handle, menu],
    );
  }
}

/// Compact chip variant for the small (48-px wide) list-tile cover.
class _ListChip extends StatelessWidget {
  const _ListChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 9),
      ),
    );
  }
}

/// 格式标识 chip，叠加在封面右下角。
/// M4.5: 通用化 —— 接收 [BookFormat]，显示对应标签（PDF/Markdown/TXT）。
class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.format});

  final BookFormat format;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        format.displayLabel,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}

/// M2.8 T11: cloud-download badge for list-tile leading covers. Mirrors
/// BookCard._NeedsDownloadBadge but slightly smaller for the 48-px thumb.
class _NeedsDownloadBadge extends StatelessWidget {
  const _NeedsDownloadBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Icon(
        Icons.cloud_download_outlined,
        color: Colors.white,
        size: 12,
      ),
    );
  }
}
