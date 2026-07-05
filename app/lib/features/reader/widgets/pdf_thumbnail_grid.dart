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

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// M4.6/T5：PDF 无目录时的页面缩略图导航 grid。
///
/// 背景：pdfrx 渲染的 PDF 若没有内嵌书签，[TocDrawer] 之前只显示「本书无目录」
/// 空文案。本 widget 用 `PdfPage.render()` 异步渲染每页缩略图，配合
/// [GridView.builder] 懒加载（仅构建可视 cell + 缓存窗口），点击 cell 跳页。
///
/// 内存管理：
/// - LRU 缓存上限 32 张（[_maxCache]），超出淘汰最旧的 `ui.Image` 并 dispose
/// - 渲染中的页索引记入 [_rendering]，避免重复触发
/// - widget dispose 时统一 dispose 全部缓存 image，防 native 泄漏
///
/// pdfrx 2.4.4 API 适配（与 plan 骨架不同）：
/// - `PdfPage.render()` 返回 `Future<PdfImage?>`（原始 BGRA 像素），不是
///   `PdfPageImage`；用 `PdfImageExt.createImage()`（pdfrx_flutter 导出）
///   转成 `ui.Image`，转换后立即 dispose `PdfImage` 释放像素 buffer。
/// - render 用 `fullWidth` / `fullHeight` 指定目标像素尺寸（不是 width/height）。
class PdfThumbnailGrid extends StatefulWidget {
  const PdfThumbnailGrid({
    super.key,
    required this.document,
    required this.currentPage,
    required this.onPageSelected,
  });

  /// 已打开的 PDF 文档（来自 [PdfReaderEngine.rendererRef].doc）。
  final PdfDocument document;

  /// 当前页索引（0-based，与 PdfRenderer.currentPage 一致），用于高亮当前页。
  final int currentPage;

  /// 用户点击某页缩略图时的回调，参数为 0-based 页索引。
  /// 调用方负责转 1-based 构造 [PdfPageLocator] 并跳转。
  final ValueChanged<int> onPageSelected;

  @override
  State<PdfThumbnailGrid> createState() => _PdfThumbnailGridState();
}

class _PdfThumbnailGridState extends State<PdfThumbnailGrid> {
  /// LRU 缓存：page index → ui.Image。容量 [_maxCache]，超出淘汰最旧。
  /// Dart Map 保持插入顺序，`keys.first` 即最久未更新的 key。
  final _cache = <int, ui.Image>{};
  static const int _maxCache = 32;

  /// 正在渲染的 page index 集合（避免同一页重复触发 render）。
  final _rendering = <int>{};

  @override
  void dispose() {
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
    super.dispose();
  }

  /// 幂等渲染某页缩略图。[_cache] / [_rendering] 双重检查避免重复。
  /// 渲染失败时静默忽略（cell 留空 loading 态），不阻塞其他页。
  Future<void> _renderThumbnail(int pageIndex) async {
    if (_cache.containsKey(pageIndex) || _rendering.contains(pageIndex)) return;
    if (pageIndex < 0 || pageIndex >= widget.document.pages.length) return;
    _rendering.add(pageIndex);
    try {
      final page = widget.document.pages[pageIndex];
      // 缩略图目标宽度（CSS px 级别，足够清晰又省内存）。按 PDF 页宽高比例算高度。
      const thumbWidth = 200.0;
      final scale = thumbWidth / page.width;
      final thumbHeight = page.height * scale;
      // pdfrx：fullWidth/fullHeight 指定完整渲染目标尺寸。
      // backgroundColor 默认白色（0xffffffff）正是 PDF 期望背景，无需显式传。
      final pdfImage = await page.render(
        fullWidth: thumbWidth,
        fullHeight: thumbHeight,
      );
      if (pdfImage == null) return;
      // PdfImage（原始像素）→ ui.Image（GPU 上传）。转换后立即释放像素 buffer。
      final uiImage = await pdfImage.createImage();
      pdfImage.dispose();
      if (!mounted) {
        uiImage.dispose();
        return;
      }
      setState(() {
        _cache[pageIndex] = uiImage;
        // LRU 淘汰最旧的（Map.keys 按插入序）。
        while (_cache.length > _maxCache) {
          final oldestKey = _cache.keys.first;
          _cache[oldestKey]?.dispose();
          _cache.remove(oldestKey);
        }
      });
    } catch (e) {
      // 渲染失败：留空 cell（持续 loading），不阻塞其他页。
      debugPrint('PDF thumbnail render failed for page $pageIndex: $e');
    } finally {
      _rendering.remove(pageIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        // PDF 页通常竖长（A4 ≈ 0.707）；用 0.7 让 cell 高瘦贴合页比例。
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: widget.document.pages.length,
      itemBuilder: (context, index) {
        final thumb = _cache[index];
        final isCurrent = index == widget.currentPage;

        // 触发渲染：post-frame callback 避免在 build 中 setState 报错。
        // builder 本身只构建可视 + 缓存窗口内的 cell，天然懒加载。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _renderThumbnail(index);
        });

        return GestureDetector(
          onTap: () => widget.onPageSelected(index),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isCurrent
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
                width: isCurrent ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: thumb == null
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: RawImage(
                      image: thumb,
                      fit: BoxFit.contain,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
