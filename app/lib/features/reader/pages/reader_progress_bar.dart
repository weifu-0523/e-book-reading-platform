import 'package:flutter/material.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine_pdf_view/pdf_reader_engine.dart';

import '../widgets/reader_bottom_bar.dart';

/// Extracted from reader_page.dart on T8 (2026-06-30).
///
/// ReaderBottomBar 的章节/页标题 fallback。PDF 用「第 N 页」取代章节标题。
///
/// `loc` 为 null 时返回 null（与原 `_chapterTitle` 行为一致）。
String? chapterOrPageLabel(Locator? loc) {
  if (loc is PdfPageLocator) return '第 ${loc.page} 页';
  if (loc is EpubCfiLocator) return loc.chapterTitle;
  return null;
}

/// Extracted from reader_page.dart on T8 (2026-06-30).
///
/// ReaderBottomBar 的进度比 fallback。PDF 用 page/total，EPUB 沿用
/// chapterIndex/100（M2 MVP 近似）。
///
/// `pdfPageCount` 仅 PDF 路径需要；0 或 null 时 PDF fallback 返回 0（避免除零）。
double estimateProgressPercent(Locator? loc, {int? pdfPageCount}) {
  if (loc is PdfPageLocator) {
    final total = pdfPageCount ?? 0;
    if (total <= 0) return 0.0;
    return (loc.page / total).clamp(0.0, 1.0);
  }
  if (loc is EpubCfiLocator) {
    return (loc.chapterIndex / 100).clamp(0.0, 1.0);
  }
  return 0.0;
}

/// Extracted from reader_page.dart on T8 (2026-06-30).
///
/// 监听 [ReaderEngine.currentLocation$] 的 [ReaderBottomBar] 包装。
///
/// 抽成顶层 widget 让 reader_page.dart 只负责 page-level shell；本类负责
/// 进度条的订阅 + 显示。零行为变化（原 `_ReaderProgressBar` 平移过来）。
class ReaderProgressBar extends StatefulWidget {
  final ReaderEngine engine;

  const ReaderProgressBar({super.key, required this.engine});

  @override
  State<ReaderProgressBar> createState() => _ReaderProgressBarState();
}

class _ReaderProgressBarState extends State<ReaderProgressBar> {
  Locator? _current;

  @override
  void initState() {
    super.initState();
    widget.engine.currentLocation$.listen((loc) {
      if (mounted) setState(() => _current = loc);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ReaderBottomBar(
      chapterTitle: chapterOrPageLabel(_current),
      percent: estimateProgressPercent(_current, pdfPageCount: _pdfPageCount),
    );
  }

  /// PDF 总页数（仅 PdfReaderEngine 暴露；EPUB 引擎此值为 null）。
  int? get _pdfPageCount {
    final engine = widget.engine;
    if (engine is PdfReaderEngine) return engine.pageCount;
    return null;
  }
}
