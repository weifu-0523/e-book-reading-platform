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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locator.dart';
import '../../../core/providers.dart'
    show bookProvider, notesRepositoryProvider;
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/annotation.dart';
import '../../../data/models/book_note.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../reader/widgets/annotation_tile.dart';
import '../../reader/widgets/note_editor_sheet.dart';
import '../providers/notes_page_providers.dart';
import '../services/markdown_exporter.dart';
import '../services/note_file_writer.dart';
import '../widgets/annotation_context_sheet.dart';

/// 单本书的笔记页：按章节分组展示高亮与笔记。
///
/// - 顶部：统计行（共 N 条高亮 · M 条笔记 · 最近更新 MM-DD）
/// - 章节分组：使用 locator.chapterIndex 排序，每组显示章节标题
/// - 条目：复用 reader 的 [AnnotationTile]（showMeta: true）
/// - 交互：
///   - 点击 → push 阅读器路由，extra 为 annotation.locator
///   - 长按 → 弹出 [showAnnotationContextSheet]
/// - AppBar：导出 Markdown 按钮（[NoteFileWriter] 调用系统目录选择）
class NotesPage extends ConsumerWidget {
  final String bookId;

  const NotesPage({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final annotationsAsync =
        ref.watch(notesPageAnnotationsProvider(bookId));
    final noteAsync = ref.watch(notesPageBookNoteProvider(bookId));

    return Scaffold(
      appBar: AppBar(
        title: noteAsync.maybeWhen(
          data: (n) => Text(_titleFor(n)),
          orElse: () => const Text('笔记'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: '导出 Markdown',
            onPressed: () => _export(context, ref),
          ),
        ],
      ),
      body: annotationsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) {
          debugPrint('notesPageAnnotationsProvider error: $e');
          return ErrorView(
            message: l10n.notesLoadFailed,
            onRetry: () =>
                ref.invalidate(notesPageAnnotationsProvider(bookId)),
          );
        },
        data: (annotations) => _body(context, ref, annotations),
      ),
    );
  }

  String _titleFor(BookNote? n) {
    if (n == null) return '笔记';
    // BookNote.title 在 BookNote.empty 中是 "《书名》读书笔记"。
    // 还原为纯书名后再统一加 "笔记" 后缀。
    final raw = n.title;
    var stripped = raw;
    if (stripped.startsWith('《')) {
      stripped = stripped.substring(1);
    }
    const suffix = '》读书笔记';
    if (stripped.endsWith(suffix)) {
      stripped = stripped.substring(0, stripped.length - suffix.length);
    }
    return '《$stripped》笔记';
  }

  Widget _body(
      BuildContext context, WidgetRef ref, List<Annotation> annotations) {
    if (annotations.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return EmptyView(
        title: l10n.notesEmptyTitle,
        icon: Icons.edit_note,
        actionLabel: l10n.notesEmptyAction,
        onAction: () => context.push('/book/$bookId'),
      );
    }

    final notes = annotations.where((a) => a.hasNote).length;
    final highlights = annotations.length - notes;

    final groups = <int, List<Annotation>>{};
    for (final a in annotations) {
      final idx = _chapterIndex(a);
      groups.putIfAbsent(idx, () => []).add(a);
    }
    final sortedKeys = groups.keys.toList()..sort();

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '共 $highlights 条高亮 · $notes 条笔记 · 更新于 '
            '${_latestDate(annotations)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        for (final chapterIdx in sortedKeys) ...[
          ListTile(
            title: Text(
              _chapterTitle(groups[chapterIdx]!.first),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final a in groups[chapterIdx]!)
            AnnotationTile(
              annotation: a,
              showMeta: true,
              onTap: () => context.push('/book/$bookId', extra: a.locator),
              onLongPress: () => _showContextMenu(context, ref, a),
              onSecondaryTapDown: (globalPos) =>
                  _showContextMenu(context, ref, a, fromDesktop: globalPos),
            ),
        ],
      ],
    );
  }

  /// 摘录上下文菜单统一调度入口。
  ///
  /// - [fromDesktop] == null：移动端长按路径，弹 [showAnnotationContextSheet]
  ///   （bottom sheet），复制类操作在 sheet 内部完成。
  /// - [fromDesktop] != null：桌面右键路径，[fromDesktop] 为右键全局坐标，
  ///   弹 [showAnnotationContextMenu]（Material showMenu，原生右键观感）。
  ///
  /// 两条路径共用同一枚举与同一 dispatch（edit/delete/export + copy），仅在
  /// 「获取 action」与「复制类是否已在 UI 内完成」上不同：bottom sheet 版本
  /// 的 copyQuote/copyMarkdown 在 sheet 内部直接写剪贴板；桌面 showMenu 版本
  /// 只 pop 枚举，复制在这里完成。
  Future<void> _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Annotation a, {
    Offset? fromDesktop,
  }) async {
    final AnnotationContextAction? action;
    if (fromDesktop == null) {
      action = await showAnnotationContextSheet(context, a, chapterTitle: null);
    } else {
      action = await showAnnotationContextMenu(context, fromDesktop);
    }
    if (action == null || !context.mounted) return;
    switch (action) {
      case AnnotationContextAction.edit:
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => NoteEditorSheet(
            annotation: a,
            suggestions: const [],
            onSave: (note, color) async {
              await ref.read(notesRepositoryProvider).updateAnnotation(
                  a.copyWith(note: note, color: color, updatedAt: DateTime.now()));
            },
            onDelete: () async {
              await ref.read(notesRepositoryProvider).deleteAnnotation(a.id);
            },
          ),
        );
        break;
      case AnnotationContextAction.delete:
        await ref.read(notesRepositoryProvider).deleteAnnotation(a.id);
        break;
      case AnnotationContextAction.copyQuote:
        if (fromDesktop != null) {
          await _copyToClipboard(context, a.quote, '已复制');
        }
        // bottom sheet 版本已在内部复制。
        break;
      case AnnotationContextAction.copyMarkdown:
        if (fromDesktop != null) {
          await _copyToClipboard(
              context, MarkdownExporter.exportSingle(a), '已复制 Markdown 片段');
        }
        // bottom sheet 版本已在内部复制。
        break;
      case AnnotationContextAction.export:
        await _exportSingle(context, a);
        break;
    }
  }

  Future<void> _copyToClipboard(
      BuildContext context, String text, String toast) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toast)));
  }

  /// 导出单条摘录为 Markdown 文件。
  Future<void> _exportSingle(BuildContext context, Annotation a) async {
    final markdown = MarkdownExporter.exportSingle(a);
    final name = NoteFileWriter.sanitizeForFilename(a.quote);
    try {
      final path = await NoteFileWriter.saveMarkdownFile(
        content: markdown,
        suggestedName: name,
      );
      if (!context.mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已保存：$path'),
          action: SnackBarAction(
            label: '打开文件夹',
            onPressed: () => _openFolder(path),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final note = await ref.read(notesPageBookNoteProvider(bookId).future);
    final book = await ref.read(bookProvider(bookId).future);
    if (note == null || book == null || !context.mounted) return;
    final markdown = MarkdownExporter.export(
      bookNote: note,
      book: book,
      now: DateTime.now(),
    );
    final name = '${NoteFileWriter.sanitizeForFilename(note.title)} - 读书笔记';
    try {
      final path = await NoteFileWriter.saveMarkdownFile(
        content: markdown,
        suggestedName: name,
      );
      if (!context.mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已保存：$path'),
          action: SnackBarAction(
            label: '打开文件夹',
            onPressed: () => _openFolder(path),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
    }
  }

  /// Best-effort open of the parent directory of [filePath] in the native
  /// file manager. On Windows selects the file; on macOS opens the file
  /// directly; on Linux opens the parent directory. Failures are silently
  /// swallowed — this is a convenience action, not a critical path.
  Future<void> _openFolder(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,$filePath']);
      } else if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [File(filePath).parent.path]);
      }
    } catch (_) {
      // Best-effort; ignore failures.
    }
  }

  int _chapterIndex(Annotation a) {
    final loc = a.locator;
    if (loc is PdfRangeLocator) return loc.page;
    if (loc is EpubRangeLocator) return loc.chapterIndex;
    if (loc is EpubCfiLocator) return loc.chapterIndex;
    return 0;
  }

  String _chapterTitle(Annotation a) {
    final loc = a.locator;
    if (loc is PdfRangeLocator) {
      // PDF 没有「章节」概念，按页分组（与 MarkdownExporter 一致）。
      return '第 ${loc.page} 页';
    }
    if (loc is EpubRangeLocator) {
      final t = loc.chapterTitle;
      return (t != null && t.isNotEmpty) ? t : '第 ${loc.chapterIndex + 1} 章';
    }
    if (loc is EpubCfiLocator) {
      final t = loc.chapterTitle;
      return (t != null && t.isNotEmpty) ? t : '第 ${loc.chapterIndex + 1} 章';
    }
    return '未分类';
  }

  String _latestDate(List<Annotation> annotations) {
    final latest = annotations
        .map((a) => a.updatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return '${latest.month.toString().padLeft(2, '0')}'
        '-${latest.day.toString().padLeft(2, '0')}';
  }
}
