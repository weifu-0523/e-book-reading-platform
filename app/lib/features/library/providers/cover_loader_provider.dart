import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// 按 bookId 查询书籍的封面文件。
/// 返回 null 的情况：book 不存在、coverPath 为 null、文件在磁盘上不存在。
/// UI 用此 provider 决定显示真实封面还是占位图。
final coverLoaderProvider =
    FutureProvider.family<File?, String>((ref, bookId) async {
  final book = await ref.watch(bookRepositoryProvider).getById(bookId);
  final path = book?.coverPath;
  if (path == null) return null;
  final file = File(path);
  return file.existsSync() ? file : null;
});
