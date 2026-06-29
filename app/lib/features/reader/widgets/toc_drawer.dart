import 'package:flutter/material.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/navigation/toc.dart';

import '../../ai/providers/book_preprocess_controller.dart';

/// 用于为 TocEntry 解析 chapterIndex 的回调（仅 EPUB CFI locator 有此信息）。
/// 返回 null 时该 entry 不渲染 AI 状态标记。
typedef TocChapterIndexResolver = int? Function(TocEntry entry);

class TocDrawer extends StatelessWidget {
  final TableOfContents toc;
  final ValueChanged<TocEntry> onSelect;

  /// 可选：当前书籍的预处理状态。若 [PreprocessStatus.done]，对每个 entry
  /// 解析其 chapterIndex，依据 [PreprocessState.failedChapters] 渲染 ✓/⚠。
  /// 为 null 或 idle/chunking/summarizing 时不渲染任何标记。
  final PreprocessState? preprocessState;

  /// 可选：从 [TocEntry] 解析出 0-based chapterIndex（通常取自
  /// [EpubCfiLocator.chapterIndex]）。仅在 [preprocessState] 已 done 时使用。
  final TocChapterIndexResolver? chapterIndexResolver;

  const TocDrawer({
    super.key,
    required this.toc,
    required this.onSelect,
    this.preprocessState,
    this.chapterIndexResolver,
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

  const _TocTile({
    required this.entry,
    required this.depth,
    required this.onSelect,
    this.preprocessState,
    this.chapterIndexResolver,
  });

  @override
  Widget build(BuildContext context) {
    final marker = _buildMarker();
    return ExpansionTile(
      tilePadding: EdgeInsets.only(left: 16.0 + depth * 16.0, right: 16.0),
      title: InkWell(
        onTap: () => onSelect(entry),
        child: Row(
          children: [
            Expanded(child: Text(entry.title)),
            if (marker != null) marker,
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
              ))
          .toList(),
    );
  }

  /// ✓ green when state.done and chapter not failed; ⚠ amber when in failedChapters;
  /// null otherwise.
  Widget? _buildMarker() {
    final state = preprocessState;
    final resolver = chapterIndexResolver;
    if (state == null || resolver == null) return null;
    if (state.status != PreprocessStatus.done) return null;
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
    return const Padding(
      padding: EdgeInsets.only(left: 8),
      child: Icon(Icons.check_circle_outline,
          size: 18, color: Colors.green),
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
