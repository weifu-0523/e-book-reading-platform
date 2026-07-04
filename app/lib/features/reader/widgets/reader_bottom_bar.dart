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

class ReaderBottomBar extends StatelessWidget {
  final String? chapterTitle;
  final double percent;

  /// M2.9: 本章页码文本（如 "3 / 12" 或 "3-4 / 12"）。非 null 时优先于
  /// 百分比显示在右侧。EPUB paged 模式由 ReaderProgressBar 计算填充；
  /// PDF / scroll 模式为 null（回退到百分比）。
  final String? pageInfo;

  const ReaderBottomBar({
    super.key,
    required this.chapterTitle,
    required this.percent,
    this.pageInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              chapterTitle ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          // M2.9: 有 pageInfo 时显示页码，否则回退到百分比。
          Text(
            pageInfo ?? '${(percent * 100).round()}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
