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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/local/database.dart' hide Book;
import '../../../data/models/book.dart';
import '../../../features/ai/providers/book_preprocess_controller.dart';
import '../../../features/library/widgets/tag_editor.dart';
import '../../../services/ai/book_preprocessor.dart';

/// 书籍详情页。
/// 由路由 `/book/:id/details` 进入。展示元数据 + 删除入口。
class BookDetailPage extends ConsumerStatefulWidget {
  final String bookId;

  const BookDetailPage({super.key, required this.bookId});

  @override
  ConsumerState<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends ConsumerState<BookDetailPage> {
  /// True until the book lookup resolves. Rendering a loading state for at
  /// least one frame keeps the UI consistent across sync and async repository
  /// implementations and makes loading observable in tests.
  bool _loading = true;
  Book? _book;
  Timer? _loadTimer;

  @override
  void initState() {
    super.initState();
    // Schedule the lookup on the next turn of the event loop so the loading
    // indicator is rendered first. Using a [Timer] (rather than microtasks or
    // post-frame callbacks) keeps it from firing within the same frame.
    _loadTimer = Timer(Duration.zero, _loadBook);
  }

  Future<void> _loadBook() async {
    if (!mounted) return;
    final b = await ref.read(bookRepositoryProvider).getById(widget.bookId);
    if (!mounted) return;
    setState(() {
      _book = b;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preprocess = ref.watch(bookPreprocessControllerProvider(widget.bookId));
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.bookDetailTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.article_outlined),
            tooltip: AppLocalizations.of(context)!.bookDetailActionViewNotes,
            onPressed: () => context.push('/book/${widget.bookId}/notes'),
          ),
        ],
      ),
      body: _buildBody(context, preprocess),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // M2.7 (2026-07-07): BookPreprocessor 暂时禁用 per user decision.
          // "重新处理" FAB 隐藏。代码 + 表保留以备未来恢复（取消下方 Visibility
          // 注释即可还原；也可以把整段 FloatingActionButton.extended 块删掉）。
          // Visibility(
          //   visible: false,
          //   child: FloatingActionButton.extended(
          //     heroTag: 'reprocess',
          //     onPressed: _book == null ? null : _reprocess,
          //     icon: const Icon(Icons.refresh),
          //     label: Text(AppLocalizations.of(context)!.bookDetailActionReprocess),
          //   ),
          // ),
          // const SizedBox(width: 12),
          // M2.7 (2026-07-07): 全书 AI 导读入口暂时禁用 per spec §1.2 + §5.7.
          // 整书导读开销大且超 LLM context，已替换为右侧抽屉的章节级 AI 交互.
          // 代码 + 表（ai_summaries mode='book'）保留以备未来恢复.
          // FloatingActionButton.extended(
          //   heroTag: 'ai_guide',
          //   onPressed: _book == null ? null : _openAiGuide,
          //   icon: const Icon(Icons.auto_awesome_outlined),
          //   label: Text(AppLocalizations.of(context)!.bookDetailActionAiGuide),
          // ),
          // const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'delete',
            onPressed: _confirmDelete,
            backgroundColor: Colors.red,
            icon: const Icon(Icons.delete),
            label: Text(AppLocalizations.of(context)!.bookDetailActionDelete),
          ),
        ],
      ),
    );
  }

  /// Restart preprocessing from scratch. No-op if the book hasn't been
  /// loaded yet (the FAB is disabled in that case).
  //
  // M2.7 (2026-07-07): BookPreprocessor 暂时禁用。`_reprocess` 当前没有调用方
  // （FAB 已隐藏），但保留方法体以便恢复时直接取消上面 FAB 注释即可联调。
  // 当恢复时也取消此处的 `// ignore: unused_element` 即可。
  // ignore: unused_element
  void _reprocess() {
    final book = _book;
    if (book == null) return;
    ref
        .read(bookPreprocessControllerProvider(widget.bookId).notifier)
        .start(book);
  }

  // M2.7 (2026-07-07): `_openAiGuide` 已删除 —— 全书导读 FAB 已被 spec §1.2
  // + §5.7 否决（开销 + LLM context 限制），AI 入口统一到 reader 右侧抽屉。
  // 如需恢复，把对应 PopupMenuItem/FAB 取消注释并重新加回此方法即可。

  Widget _buildBody(BuildContext context, PreprocessState preprocess) {
    if (_loading) {
      return const LoadingView();
    }
    final book = _book;
    if (book == null) {
      return Center(child: Text(AppLocalizations.of(context)!.bookDetailNotFound));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          book.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (book.author != null) ...[
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context)!.bookDetailFieldAuthor(book.author!)),
        ],
        const SizedBox(height: 16),
        Text(AppLocalizations.of(context)!.bookDetailFieldFormat(book.format.displayLabel)),
        Text(AppLocalizations.of(context)!.bookDetailFieldFileSize(_humanSize(book.fileSizeBytes))),
        Text(AppLocalizations.of(context)!.bookDetailFieldAddedAt(book.addedAt.toLocal().toString())),
        if (book.lastReadAt != null)
          Text(AppLocalizations.of(context)!.bookDetailFieldLastReadAt(book.lastReadAt!.toLocal().toString())),
        const Divider(),
        // M2.8 (2026-07-12): 标签编辑区。Inline TagEditor 通过
        // [bookTagsRepositoryProvider] 持久化；FutureBuilder 保证每次
        // 编辑后 UI 立即 re-fetch 与底层 drift 表对齐。
        _TagsSection(bookId: widget.bookId),
        const Divider(),
        _PreprocessPanel(
          state: preprocess,
          bookId: widget.bookId,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.article_outlined),
          title: Text(AppLocalizations.of(context)!.bookDetailActionViewNotes),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/book/${widget.bookId}/notes'),
        ),
      ],
    );
  }

  String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _confirmDelete() async {
    final book = await ref.read(bookRepositoryProvider).getById(widget.bookId);
    if (book == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.bookDetailDeleteTitle),
        content: Text(
          AppLocalizations.of(context)!.bookDetailDeleteBody(book.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.bookDetailDeleteCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppLocalizations.of(context)!.bookDetailDeleteConfirm,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(libraryControllerProvider.notifier).deleteBook(book.id);
      // Best-effort navigation back to home. In some host environments (tests)
      // there is no GoRouter ancestor; tolerate that.
      if (mounted) {
        try {
          context.go('/');
        } catch (_) {
          unawaited(Navigator.of(context).maybePop());
        }
      }
    }
  }
}

/// Panel that surfaces the [PreprocessState] for a book: a progress bar while
/// chunking/summarizing, an auth-failed banner, a partial-failure banner with
/// retry, and a done status. Cancel/retry are wired to the controller via
/// [bookPreprocessControllerProvider].
class _PreprocessPanel extends ConsumerWidget {
  const _PreprocessPanel({required this.state, required this.bookId});

  final PreprocessState state;
  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    switch (state.status) {
      case PreprocessStatus.idle:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(l10n.bookDetailPreprocessIdle),
        );
      case PreprocessStatus.chunking:
      case PreprocessStatus.summarizing:
        final total = state.totalChapters > 0 ? state.totalChapters : 1;
        final current = state.currentChapter.clamp(0, total);
        final phase = state.status == PreprocessStatus.chunking
            ? l10n.bookDetailPreprocessChunking
            : l10n.bookDetailPreprocessSummarizing;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.bookDetailPreprocessStatusLabel(phase, current, total)),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: current / total,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => ref
                      .read(bookPreprocessControllerProvider(bookId).notifier)
                      .cancel(),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(l10n.bookDetailPreprocessCancel),
                ),
              ),
            ],
          ),
        );
      case PreprocessStatus.error:
        if (state.error == PreprocessError.authFailed) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.bookDetailPreprocessAuthFailed)),
                TextButton(
                  onPressed: () => context.push('/settings/ai'),
                  child: Text(l10n.bookDetailPreprocessGoSettings),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            l10n.bookDetailPreprocessFailed(state.error == null ? l10n.bookDetailPreprocessUnknownError : state.error!.name),
            style: const TextStyle(color: Colors.red),
          ),
        );
      case PreprocessStatus.done:
        if (state.failedChapters.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n.bookDetailPreprocessDone),
          );
        }
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.bookDetailPreprocessFailedCount(state.failedChapters.length),
                ),
              ),
              TextButton(
                onPressed: () {
                  final container = ProviderScope.containerOf(context);
                  final db = container.read(appDatabaseProvider);
                  _retryWithBookLookup(container, db);
                },
                child: Text(l10n.bookDetailPreprocessRetry),
              ),
            ],
          ),
        );
    }
  }

  /// Re-reads the [Book] row from the database and kicks off a fresh
  /// preprocessing run. Extracted as a helper so the retry button can re-fire
  /// without needing parent state plumbing.
  Future<void> _retryWithBookLookup(
    ProviderContainer container,
    AppDatabase db,
  ) async {
    final row = await (db.select(db.books)
          ..where((t) => t.id.equals(bookId)))
        .getSingleOrNull();
    if (row == null) return;
    final book = Book.fromRow(row);
    container
        .read(bookPreprocessControllerProvider(bookId).notifier)
        .start(book);
  }
}

/// Inline 标签编辑区，嵌入 [BookDetailPage] 主体列表中。
///
/// M2.8 (2026-07-12) T6：使用 [TagEditor] + [bookTagsRepositoryProvider]。
/// 每次变更后通过 [_fetchNonce] 触发 [FutureBuilder] 重新拉取最新 tags，
/// 让 UI 与 drift 表保持一致（无需 stream 订阅）。所有持久化逻辑都在
/// repository 层，本 widget 只负责显示 + 转发改动事件。
class _TagsSection extends ConsumerStatefulWidget {
  const _TagsSection({required this.bookId});

  final String bookId;

  @override
  ConsumerState<_TagsSection> createState() => _TagsSectionState();
}

class _TagsSectionState extends ConsumerState<_TagsSection> {
  /// Bumped on every successful mutation so the keyed FutureBuilder rebuilds
  /// with a fresh Future and re-fetches the latest tag list. Avoids relying
  /// on drift Stream subscriptions here (this widget is short-lived and the
  /// Future pattern is sufficient for a synchronous-ish edit flow).
  int _fetchNonce = 0;

  Future<List<String>> _loadTags() {
    return ref.read(bookTagsRepositoryProvider).tagsOfBook(widget.bookId);
  }

  Future<void> _onChanged(List<String> newTags) async {
    await ref
        .read(bookTagsRepositoryProvider)
        .replaceTagsForBook(bookId: widget.bookId, tags: newTags);
    if (!mounted) return;
    setState(() => _fetchNonce++);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('标签', style: theme.textTheme.titleSmall),
          ),
          // Keyed FutureBuilder: changing the key forces a brand-new
          // FutureBuilder instance (and therefore a fresh future), which is
          // simpler and more reliable than fighting FutureBuilder's identity
          // comparison on every parent rebuild.
          FutureBuilder<List<String>>(
            key: ValueKey('tags-future-$_fetchNonce'),
            future: _loadTags(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              return TagEditor(
                tags: snap.data ?? const <String>[],
                onChanged: _onChanged,
              );
            },
          ),
        ],
      ),
    );
  }
}
