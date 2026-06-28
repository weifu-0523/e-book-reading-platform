import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../data/models/book.dart';
import '../../../features/ai/widgets/ai_guide_sheet.dart';
import '../../../services/ai/ai_guide.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('书籍详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.article_outlined),
            tooltip: '查看笔记',
            onPressed: () => context.push('/book/${widget.bookId}/notes'),
          ),
        ],
      ),
      body: _buildBody(context),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'ai_guide',
            onPressed: _openAiGuide,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('AI 导读'),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'delete',
            onPressed: _confirmDelete,
            backgroundColor: Colors.red,
            icon: const Icon(Icons.delete),
            label: const Text('删除'),
          ),
        ],
      ),
    );
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

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final book = _book;
    if (book == null) {
      return const Center(child: Text('未找到书籍'));
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
          Text('作者：${book.author!}'),
        ],
        const SizedBox(height: 16),
        Text('格式：${book.format == BookFormat.epub ? 'EPUB' : 'PDF'}'),
        Text('文件大小：${_humanSize(book.fileSizeBytes)}'),
        Text('添加时间：${book.addedAt.toLocal()}'),
        if (book.lastReadAt != null)
          Text('最近阅读：${book.lastReadAt!.toLocal()}'),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.article_outlined),
          title: const Text('查看笔记'),
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
        title: const Text('删除书籍？'),
        content: Text(
          '《${book.title}》及其阅读进度和高亮笔记都会被删除，无法恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '删除',
              style: TextStyle(color: Colors.red),
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
          Navigator.of(context).maybePop();
        }
      }
    }
  }
}
