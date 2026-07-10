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
import '../../../data/local/database.dart' hide Annotation;
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

  /// M3e/Q7：摘录右键 / 可见操作按钮回调。这些是按 annotation id 委托的
  /// （与 onTap/onLongPress 一致），由父级（reader_body）反查 annotation 后
  /// 弹菜单或执行操作。全 null 时（旧行为）AnnotationTile 不渲染 actions 行、
  /// 不接右键 —— 向后兼容。
  final void Function(String id, Offset globalPosition)? onSecondaryTapDown;
  final ValueChanged<String>? onEdit;
  final ValueChanged<String>? onExport;
  final ValueChanged<String>? onDelete;

  /// Bug #3 (2026-07-10)：自由笔记列表 + 新建回调。空列表 + null 回调时
  /// 整个 freeform section 不渲染，向后兼容。
  final List<FreeformNote> freeformNotes;
  final VoidCallback? onCreateFreeformNote;
  final ValueChanged<String>? onOpenFreeformNote;

  const NotesDrawerContent({
    super.key,
    required this.annotations,
    required this.chapterTitles,
    required this.onTap,
    required this.onLongPress,
    required this.onClose,
    this.onSecondaryTapDown,
    this.onEdit,
    this.onExport,
    this.onDelete,
    this.freeformNotes = const [],
    this.onCreateFreeformNote,
    this.onOpenFreeformNote,
  });

  @override
  Widget build(BuildContext context) {
    if (annotations.isEmpty && freeformNotes.isEmpty) {
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
            child: ListView(
              children: [
                _buildFreeformSection(),
                ...sortedKeys.map((chapterIdx) {
                  final List<Annotation> items = groups[chapterIdx]!;
                  items.sort((Annotation a, Annotation b) =>
                      b.updatedAt.compareTo(a.updatedAt));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Text(
                            chapterTitles[chapterIdx] ??
                                '第 ${chapterIdx + 1} 章',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                      ),
                      ...items.map((Annotation a) => AnnotationTile(
                            annotation: a,
                            chapterTitle: null,
                            onTap: () => onTap(a.id),
                            onLongPress: () => onLongPress(a.id),
                            // M3e/Q7：右键 + 可见操作按钮（编辑/导出/删除）。
                            // 按 id 委托给父级（reader_body 反查 annotation）。
                            onSecondaryTapDown: onSecondaryTapDown == null
                                ? null
                                : (globalPos) =>
                                    onSecondaryTapDown!(a.id, globalPos),
                            onEdit: onEdit == null ? null : () => onEdit!(a.id),
                            onExport: onExport == null
                                ? null
                                : () => onExport!(a.id),
                            onDelete: onDelete == null
                                ? null
                                : () => onDelete!(a.id),
                          )),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() => ListTile(
        leading: const Icon(Icons.menu_book),
        title: const Text('本书高亮与笔记'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onCreateFreeformNote != null)
              IconButton(
                icon: const Icon(Icons.note_add, size: 22),
                tooltip: '新建自由笔记',
                onPressed: onCreateFreeformNote,
              ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
          ],
        ),
      );

  /// Bug #3 (2026-07-10)：自由笔记 section，渲染在 annotations 上方。
  /// 列表为空 + onCreateFreeformNote == null 时不渲染（保持旧行为）。
  Widget _buildFreeformSection() {
    if (freeformNotes.isEmpty && onCreateFreeformNote == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.note_outlined, size: 18),
              const SizedBox(width: 6),
              Text('自由笔记（${freeformNotes.length}）',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        if (freeformNotes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              '点击右上 note_add 图标创建第一条\n—— 可保存 AI 生成的金句或自己的感悟',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          )
        else
          ...freeformNotes.map((n) => ListTile(
                dense: true,
                leading: const Icon(Icons.note_outlined, size: 20),
                title: Text(n.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  n.content.replaceAll('\n', ' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: onOpenFreeformNote == null
                    ? null
                    : () => onOpenFreeformNote!(n.id),
              )),
        const Divider(height: 1),
      ],
    );
  }
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

  /// M3e/Q7：同 NotesDrawerContent 的可选回调，透传。
  final void Function(String id, Offset globalPosition)? onSecondaryTapDown;
  final ValueChanged<String>? onEdit;
  final ValueChanged<String>? onExport;
  final ValueChanged<String>? onDelete;

  /// Bug #3 (2026-07-10)：自由笔记 + 新建回调（透传到 content）。
  final List<FreeformNote> freeformNotes;
  final VoidCallback? onCreateFreeformNote;
  final ValueChanged<String>? onOpenFreeformNote;

  const NotesDrawer({
    super.key,
    required this.annotations,
    required this.chapterTitles,
    required this.onTap,
    required this.onLongPress,
    required this.onClose,
    this.onSecondaryTapDown,
    this.onEdit,
    this.onExport,
    this.onDelete,
    this.freeformNotes = const [],
    this.onCreateFreeformNote,
    this.onOpenFreeformNote,
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
        onSecondaryTapDown: onSecondaryTapDown,
        onEdit: onEdit,
        onExport: onExport,
        onDelete: onDelete,
        freeformNotes: freeformNotes,
        onCreateFreeformNote: onCreateFreeformNote,
        onOpenFreeformNote: onOpenFreeformNote,
      ),
    );
  }
}
