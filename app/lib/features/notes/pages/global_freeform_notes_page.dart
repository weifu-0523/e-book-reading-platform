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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/local/database.dart' hide Annotation, Book, BookNote;
import '../../../gen_l10n/app_localizations.dart';
import '../providers/notes_page_providers.dart';
import 'note_edit_page.dart';

/// 全部自由笔记（全局 + 各书）列表。Bug #3 (2026-07-10)。
///
/// 与 [NotesPage] 的 per-book 视图不同：
/// - 入口在 library drawer（跨书聚合）
/// - 新建笔记默认 bookId=null（纯全局）
/// - 编辑现有笔记时 bookId 从 DB 读
class GlobalFreeformNotesPage extends ConsumerWidget {
  const GlobalFreeformNotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(allFreeformNotesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('全部自由笔记')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'global_freeform_fab',
        tooltip: '新建自由笔记',
        child: const Icon(Icons.note_add),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const NoteEditPage(bookId: null),
          ),
        ),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: l10n.notesLoadFailed,
          onRetry: () => ref.invalidate(allFreeformNotesProvider),
        ),
        data: (notes) => _body(context, notes),
      ),
    );
  }

  Widget _body(BuildContext context, List<FreeformNote> notes) {
    if (notes.isEmpty) {
      return EmptyView(
        title: '暂无自由笔记',
        icon: Icons.note_outlined,
        actionLabel: '新建第一条',
        onAction: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const NoteEditPage(bookId: null),
          ),
        ),
      );
    }
    final sorted = [...notes]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, i) {
        final n = sorted[i];
        return ListTile(
          leading: const Icon(Icons.note_outlined),
          title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            n.content.replaceAll('\n', ' '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NoteEditPage(noteId: n.id),
            ),
          ),
        );
      },
    );
  }
}
