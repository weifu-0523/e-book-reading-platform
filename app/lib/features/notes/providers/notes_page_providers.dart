import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart' show notesRepositoryProvider;
import '../../../data/models/annotation.dart';
import '../../../data/models/book_note.dart';

/// 反应式订阅本书全部 Annotation，供 [NotesPage] 使用。
///
/// `autoDispose` 让离开页面时关闭 Stream。family 按 bookId 分流。
final notesPageAnnotationsProvider =
    StreamProvider.autoDispose.family<List<Annotation>, String>(
  (ref, bookId) =>
      ref.watch(notesRepositoryProvider).watchAnnotations(bookId),
);

/// 一次性读取 BookNote 头部（标题/摘要/核心知识点），供 AppBar 标题与
/// Markdown 导出使用。
final notesPageBookNoteProvider =
    FutureProvider.autoDispose.family<BookNote?, String>(
  (ref, bookId) => ref.watch(notesRepositoryProvider).getNoteByBook(bookId),
);
