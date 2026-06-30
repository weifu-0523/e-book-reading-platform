import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/book.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../../services/ai/ai_guide.dart';
import '../../../services/ai/chapter_bullet_parser.dart';
import '../providers/ai_guide_controller.dart';
import 'key_takeaway_actions.dart';

/// AI 导读 bottom sheet.
///
/// Renders the five-state machine driven by [AiGuideController]:
/// idle / loading / streaming / done / error.
///
/// Mode toggle (full / chapter / selection) is exposed via [ToggleButtons].
/// When [modeLocked] is true the toggle is rendered disabled (e.g. when
/// invoked from a selection that has no chapter context).
///
/// In chapter mode + on done, the accumulated text is parsed via
/// [ChapterBulletParser] into (summary, bullets). Each bullet is rendered
/// through [KeyTakeawayActions] with a "加入笔记" affordance that persists
/// the bullet via [BookNotesDao.appendKeyTakeaway].
///
/// Error state picks the recovery button based on the [AiGuideError]:
/// - [AiGuideError.noApiKey] / [AiGuideError.authFailed] → 去设置
/// - [AiGuideError.emptySource] / [AiGuideError.cancelled] → no button
/// - everything else → 重试
class AiGuideSheet extends ConsumerStatefulWidget {
  const AiGuideSheet({
    super.key,
    required this.book,
    required this.initialMode,
    this.selection,
    this.chapterIndex,
    this.chapterTitle,
    this.modeLocked = false,
    this.availableChapters = const [],
  });

  final Book book;
  final AiGuideMode initialMode;
  final String? selection;
  final int? chapterIndex;
  final String? chapterTitle;
  final bool modeLocked;

  /// Chapter picker options for chapter mode. Records are `(index, title)`.
  final List<({int index, String title})> availableChapters;

  @override
  ConsumerState<AiGuideSheet> createState() => _AiGuideSheetState();
}

class _AiGuideSheetState extends ConsumerState<AiGuideSheet> {
  late AiGuideMode _mode = widget.initialMode;
  late int? _chapterIndex = widget.chapterIndex;
  late String? _chapterTitle = widget.chapterTitle;
  late List<bool> _selectedMode = _modeFlags(widget.initialMode);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _kickoff());
  }

  Future<void> _kickoff() async {
    if (!mounted) return;
    final controller = ref.read(aiGuideControllerProvider.notifier);
    switch (widget.initialMode) {
      case AiGuideMode.full:
        await controller.startFullBook(widget.book);
      case AiGuideMode.chapter:
        await controller.startChapter(
          widget.book,
          _chapterIndex ?? 0,
          chapterTitle: _chapterTitle,
        );
      case AiGuideMode.selection:
        await controller.startSelection(
          widget.book,
          widget.selection ?? '',
          chapterTitle: _chapterTitle,
        );
    }
  }

  List<bool> _modeFlags(AiGuideMode m) => [
        m == AiGuideMode.full,
        m == AiGuideMode.chapter,
        m == AiGuideMode.selection,
      ];

  Future<void> _onModeChanged(int idx) async {
    if (widget.modeLocked) return;
    if (idx < 0 || idx >= AiGuideMode.values.length) return;
    final newMode = AiGuideMode.values[idx];
    setState(() {
      _mode = newMode;
      _selectedMode = _modeFlags(newMode);
    });
    final controller = ref.read(aiGuideControllerProvider.notifier);
    switch (newMode) {
      case AiGuideMode.full:
        await controller.startFullBook(widget.book);
      case AiGuideMode.chapter:
        await controller.startChapter(
          widget.book,
          _chapterIndex ?? 0,
          chapterTitle: _chapterTitle,
        );
      case AiGuideMode.selection:
        if (widget.selection == null) return;
        await controller.startSelection(
          widget.book,
          widget.selection!,
          chapterTitle: _chapterTitle,
        );
    }
  }

  Future<void> _onAddBulletToNotes(String bullet) async {
    final db = ref.read(appDatabaseProvider);
    await db.bookNotesDao.appendKeyTakeaway(
      bookId: widget.book.id,
      bookTitle: widget.book.title,
      takeaway: bullet,
      sourceChapter: _chapterTitle,
    );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.aiGuideAddToNotes)),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  void _goToSettings(BuildContext ctx) {
    ctx.push('/settings/ai');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(aiGuideControllerProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(l10n.aiGuideTitle,
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.aiActionClose,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            if (state.status == AiGuideStatus.idle ||
                state.status == AiGuideStatus.loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ToggleButtons(
                  isSelected: _selectedMode,
                  onPressed: widget.modeLocked ? null : _onModeChanged,
                  children: [
                    Text(l10n.aiGuideModeFull),
                    Text(l10n.aiGuideModeChapter),
                    Text(l10n.aiGuideModeSelection),
                  ],
                ),
              ),
            if (_mode == AiGuideMode.chapter &&
                widget.availableChapters.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: DropdownButton<int>(
                  value: _chapterIndex,
                  items: widget.availableChapters
                      .map((c) => DropdownMenuItem(
                            value: c.index,
                            child: Text(
                                '${l10n.aiGuideChapterPrefix} ${c.index + 1} - ${c.title}'),
                          ))
                      .toList(),
                  onChanged: (idx) async {
                    if (idx == null) return;
                    final match = widget.availableChapters.firstWhere(
                      (c) => c.index == idx,
                      orElse: () => widget.availableChapters.first,
                    );
                    setState(() {
                      _chapterIndex = idx;
                      _chapterTitle = match.title;
                    });
                    final controller =
                        ref.read(aiGuideControllerProvider.notifier);
                    await controller.startChapter(
                      widget.book,
                      idx,
                      chapterTitle: match.title,
                    );
                  },
                ),
              ),
            const Divider(),
            Expanded(
              child: _buildBody(ctx, state, scrollController, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext ctx,
    AiStreamState state,
    ScrollController sc,
    AppLocalizations l10n,
  ) {
    switch (state.status) {
      case AiGuideStatus.idle:
        return Center(
          child: FilledButton(
            onPressed: _kickoff,
            child: Text(l10n.aiGuideStart),
          ),
        );
      case AiGuideStatus.loading:
        return LoadingView(message: l10n.aiGuideLoadingExtract);
      case AiGuideStatus.streaming:
        return ListView(
          controller: sc,
          padding: const EdgeInsets.all(16),
          children: [
            SelectableText(state.accumulatedText),
            const SizedBox(height: 12),
            Text(l10n.aiGuideLoadingGenerate,
                style: Theme.of(ctx).textTheme.bodySmall),
          ],
        );
      case AiGuideStatus.done:
        final parsed = _mode == AiGuideMode.chapter
            ? ChapterBulletParser.parse(state.accumulatedText)
            : null;
        return ListView(
          controller: sc,
          padding: const EdgeInsets.all(16),
          children: [
            if (state.fromCache)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l10n.aiGuideCacheHit,
                    style: Theme.of(ctx).textTheme.bodySmall),
              ),
            SelectableText(parsed?.summary ?? state.accumulatedText),
            if (parsed != null && parsed.bullets.isNotEmpty) ...[
              const SizedBox(height: 16),
              KeyTakeawayActions(
                bullets: parsed.bullets,
                onAddToNotes: _onAddBulletToNotes,
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _copyToClipboard(state.accumulatedText),
                  icon: const Icon(Icons.copy_outlined),
                  label: Text(l10n.aiGuideCopy),
                ),
                if (state.fromCache)
                  TextButton.icon(
                    onPressed: _kickoff,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.aiGuideRegenerate),
                  ),
              ],
            ),
          ],
        );
      case AiGuideStatus.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorLabel(state.error, l10n),
                  style:
                      TextStyle(color: Theme.of(ctx).colorScheme.error)),
              const SizedBox(height: 12),
              if (state.error == AiGuideError.noApiKey ||
                  state.error == AiGuideError.authFailed)
                FilledButton(
                  onPressed: () => _goToSettings(ctx),
                  child: Text(l10n.aiActionGoSettings),
                )
              else if (state.error != AiGuideError.emptySource &&
                  state.error != AiGuideError.cancelled)
                FilledButton(
                  onPressed: _kickoff,
                  child: Text(l10n.aiGuideRetry),
                ),
            ],
          ),
        );
    }
  }

  String _errorLabel(AiGuideError? e, AppLocalizations l10n) {
    switch (e) {
      case AiGuideError.noApiKey:
        return l10n.aiErrorNoKey;
      case AiGuideError.authFailed:
        return l10n.aiErrorAuthFailed;
      case AiGuideError.rateLimited:
        return l10n.aiErrorRateLimited;
      case AiGuideError.serverError:
        return l10n.aiErrorServer;
      case AiGuideError.network:
        return l10n.aiErrorNetwork;
      case AiGuideError.emptySource:
        return l10n.aiErrorEmptySource;
      case AiGuideError.parseError:
        return l10n.aiErrorParse;
      case AiGuideError.cancelled:
        return l10n.aiErrorCancelled;
      default:
        return l10n.aiErrorServer;
    }
  }
}
