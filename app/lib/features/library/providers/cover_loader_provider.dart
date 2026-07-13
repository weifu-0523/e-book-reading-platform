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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../services/sync/book_file_sync_service.dart';
import '../../../features/sync/providers/sync_controller.dart';

/// 按 bookId 查询书籍的封面文件。
///
/// 返回 null 的情况：
/// - book 不存在
/// - coverPath 为 null（PDF 等无封面的格式，或远端 404 后清空）
/// - 文件在磁盘上不存在（数据完整性问题）
///
/// UI 用此 provider 决定显示真实封面还是占位图。
///
/// T4 (2026-07-13): autoDispose.family + sentinel 触发懒下载。
///
/// - `autoDispose`：library_page + bookshelf_dialog 是仅有的两处订阅方，
///   页面/对话框关闭时自动释放 Riverpod cache，避免累积。
/// - `family`：按 bookId 分桶，同一 bookId 的并发 widget 订阅共享同一
///   Future（Riverpod dedup），避免重复触发下载。
/// - sentinel 触发：当 `cover_path == [BookFileSyncService.needsCoverDownloadSentinel]`
///   时，调 `SyncController.downloadCoverFile` 拉取封面。下载期间用
///   `ref.keepAlive()` 防止 provider 被 dispose 中断 Future。
final coverLoaderProvider =
    FutureProvider.autoDispose.family<File?, String>((ref, bookId) async {
  final book = await ref.watch(bookRepositoryProvider).getById(bookId);
  final path = book?.coverPath;
  if (path == null) return null;

  if (path == BookFileSyncService.needsCoverDownloadSentinel) {
    // Cover binary is on a peer device but not local — trigger lazy
    // download. keepAlive prevents autoDispose from cancelling the
    // in-flight Future if the widget unsubscribes mid-download.
    final link = ref.keepAlive();
    try {
      final ok = await ref
          .read(syncControllerProvider.notifier)
          .downloadCoverFile(bookId);
      if (!ok) return null;
      // Re-read — drift DSL write should have updated cover_path to the
      // local path (or NULL on 404). bookRepositoryProvider is watched
      // above so the new value flows through.
      final refreshed =
          await ref.read(bookRepositoryProvider).getById(bookId);
      final localPath = refreshed?.coverPath;
      if (localPath == null) return null;
      if (localPath == BookFileSyncService.needsCoverDownloadSentinel) {
        return null; // still sentinel — download didn't update; bail.
      }
      final file = File(localPath);
      return file.existsSync() ? file : null;
    } finally {
      link.close();
    }
  }

  final file = File(path);
  return file.existsSync() ? file : null;
});
