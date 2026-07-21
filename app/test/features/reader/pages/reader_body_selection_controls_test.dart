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

void main() {
  group('reader_body SelectableRegion selection toolbar (v1.14.1-alpha Bug)', () {
    // Bug 摘要：v1.14.0-alpha 及之前，reader_body 的 SelectableRegion 配置了
    // `selectionControls: materialTextSelectionControls`，导致移动端选中文字时
    // 同时弹出两个 toolbar：
    //  1. Flutter 框架默认 toolbar（Copy / Share / Select All，系统风格长条白卡）
    //  2. 项目自定义 toolbar（摘录 / 复制 / 朗读 / 问 AI，由 ReaderSelectionToolbar 渲染）
    //
    // 修复：把 selectionControls 显式改为 null。Flutter 框架不再渲染默认 toolbar，
    // 只剩我们自己的四按钮弹片。
    //
    // 这里做防御性静态断言（沿用 database_migration_v14_test.dart 的 degraded
    // fallback 模式），防止未来 PR 不小心把 materialTextSelectionControls 加回来。
    // widget test 难以稳定触发框架 toolbar 的渲染时机（pump 时机 + 选区几何），
    // 源码断言是更稳的保护。

    test('reader_body does NOT reference materialTextSelectionControls', () {
      final source = File(_readerBodyPath).readAsStringSync();
      expect(
        source,
        isNot(contains('materialTextSelectionControls')),
        reason: 'reader_body 必须禁用 Flutter 默认 selection toolbar；'
            '选区 UI 由 ReaderSelectionToolbar 接管（摘录/复制/朗读/问 AI）。',
      );
    });

    test(
        'reader_body wires NoToolbarSelectionControls (handle-only, no default toolbar)',
        () {
      final source = File(_readerBodyPath).readAsStringSync();
      expect(
        source,
        contains('noToolbarSelectionControls'),
        reason: 'SelectableRegion.selectionControls 必须使用 NoToolbarSelectionControls，'
            '让 Flutter 框架检测到 TextSelectionHandleControls mixin 后 hideToolbar。'
            'handles 仍由 MaterialTextSelectionControls 提供（移动端可拖动调整选区）。',
      );
    });
  });
}
