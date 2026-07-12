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
import 'package:zhiyue/features/library/widgets/tag_editor.dart';

void main() {
  group('TagEditor', () {
    testWidgets('renders existing tags as InputChips', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TagEditor(
            tags: const ['AI', '哲学'],
            suggestions: const {},
            onChanged: (_) {},
          ),
        ),
      ));

      expect(find.text('AI'), findsOneWidget);
      expect(find.text('哲学'), findsOneWidget);
      expect(find.byType(InputChip), findsNWidgets(2));
    });

    testWidgets('renders add button when not adding', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TagEditor(
            tags: const ['AI'],
            suggestions: const {},
            onChanged: (_) {},
          ),
        ),
      ));

      expect(find.byKey(const Key('tag-editor-add-btn')), findsOneWidget);
      // Input field should not be visible yet
      expect(find.byKey(const Key('tag-editor-input')), findsNothing);
    });

    testWidgets('add button expands text field on tap', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TagEditor(
            tags: const ['AI'],
            suggestions: const {},
            onChanged: (_) {},
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('tag-editor-add-btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tag-editor-input')), findsOneWidget);
    });

    testWidgets('valid tag submits via keyboard action and calls onChanged',
        (tester) async {
      List<String>? captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TagEditor(
            tags: const ['AI'],
            suggestions: const {},
            onChanged: (tags) => captured = tags,
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('tag-editor-add-btn')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('tag-editor-input')),
        '新书签',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured, containsAll(['AI', '新书签']));
      expect(captured!.length, 2);
    });

    testWidgets('valid tag submits via confirm icon button', (tester) async {
      List<String>? captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TagEditor(
            tags: const ['AI'],
            suggestions: const {},
            onChanged: (tags) => captured = tags,
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('tag-editor-add-btn')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('tag-editor-input')),
        '新书签',
      );
      await tester.tap(find.byKey(const Key('tag-editor-confirm-btn')));
      await tester.pumpAndSettle();

      expect(captured, containsAll(['AI', '新书签']));
    });

    testWidgets(
        'rejects input containing __ (sync composite key separator)',
        (tester) async {
      List<String>? captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TagEditor(
            tags: const [],
            suggestions: const {},
            onChanged: (tags) => captured = tags,
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('tag-editor-add-btn')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('tag-editor-input')),
        'bad__tag',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should NOT call onChanged
      expect(captured, isNull);
      // The widget clears the offending input, so the only '__' remaining
      // in the tree is the validation error rendered via InputDecoration.
      expect(find.textContaining('__'), findsOneWidget);
      // Input should remain visible so user can retry
      expect(find.byKey(const Key('tag-editor-input')), findsOneWidget);
    });

    testWidgets('rejects empty input after trim', (tester) async {
      List<String>? captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TagEditor(
            tags: const [],
            suggestions: const {},
            onChanged: (tags) => captured = tags,
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('tag-editor-add-btn')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('tag-editor-input')),
        '   ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(captured, isNull);
      // Input still visible
      expect(find.byKey(const Key('tag-editor-input')), findsOneWidget);
    });

    testWidgets('rejects duplicates case-insensitive', (tester) async {
      List<String>? captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TagEditor(
            tags: const ['AI'],
            suggestions: const {},
            onChanged: (tags) => captured = tags,
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('tag-editor-add-btn')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('tag-editor-input')),
        'ai',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(captured, isNull);
      // Should show some error text
      expect(find.byKey(const Key('tag-editor-input')), findsOneWidget);
    });

    testWidgets('maxLength enforces 32-char limit (truncates input)',
        (tester) async {
      List<String>? captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TagEditor(
            tags: const [],
            suggestions: const {},
            onChanged: (tags) => captured = tags,
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('tag-editor-add-btn')));
      await tester.pumpAndSettle();

      // Attempt to type 33 chars. TextField.maxLength truncates input at 32,
      // so the resulting tag will be exactly 32 chars (not 33).
      final longTag = 'a' * 33;
      await tester.enterText(
        find.byKey(const Key('tag-editor-input')),
        longTag,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Resulting tag should be exactly 32 chars (enforced by maxLength).
      expect(captured, isNotNull);
      expect(captured!.length, 1);
      expect(captured!.first.length, 32);
    });

    testWidgets('tap delete icon on InputChip removes that tag',
        (tester) async {
      List<String>? captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TagEditor(
            tags: const ['AI', '哲学'],
            suggestions: const {},
            onChanged: (tags) => captured = tags,
          ),
        ),
      ));

      // The TagEditor sets a Keyed deleteIcon on each InputChip so the test
      // can target the delete affordance robustly across Flutter versions.
      await tester.tap(find.byKey(const ValueKey('tag-editor-delete-icon')).first);
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured, ['哲学']);
    });

    testWidgets('cancel button hides input without calling onChanged',
        (tester) async {
      List<String>? captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TagEditor(
            tags: const ['AI'],
            suggestions: const {},
            onChanged: (tags) => captured = tags,
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('tag-editor-add-btn')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('tag-editor-input')),
        'aborted',
      );
      await tester.tap(find.byKey(const Key('tag-editor-cancel-btn')));
      await tester.pumpAndSettle();

      // No change emitted
      expect(captured, isNull);
      // Input collapsed
      expect(find.byKey(const Key('tag-editor-input')), findsNothing);
      // Add button visible again
      expect(find.byKey(const Key('tag-editor-add-btn')), findsOneWidget);
    });

    testWidgets('renders suggestions as tappable chips when provided',
        (tester) async {
      List<String>? captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TagEditor(
            tags: const ['AI'],
            suggestions: const {'哲学', '历史'},
            onChanged: (tags) => captured = tags,
          ),
        ),
      ));

      // Suggestions should appear as tappable chips
      expect(find.text('哲学'), findsOneWidget);
      expect(find.text('历史'), findsOneWidget);

      // Tap the '哲学' suggestion chip to add it (use the keyed ActionChip
      // so the tap lands on the actual tappable affordance, not just the
      // label text inside it).
      await tester.tap(find.byKey(const Key('tag-editor-suggestion-哲学')));
      await tester.pumpAndSettle();

      expect(captured, containsAll(['AI', '哲学']));
    });

    testWidgets('suggestion chips for already-existing tags are filtered out',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TagEditor(
            tags: const ['AI'],
            suggestions: const {'AI', '哲学'},
            onChanged: (_) {},
          ),
        ),
      ));

      // 'AI' suggestion should NOT be rendered since it's already a tag.
      // But the existing tag 'AI' chip should still be visible.
      final aiFinders = find.text('AI');
      expect(aiFinders, findsOneWidget);
      // Suggestion chips rendered with key prefix to disambiguate
      expect(find.byKey(const Key('tag-editor-suggestion-哲学')), findsOneWidget);
      expect(find.byKey(const Key('tag-editor-suggestion-AI')), findsNothing);
    });
  });
}
