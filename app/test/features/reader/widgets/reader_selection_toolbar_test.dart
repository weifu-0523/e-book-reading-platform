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
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/widgets/highlight_selection_controls.dart';
import 'package:zhiyue/features/reader/widgets/reader_selection_toolbar.dart';

void main() {
  group('ReaderSelectionToolbar', () {
    testWidgets('renders nothing when selection is null', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Text('underlying content'),
              ReaderSelectionToolbar(
                selection: null,
                onExcerpt: () {},
                onCopy: () {},
                onAiComment: () {},
              ),
            ],
          ),
        ),
      ));
      expect(find.byType(HighlightSelectionControls), findsNothing);
    });

    testWidgets('renders nothing when selection plainText is empty',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Text('underlying content'),
              ReaderSelectionToolbar(
                selection: const SelectedContent(plainText: ''),
                onExcerpt: () {},
                onCopy: () {},
                onAiComment: () {},
              ),
            ],
          ),
        ),
      ));
      expect(find.byType(HighlightSelectionControls), findsNothing);
    });

    testWidgets('renders HighlightSelectionControls when selection non-empty',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: Stack(
              children: [
                const Text('underlying content'),
                ReaderSelectionToolbar(
                  selection: const SelectedContent(plainText: 'highlighted text'),
                  onExcerpt: () {},
                  onCopy: () {},
                  onAiComment: () {},
                ),
              ],
            ),
          ),
        ),
      ));
      expect(find.byType(HighlightSelectionControls), findsOneWidget);
    });

    testWidgets('fires onExcerpt callback when controls invoke it',
        (tester) async {
      var excerptCount = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: Stack(
              children: [
                ReaderSelectionToolbar(
                  selection: const SelectedContent(plainText: 'text'),
                  onExcerpt: () => excerptCount++,
                  onCopy: () {},
                  onAiComment: () {},
                ),
              ],
            ),
          ),
        ),
      ));
      final controls = tester.widget<HighlightSelectionControls>(
        find.byType(HighlightSelectionControls),
      );
      controls.onExcerpt();
      expect(excerptCount, 1);
    });
  });
}
