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
import '../../../data/models/annotation.dart';

class AnnotationTile extends StatelessWidget {
  final Annotation annotation;

  /// 已废弃：章节标题应由父级以 section header 形式渲染。
  /// 保留只是为了向后兼容，M4 会移除。
  @Deprecated('Use section header in parent. Will be removed in M4.')
  final String? chapterTitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 桌面右键回调。收到右键点击的全局坐标（[TapDownDetails.globalPosition]），
  /// 由父级决定弹什么菜单。移动端无右键不触发；长按仍走 [onLongPress]。
  final ValueChanged<Offset>? onSecondaryTapDown;

  final bool showMeta;

  const AnnotationTile({
    super.key,
    required this.annotation,
    // ignore: deprecated_member_use_from_same_package
    this.chapterTitle,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.showMeta = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = annotation.color.swatch;
    // InkWell 外层包一层 GestureDetector 仅接 onSecondaryTapDown。
    // onSecondary（右键）与 primary（左键 onTap / onLongPress）互不干扰：
    // GestureDetector 不会消费 primary tap，InkWell 的涟漪/点击仍生效。
    // onSecondaryTapDown == null 时不包 GestureDetector，行为与原先完全一致。
    final tile = InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(annotation.quote,
                maxLines: 3, overflow: TextOverflow.ellipsis),
            if (annotation.hasNote) ...[
              const SizedBox(height: 4),
              Text(annotation.note!,
                  maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            if (chapterTitle != null) ...[
              const SizedBox(height: 4),
              // ignore: deprecated_member_use_from_same_package
              Text(chapterTitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (showMeta) ...[
              const SizedBox(height: 4),
              Text(
                _metaLine(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
    final onSecondary = onSecondaryTapDown;
    if (onSecondary == null) return tile;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) => onSecondary(details.globalPosition),
      child: tile,
    );
  }

  String _metaLine() {
    final parts = <String>[_formatDate(annotation.updatedAt)];
    if (annotation.tags.isNotEmpty) {
      parts.add(annotation.tags.map((t) => '#$t').join(' '));
    }
    return parts.join(' · ');
  }

  static String _formatDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
