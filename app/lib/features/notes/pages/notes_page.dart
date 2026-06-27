import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locator.dart';
import '../../../core/providers.dart' show notesRepositoryProvider;
import '../../../data/models/annotation.dart';
import '../../../data/models/book.dart';
import '../../../data/models/book_note.dart';
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('加载失败：$e'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(notesPageAnnotationsProvider(bookId)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
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
    final suffix = '》读书笔记';
    if (stripped.endsWith(suffix)) {
      stripped = stripped.substring(0, stripped.length - suffix.length);
    }
    return '《$stripped》笔记';
  }

  Widget _body(
      BuildContext context, WidgetRef ref, List<Annotation> annotations) {
    if (annotations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('本书暂无高亮与笔记'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.push('/book/$bookId'),
              child: const Text('去阅读器添加'),
            ),
          ],
        ),
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
            ),
        ],
      ],
    );
  }

  Future<void> _showContextMenu(
      BuildContext context, WidgetRef ref, Annotation a) async {
    final action = await showAnnotationContextSheet(
      context,
      a,
      chapterTitle: _chapterTitle(a),
    );
    if (action == null) return;
    switch (action) {
      case AnnotationContextAction.edit:
        if (!context.mounted) return;
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
      case AnnotationContextAction.copyMarkdown:
        // Clipboard 已经在 sheet 内部处理。
        break;
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final note = await ref.read(notesPageBookNoteProvider(bookId).future);
    if (note == null || !context.mounted) return;
    final markdown = MarkdownExporter.export(
      bookNote: note,
      book: _stubBookForExport(note),
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
        SnackBar(content: Text('已保存：$path')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
    }
  }

  int _chapterIndex(Annotation a) {
    final loc = a.locator;
    if (loc is EpubRangeLocator) return loc.chapterIndex;
    if (loc is EpubCfiLocator) return loc.chapterIndex;
    return 0;
  }

  String _chapterTitle(Annotation a) {
    final loc = a.locator;
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

  /// M3.4 简化：NotesPage 只获取 BookNote，没有单独获取 Book。
  ///
  /// 为了让 MarkdownExporter 的 frontmatter 有数据，这里合成一个最小 Book。
  /// M3.5 会接入真实 Book 元数据（包括 coverPath、lastReadAt 等）。
  Book _stubBookForExport(BookNote note) {
    var title = note.title;
    if (title.startsWith('《')) {
      title = title.substring(1);
    }
    final suffix = '》读书笔记';
    if (title.endsWith(suffix)) {
      title = title.substring(0, title.length - suffix.length);
    }
    return Book(
      id: note.bookId,
      title: title,
      author: null,
      format: BookFormat.epub,
      fileSizeBytes: 0,
      filePath: '',
      fileHash: '',
      coverPath: null,
      addedAt: note.createdAt,
      lastReadAt: null,
    );
  }
}
