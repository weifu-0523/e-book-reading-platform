import 'package:flutter/material.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/navigation/toc.dart';

import '../../../gen_l10n/app_localizations.dart';
import '../../ai/providers/book_preprocess_controller.dart';

/// 用于为 TocEntry 解析 chapterIndex 的回调（仅 EPUB CFI locator 有此信息）。
/// 返回 null 时该 entry 不渲染 AI 状态标记。
typedef TocChapterIndexResolver = int? Function(TocEntry entry);

class TocDrawer extends StatelessWidget {
  final TableOfContents toc;
  final ValueChanged<TocEntry> onSelect;

  /// 可选：当前书籍的预处理状态。对每个 entry 解析其 chapterIndex，依据
  /// [PreprocessState.summarizedChapters] / [PreprocessState.failedChapters]
  /// 渲染渐进 ✓/⚠ 标记（无需等到 [PreprocessStatus.done]）。
  /// 为 null 或 chapterIndex 无法解析时不渲染任何标记。
  final PreprocessState? preprocessState;

  /// 可选：从 [TocEntry] 解析出 0-based chapterIndex（通常取自
  /// [EpubCfiLocator.chapterIndex]）。仅在 [preprocessState] 非 null 时使用。
  final TocChapterIndexResolver? chapterIndexResolver;

  /// 可选：用户点击“回顾本章”按钮时回调的章节索引（来自
  /// [chapterIndexResolver]）。为 null 时不渲染按钮。
  final ValueChanged<int>? onReviewChapter;

  const TocDrawer({
    super.key,
    required this.toc,
    required this.onSelect,
    this.preprocessState,
    this.chapterIndexResolver,
    this.onReviewChapter,
  });

  @override
  Widget build(BuildContext context) {
    if (toc.entries.isEmpty) {
      return const Center(child: Text('本书无目录'));
    }
    return ListView.builder(
      itemCount: toc.entries.length,
      itemBuilder: (context, index) {
        final entry = toc.entries[index];
        return _TocTile(
          entry: entry,
          depth: 0,
          onSelect: onSelect,
          preprocessState: preprocessState,
          chapterIndexResolver: chapterIndexResolver,
          onReviewChapter: onReviewChapter,
        );
      },
    );
  }
}

class _TocTile extends StatelessWidget {
  final TocEntry entry;
  final int depth;
  final ValueChanged<TocEntry> onSelect;
  final PreprocessState? preprocessState;
  final TocChapterIndexResolver? chapterIndexResolver;
  final ValueChanged<int>? onReviewChapter;

  const _TocTile({
    required this.entry,
    required this.depth,
    required this.onSelect,
    this.preprocessState,
    this.chapterIndexResolver,
    this.onReviewChapter,
  });

  @override
  Widget build(BuildContext context) {
    final marker = _buildMarker();
    final reviewButton = _buildReviewButton(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.only(left: 16.0 + depth * 16.0, right: 16.0),
      title: InkWell(
        onTap: () => onSelect(entry),
        child: Row(
          children: [
            Expanded(child: Text(entry.title)),
            if (marker != null) marker,
            if (reviewButton != null) reviewButton,
          ],
        ),
      ),
      children: entry.children
          .map((child) => _TocTile(
                entry: child,
                depth: depth + 1,
                onSelect: onSelect,
                preprocessState: preprocessState,
                chapterIndexResolver: chapterIndexResolver,
                onReviewChapter: onReviewChapter,
              ))
          .toList(),
    );
  }

  /// ⚠ amber when chapter in failedChapters;
  /// ✓ green when chapter in summarizedChapters (regardless of run status);
  /// null otherwise. Renders progressively as each chapter finishes so users
  /// see markers appear before [PreprocessStatus.done].
  Widget? _buildMarker() {
    final state = preprocessState;
    final resolver = chapterIndexResolver;
    if (state == null || resolver == null) return null;
    final idx = resolver(entry);
    if (idx == null) return null;
    final failed = state.failedChapters.contains(idx);
    if (failed) {
      return const Padding(
        padding: EdgeInsets.only(left: 8),
        child: Icon(Icons.warning_amber_rounded,
            size: 18, color: Colors.orange),
      );
    }
    if (state.summarizedChapters.contains(idx)) {
      return const Padding(
        padding: EdgeInsets.only(left: 8),
        child: Icon(Icons.check_circle_outline,
            size: 18, color: Colors.green),
      );
    }
    return null;
  }

  /// Renders the “回顾本章” IconButton when [onReviewChapter] is provided
  /// AND the chapter's index can be resolved. The button is enabled only
  /// for chapters already in [PreprocessState.summarizedChapters]
  /// (`onPressed: null` otherwise → Material renders a disabled state).
  Widget? _buildReviewButton(BuildContext context) {
    final callback = onReviewChapter;
    final resolver = chapterIndexResolver;
    if (callback == null || resolver == null) return null;
    final idx = resolver(entry);
    if (idx == null) return null;
    final l10n = AppLocalizations.of(context);
    final isSummarized =
        preprocessState?.summarizedChapters.contains(idx) ?? false;
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      iconSize: 20,
      icon: const Icon(Icons.rate_review_outlined),
      tooltip: l10n?.reviewButtonLabel,
      onPressed: isSummarized ? () => callback(idx) : null,
    );
  }
}

/// 默认 chapterIndex 解析器：仅识别 [EpubCfiLocator]，返回其 chapterIndex。
/// PDF / 其它 locator 类型返回 null。
int? defaultTocChapterIndex(TocEntry entry) {
  final loc = entry.locator;
  if (loc is EpubCfiLocator) return loc.chapterIndex;
  return null;
}
