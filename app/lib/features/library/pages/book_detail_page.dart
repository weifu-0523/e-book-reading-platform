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
import '../../../features/ai/widgets/ai_guide_sheet.dart';
import '../../../services/ai/ai_guide.dart';
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
          FloatingActionButton.extended(
            heroTag: 'reprocess',
            onPressed: _book == null ? null : _reprocess,
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context)!.bookDetailActionReprocess),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'ai_guide',
            onPressed: _openAiGuide,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(AppLocalizations.of(context)!.bookDetailActionAiGuide),
          ),
          const SizedBox(width: 12),
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
  void _reprocess() {
    final book = _book;
    if (book == null) return;
    ref
        .read(bookPreprocessControllerProvider(widget.bookId).notifier)
        .start(book);
  }

  Future<void> _openAiGuide() async {
    final b = _book;
    if (b == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) =>
          AiGuideSheet(book: b, initialMode: AiGuideMode.full),
    );
  }

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
        Text(AppLocalizations.of(context)!.bookDetailFieldFormat(book.format == BookFormat.epub ? 'EPUB' : 'PDF')),
        Text(AppLocalizations.of(context)!.bookDetailFieldFileSize(_humanSize(book.fileSizeBytes))),
        Text(AppLocalizations.of(context)!.bookDetailFieldAddedAt(book.addedAt.toLocal().toString())),
        if (book.lastReadAt != null)
          Text(AppLocalizations.of(context)!.bookDetailFieldLastReadAt(book.lastReadAt!.toLocal().toString())),
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
