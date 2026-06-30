import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_providers.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/book.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../../services/ai/book_qa_service.dart';
import '../providers/book_preprocess_controller.dart';
import '../providers/qa_controller.dart';
import 'qa_answer_view.dart';

/// Same-book Q&A dialog. Scaffold with input field + submit button; the body
/// is driven by [QaStatus] (idle hint, loading spinner, streaming/done
/// answer, error message). When a citation is tapped, the dialog pops itself
/// and forwards the chapter index to [onCitationTap] — T14 wires that to
/// `engine.gotoTocEntry` + `chapterSwitchSettled`.
///
/// The dialog accepts an optional [book]; without one, submit is a no-op
/// (the controller's `ask` needs a `Book`). T14 always passes the book; tests
/// that drive submit also pass it.
class QaAskDialog extends ConsumerStatefulWidget {
  const QaAskDialog({
    super.key,
    required this.bookId,
    this.book,
    this.onCitationTap,
  });

  final String bookId;
  final Book? book;
  final void Function(int chapterIndex)? onCitationTap;

  @override
  ConsumerState<QaAskDialog> createState() => _QaAskDialogState();
}

class _QaAskDialogState extends ConsumerState<QaAskDialog> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  Future<void> _loadHistory() async {
    final dao = ref.read(qaHistoryDaoProvider);
    final rows = await dao.getByBook(widget.bookId, limit: 5);
    if (!mounted) return;
    ref.read(qaControllerProvider(widget.bookId).notifier).setHistory(rows);
  }

  Future<void> _deleteHistoryEntry(String id) async {
    await ref.read(qaHistoryDaoProvider).deleteEntry(id);
    if (!mounted) return;
    await _loadHistory();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.qaHistoryDeleted)),
    );
  }

  void _resubmit(String question) {
    _controller.text = question;
    _submit();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    final book = widget.book;
    if (book == null) return;
    ref
        .read(qaControllerProvider(widget.bookId).notifier)
        .ask(book: book, question: q);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final state = ref.watch(qaControllerProvider(widget.bookId));
    final preprocess =
        ref.watch(bookPreprocessControllerProvider(widget.bookId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l.qaDialogTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: l.qaInputHint,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 8),
                if (state.status == QaStatus.streaming)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: () => ref
                          .read(qaControllerProvider(widget.bookId).notifier)
                          .reset(),
                      child: Text(l.qaStopLabel),
                    ),
                  ),
                FilledButton(
                  onPressed: _submit,
                  child: Text(l.qaSubmitLabel),
                ),
              ],
            ),
          ),
          if (_isPreprocessing(preprocess))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l.qaPreprocessInProgress(
                    '${preprocess.currentChapter}',
                    '${preprocess.totalChapters}',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            ),
          if (state.history.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l.qaHistoryLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: state.history.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final entry = state.history[i];
                  // ActionChip has no onLongPress, so wrap with a
                  // translucent GestureDetector that only listens to
                  // long-press; taps still reach the chip's onPressed and
                  // keep its ink ripple.
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onLongPress: () => _deleteHistoryEntry(entry.id),
                    child: ActionChip(
                      label: Text(entry.question),
                      onPressed: () => _resubmit(entry.question),
                    ),
                  );
                },
              ),
            ),
          ],
          Expanded(child: _buildBody(context, state, l)),
        ],
      ),
    );
  }

  bool _isPreprocessing(PreprocessState preprocess) =>
      preprocess.status == PreprocessStatus.chunking ||
      preprocess.status == PreprocessStatus.summarizing;

  Widget _buildBody(BuildContext context, QaState state, AppLocalizations l) {
    switch (state.status) {
      case QaStatus.idle:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.qaEmptyHint),
          ),
        );
      case QaStatus.loading:
        return const LoadingView();
      case QaStatus.streaming:
      case QaStatus.done:
        if (state.answer.isEmpty) {
          return const SizedBox.shrink();
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: QaAnswerView(
            answer: state.answer,
            onCitationTap: (n) {
              final cb = widget.onCitationTap;
              if (cb == null) return;
              Navigator.of(context).maybePop();
              cb(n);
            },
          ),
        );
      case QaStatus.error:
        return _ErrorView(error: state.error ?? QaError.serverError, l: l);
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.l});
  final QaError error;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final msg = switch (error) {
      QaError.noApiKey => l.qaErrorNoKey,
      QaError.emptyIndex => l.qaErrorEmptyIndex,
      QaError.authFailed => l.qaErrorAuth,
      QaError.rateLimited => l.qaErrorRateLimit,
      QaError.network => l.qaErrorNetwork,
      QaError.serverError => l.qaErrorServer,
      QaError.parseError => l.qaErrorParse,
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(msg),
      ),
    );
  }
}
