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
import '../../ai/providers/book_preprocess_controller.dart';
import '../models/book_cell_action.dart';
import 'book_cell_action_menu.dart';
import 'book_cover.dart';
import 'preprocess_chip.dart';

/// 书架网格视图的书卡。
/// 由 [BookGrid]（T17）渲染；通过 [onTap]/[onLongPress] 与父级交互。
///
/// 当 [onAction] 不为 null 且非选择模式时，右上角渲染"更多操作"菜单
/// （[BookCellActionMenu]），用于 阅读/详情/笔记/删除 等快捷入口。
///
/// 当 [preprocessState] 非空且处于 chunking/summarizing/error 阶段时，
/// 在封面左上角叠加预处理状态 chip（[PreprocessChip] / [PreprocessFailedChip]）。
class BookCard extends StatelessWidget {
  final Book book;
  final File? coverFile;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<BookCellAction>? onAction;
  final PreprocessState? preprocessState;

  const BookCard({
    super.key,
    required this.book,
    required this.coverFile,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    required this.onLongPress,
    this.onAction,
    this.preprocessState,
  });

  @override
  Widget build(BuildContext context) {
    final preprocess = preprocessState;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    BookCover(
                      coverFile: coverFile,
                      title: book.title,
                    ),
                    if (book.format == BookFormat.pdf)
                      const Positioned(
                        right: 4,
                        bottom: 4,
                        child: _PdfChip(),
                      ),
                    if (preprocess != null &&
                        (preprocess.status == PreprocessStatus.chunking ||
                            preprocess.status ==
                                PreprocessStatus.summarizing))
                      Positioned(
                        left: 4,
                        top: 4,
                        child: PreprocessChip(state: preprocess),
                      )
                    else if (preprocess != null &&
                        preprocess.status == PreprocessStatus.error)
                      const Positioned(
                        left: 4,
                        top: 4,
                        child: PreprocessFailedChip(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (book.author != null)
                Text(
                  book.author!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
          if (isSelectionMode)
            Positioned(
              top: 4,
              right: 4,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
              ),
            )
          else if (onAction != null)
            Positioned(
              top: 0,
              right: 0,
              child: BookCellActionMenu(onSelected: onAction!),
            ),
        ],
      ),
    );
  }
}

/// PDF 文档标识 chip，叠加在封面右下角。
class _PdfChip extends StatelessWidget {
  const _PdfChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'PDF',
        style: TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}
