// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source Contributors
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
import '../../../core/locator.dart';
import 'annotation_tile.dart';

/// 自 T7 (M2.5) 起的内部实现：纯粹的抽屉内容（SafeArea + Column），
/// 不再包裹 `Drawer(...)` 外壳。
///
/// 在 [ReaderDrawer.notesBuilder] 中由 [ReaderNotesDrawerWrapper] 注入；
/// 外层 `Drawer` 由 [ReaderDrawer] 统一提供。直接挂在 Scaffold 槽位上时
/// 仍应使用 [NotesDrawer]（保留 `Drawer` 包装）。
class NotesDrawerContent extends StatelessWidget {
  final List<Annotation> annotations;
  final Map<int, String> chapterTitles;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onLongPress;
  final VoidCallback onClose;

  const NotesDrawerContent({
    super.key,
    required this.annotations,
    required this.chapterTitles,
    required this.onTap,
    required this.onLongPress,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    if (annotations.isEmpty) {
      return SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Expanded(child: Center(child: Text('本书暂无高亮与笔记'))),
          ],
        ),
      );
    }
    final groups = <int, List<Annotation>>{};
    for (final a in annotations) {
      final locator = a.locator;
      if (locator is EpubRangeLocator) {
        groups.putIfAbsent(locator.chapterIndex, () => []).add(a);
      }
    }
    final sortedKeys = groups.keys.toList()..sort();
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              itemCount: sortedKeys.length,
              itemBuilder: (ctx, i) {
                final chapterIdx = sortedKeys[i];
                final items = groups[chapterIdx]!
                  ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text(
                          chapterTitles[chapterIdx] ?? '第 ${chapterIdx + 1} 章',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
                    ),
                    ...items.map((a) => AnnotationTile(
                          annotation: a,
                          chapterTitle: null,
                          onTap: () => onTap(a.id),
                          onLongPress: () => onLongPress(a.id),
                        )),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() => ListTile(
        leading: const Icon(Icons.menu_book),
        title: const Text('本书高亮与笔记'),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onClose,
        ),
      );
}

/// 直接挂在 `Scaffold.drawer` / `Scaffold.endDrawer` 槽位上的版本，
/// 自带 `Drawer(...)` 外壳。
///
/// 注：在 [ReaderDrawer] 统一容器场景下应使用 [NotesDrawerContent]，
/// 否则会嵌套出 `Drawer > Drawer`（double SafeArea + 错宽）。
class NotesDrawer extends StatelessWidget {
  final List<Annotation> annotations;
  final Map<int, String> chapterTitles;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onLongPress;
  final VoidCallback onClose;

  const NotesDrawer({
    super.key,
    required this.annotations,
    required this.chapterTitles,
    required this.onTap,
    required this.onLongPress,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: NotesDrawerContent(
        annotations: annotations,
        chapterTitles: chapterTitles,
        onTap: onTap,
        onLongPress: onLongPress,
        onClose: onClose,
      ),
    );
  }
}
