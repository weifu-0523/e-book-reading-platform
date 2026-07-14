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
import 'package:zhiyue/features/reader/widgets/tag_editor.dart';

void main() {
  testWidgets('renders existing tags as chips with remove buttons',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TagEditor(
          tags: const ['哲学', '存在主义'],
          suggestions: const ['哲学', '文学'],
          onChanged: (_) {},
        ),
      ),
    ));
    expect(find.text('哲学'), findsOneWidget);
    expect(find.text('存在主义'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNWidgets(2));
  });

  testWidgets('tapping remove fires onChanged without that tag',
      (tester) async {
    List<String> captured = const [];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TagEditor(
          tags: const ['a', 'b'],
          suggestions: const [],
          onChanged: (t) => captured = t,
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();
    expect(captured, ['b']);
  });

  testWidgets('entering text + done action appends tag', (tester) async {
    List<String> captured = const [];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TagEditor(
          tags: const [],
          suggestions: const [],
          onChanged: (t) => captured = t,
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), '哲学');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(captured, ['哲学']);
  });
}
