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

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// 启发式判定「扫描件 PDF」并在 UI 上提示用户的工具。
///
/// 扫描件的特征：原书被图片化为 PDF，没有/极少文本图层。
/// 这类文件做高亮、笔记、FTS 搜索都会失效，所以要在阅读器顶部
/// 显式提示用户。
///
/// 判定策略（保守）：
/// 取前 3 页（或更少）累计的纯文本字符数，< 100 判定为扫描件。
/// 任意一页文本 API 抛异常 → 立即返回 false（无法判定就不提示）。
class PdfScannedDetector {
  PdfScannedDetector._();

  /// 阈值：前 N 页累计字符数 < 此值 → 判定为扫描件。
  static const int _scannedThreshold = 100;

  /// 检查的最大页数（前 N 页足以判定扫描件）。
  static const int _maxCheckPages = 3;

  /// Pure function：给定累计字符数判断是否扫描件。便于单测。
  static bool isLikelyScannedByCharCount(int totalChars) {
    return totalChars < _scannedThreshold;
  }

  /// 前 3 页（或更少）累计文本字符数判断是否扫描件。
  ///
  /// 三种 fallback 情况保守返回 false（不显示 banner，避免误判）：
  /// - pdfrx API 抛异常：任何一页 loadText 失败立刻 return false
  /// - 所有页文本均为空（API 不可用 → 无法判定）：return false
  ///
  /// 性能：3 次 `PdfPage.loadText()`，对扫描件页通常 < 100ms，
  /// 不会阻塞 PDF 首屏渲染（由 PdfRenderer.build 用 cached
  /// FutureBuilder 异步驱动）。
  static Future<bool> isLikelyScanned(PdfDocument doc) async {
    final pageCount = doc.pages.length;
    final checkPages = pageCount < _maxCheckPages ? pageCount : _maxCheckPages;
    var totalChars = 0;
    var anyNonEmpty = false;
    for (var i = 0; i < checkPages; i++) {
      try {
        final text = await _loadPageText(doc.pages[i]);
        if (text.isNotEmpty) anyNonEmpty = true;
        totalChars += text.length;
        // 累计已超阈值就提前退出（不可能再判定为扫描件）。
        if (!isLikelyScannedByCharCount(totalChars)) return false;
      } catch (_) {
        // API 异常 → 无法判定，保守不显示 banner。
        return false;
      }
    }
    if (!anyNonEmpty) return false;
    return isLikelyScannedByCharCount(totalChars);
  }

  /// 调用 pdfrx v2.4.4 的 `PdfPage.loadText()` 取整页纯文本。
  ///
  /// `PdfPage.loadText()` 返回 `Future<PdfPageRawText?>`，可能 null
  /// （页面未加载完时）。`PdfPageRawText.fullText` 即字符串。
  /// 异常向上抛（caller 在 `isLikelyScanned` 里捕获后走 fallback）。
  static Future<String> _loadPageText(PdfPage page) async {
    final raw = await page.loadText();
    return raw?.fullText ?? '';
  }
}

/// 扫描件提示横幅，显示在 PDF 阅读区顶部。
///
/// 设计：`errorContainer` 主题色作为警示底色（自动适配 light/sepia/night），
/// `warning_amber_outlined` 图标 + 简短文案，告知用户高亮/笔记/搜索不可用。
class PdfScannedBanner extends StatelessWidget {
  const PdfScannedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined),
            SizedBox(width: 8),
            Expanded(child: Text('扫描件：高亮、笔记、搜索不可用')),
          ],
        ),
      ),
    );
  }
}
