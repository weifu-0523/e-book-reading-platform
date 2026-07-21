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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _readerBodyPath = 'lib/features/reader/pages/reader_body.dart';
const _epubxRendererPath = '../reader_engine_epub_view/lib/epubx_renderer.dart';
const _selectablePageViewPath =
    '../reader_engine_epub_view/lib/selectable_page_view.dart';

void main() {
  group('reader selection context menu (v1.14.2-alpha Bug)', () {
    // Bug 摘要：v1.14.1-alpha 之前 reader_body 的 SelectableRegion 用了
    // materialTextSelectionControls，被误认为是「白色长条 toolbar」的来源。
    // v1.14.1-alpha 修了 selectionControls，但用户报告「卡片还在」。
    //
    // 真根因：SelectionArea / SelectableRegion 的 contextMenuBuilder 默认值
    // 构建 AdaptiveTextSelectionToolbar（Copy/Share/SelectAll）。selectionControls
    // 在 framework 检测到 TextSelectionHandleControls mixin 后完全被跳过
    // （selectable_region.dart:1374-1387），与 toolbar 显示无关。
    //
    // 真修复：所有 SelectionArea 和 SelectableRegion 必须显式传
    // `contextMenuBuilder: emptySelectionContextMenu`（来自
    // reader_engine_epub_view/lib/src/no_selection_toolbar.dart），
    // 让 contextMenu overlay 渲染为 SizedBox.shrink()。
    //
    // 这里做防御性静态断言（沿用 database_migration_v14_test.dart 的 degraded
    // fallback 模式），防止未来 PR 忘记传 contextMenuBuilder。

    test('reader_body SelectableRegion wires emptySelectionContextMenu', () {
      final source = File(_readerBodyPath).readAsStringSync();
      expect(
        source,
        contains('emptySelectionContextMenu'),
        reason: 'SelectableRegion 必须传 contextMenuBuilder: '
            'emptySelectionContextMenu，否则 Flutter 框架默认 toolbar '
            '(AdaptiveTextSelectionToolbar) 仍会显示。',
      );
    });

    test('epubx_renderer.dart all SelectionArea wire emptySelectionContextMenu',
        () {
      final source = File(_epubxRendererPath).readAsStringSync();
      // 至少 4 处 SelectionArea（main paged + dual page left/right + fwfh fallback）
      final count = 'SelectionArea('.allMatches(source).length;
      expect(count, greaterThanOrEqualTo(4),
          reason: 'epubx_renderer.dart 应该至少有 4 处 SelectionArea');
      // 每处都应传 contextMenuBuilder
      final contextMenuCount = 'emptySelectionContextMenu'.allMatches(source).length;
      expect(contextMenuCount, greaterThanOrEqualTo(4),
          reason: '所有 SelectionArea 必须传 contextMenuBuilder: '
              'emptySelectionContextMenu；找到 $count 处 SelectionArea 但只有 '
              '$contextMenuCount 处 wiring。');
    });

    test('selectable_page_view.dart SelectionArea wires emptySelectionContextMenu',
        () {
      final source = File(_selectablePageViewPath).readAsStringSync();
      expect(
        source,
        contains('emptySelectionContextMenu'),
        reason: 'SelectablePageView 内的 SelectionArea 必须传 '
            'contextMenuBuilder: emptySelectionContextMenu。',
      );
    });
  });
}
