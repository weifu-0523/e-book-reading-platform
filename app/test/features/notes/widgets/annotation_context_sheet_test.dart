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
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/notes/widgets/annotation_context_sheet.dart';

/// Holds the result of [showAnnotationContextMenu] across the async gap.
class _Holder {
  AnnotationContextAction? result;
  bool completed = false;
}

/// Pumps a host with a button that opens the menu, taps the button, settles
/// the menu-open animation. The menu stays open so the test can inspect or
/// pick an item. [holder] is filled when the menu resolves.
Future<_Holder> _open(WidgetTester tester, _Holder holder) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) => Center(
          child: ElevatedButton(
            onPressed: () async {
              final action = await showAnnotationContextMenu(
                  ctx, const Offset(100, 100));
              holder
                ..result = action
                ..completed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return holder;
}

/// Pick a menu item by label and wait for the menu future to resolve.
Future<void> _pick(WidgetTester tester, _Holder holder, String label) async {
  await tester.tap(find.text(label));
  // Pump until the menu's pop resolves the showMenu future.
  while (!holder.completed) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('showAnnotationContextMenu (desktop right-click menu)', () {
    testWidgets('renders 5 menu items with correct labels', (tester) async {
      await _open(tester, _Holder());
      expect(find.text('编辑笔记'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
      expect(find.text('复制摘录'), findsOneWidget);
      expect(find.text('复制 Markdown 片段'), findsOneWidget);
      expect(find.text('导出'), findsOneWidget);
      // 5 PopupMenuItem total.
      expect(find.byType(PopupMenuItem<AnnotationContextAction>),
          findsNWidgets(5));
    });

    testWidgets('selecting 编辑笔记 returns edit', (tester) async {
      final holder = _Holder();
      await _open(tester, holder);
      await _pick(tester, holder, '编辑笔记');
      expect(holder.result, AnnotationContextAction.edit);
    });

    testWidgets('selecting 删除 returns delete', (tester) async {
      final holder = _Holder();
      await _open(tester, holder);
      await _pick(tester, holder, '删除');
      expect(holder.result, AnnotationContextAction.delete);
    });

    testWidgets('selecting 复制摘录 returns copyQuote', (tester) async {
      final holder = _Holder();
      await _open(tester, holder);
      await _pick(tester, holder, '复制摘录');
      expect(holder.result, AnnotationContextAction.copyQuote);
    });

    testWidgets('selecting 复制 Markdown 片段 returns copyMarkdown',
        (tester) async {
      final holder = _Holder();
      await _open(tester, holder);
      await _pick(tester, holder, '复制 Markdown 片段');
      expect(holder.result, AnnotationContextAction.copyMarkdown);
    });

    testWidgets('selecting 导出 returns export', (tester) async {
      final holder = _Holder();
      await _open(tester, holder);
      await _pick(tester, holder, '导出');
      expect(holder.result, AnnotationContextAction.export);
    });

    testWidgets('dismiss (barrier) returns null', (tester) async {
      final holder = _Holder();
      await _open(tester, holder);
      await tester.tapAt(const Offset(10, 10));
      while (!holder.completed) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(holder.result, isNull);
    });
  });
}
