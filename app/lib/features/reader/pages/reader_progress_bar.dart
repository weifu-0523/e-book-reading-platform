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
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine_pdf_view/pdf_reader_engine.dart';
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';

import '../widgets/reader_bottom_bar.dart';

/// ReaderProgressBar 估算高度（vertical:8 padding + bodyMedium ~16 行高 + 8）。
///
/// 用于 reader_body 的 Stack 给 SelectableRegion 让出底部空间，避免 EPUB
/// Paginator 按完整 viewport 切页后底部文字被不透明 progress bar 遮住
/// （M2.11 回归修复）。
const double kReaderProgressBarHeight = 32.0;

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

  // 2026-07-08 Review P1: initState 注册的 currentLocation$ subscription
  // 之前被丢弃，widget unmount 后 listener 仍挂在 engine 上。dispose cancel。
  StreamSubscription? _locationSub;

  @override
  void initState() {
    super.initState();
    _locationSub = widget.engine.currentLocation$.listen((loc) {
      if (mounted) setState(() => _current = loc);
    });
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ReaderBottomBar(
      chapterTitle: chapterOrPageLabel(_current),
      percent: estimateProgressPercent(_current, pdfPageCount: _pdfPageCount),
      // M2.9: EPUB paged 模式显示本章页码（当前/总）；双页模式显示范围。
      // PDF / scroll / breaks 未算出时为 null，ReaderBottomBar 回退到百分比。
      pageInfo: _epubPageInfo,
    );
  }

  /// M2.9: EPUB paged 模式的本章页码字符串。
  ///
  /// 单页：「3 / 12」（当前页/总页，1-based 显示）。
  /// 双页：「3-4 / 12」（左右两页，孤页只显左）。
  ///
  /// 数据源：`engine.currentSpreadCount`（总）+ `engine.currentSpreadIndex`
  /// （当前 spread）。这两个值在翻页时由 _emitCurrentLocation 触发的
  /// currentLocation$ emit → 本 widget setState 刷新（见 _buildState）。
  String? get _epubPageInfo {
    final engine = widget.engine;
    // 仅 EPUB paged 模式有页码；PDF 用「第 N 页」（chapterOrPageLabel 已处理），
    // scroll 模式无分页概念。
    if (engine is! ConcreteEpubReaderEngine) return null;
    if (engine.paginationMode != PaginationMode.paged) return null;
    final total = engine.currentSpreadCount;
    if (total <= 0) return null;
    final spreadIdx = engine.currentSpreadIndex.clamp(0, total - 1);
    // 单页模式：spreadIdx == pageIdx，显示「当前/总」。
    if (!engine.dualPageMode) {
      return '${spreadIdx + 1} / $total';
    }
    // 双页模式：spread[i] 含 breaks[i*2] (左) + breaks[i*2+1] (右)。
    // 左页号 = spreadIdx*2 + 1（1-based），右页号 = 左 + 1。
    final breaks = engine.currentChapterPageBreaks;
    final leftPageNo = spreadIdx * 2 + 1;
    final rightPageNo = leftPageNo + 1;
    final hasRight = (spreadIdx * 2 + 1) < breaks.length;
    // 总页数显示 break 总数（列数），不是 spread 数 —— 用户感知的是「页」。
    final totalCols = breaks.length;
    if (!hasRight) {
      return '$leftPageNo / $totalCols';
    }
    return '$leftPageNo-$rightPageNo / $totalCols';
  }

  /// PDF 总页数（仅 PdfReaderEngine 暴露；EPUB 引擎此值为 null）。
  int? get _pdfPageCount {
    final engine = widget.engine;
    if (engine is PdfReaderEngine) return engine.pageCount;
    return null;
  }
}
