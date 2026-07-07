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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/ai_chat/providers/chat_session_controller.dart';
import 'package:zhiyue/features/ai_chat/widgets/ai_input_composer.dart';

/// Fake [ChatSessionController] that records sendMessage calls.
///
/// Mirrors the pattern in `ai_preset_card_row_test.dart`. The base
/// constructor only stores [Ref] + bookId; those fields are not used because
/// overridden methods skip the `_ref.read(...)` path entirely.
class _FakeController extends ChatSessionController {
  _FakeController(super.ref, super.bookId);

  int sendMessageCount = 0;
  String? lastText;
  String? lastAttachmentId;
  String? lastAttachmentSnap;

  @override
  Future<void> sendMessage({
    required String text,
    String? attachmentNoteId,
    String? attachmentSnapshot,
  }) async {
    sendMessageCount++;
    lastText = text;
    lastAttachmentId = attachmentNoteId;
    lastAttachmentSnap = attachmentSnapshot;
  }
}

void main() {
  late _FakeController fakeController;
  late ProviderContainer container;

  setUp(() {
    // Build a provider container with an overridden controller so the test
    // can observe sendMessage calls without wiring the LLM/repo chain.
    fakeController = _FakeController(_NullRef(), 'b1');
    container = ProviderContainer(overrides: [
      chatSessionControllerProvider('b1')
          .overrideWith((ref) => fakeController),
    ]);
    addTearDown(container.dispose);
  });

  Future<void> pumpComposer(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: AiInputComposer(bookId: 'b1', chapterIndex: 0),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('renders text field + send button', (tester) async {
    await pumpComposer(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);
  });

  testWidgets('send button disabled when input empty', (tester) async {
    await pumpComposer(tester);
    final sendButton = tester.widget<IconButton>(find.byType(IconButton).last);
    expect(sendButton.onPressed, isNull,
        reason: 'send should be disabled when input empty');
  });

  testWidgets('typing text enables send button', (tester) async {
    await pumpComposer(tester);
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    final sendButton = tester.widget<IconButton>(find.byType(IconButton).last);
    expect(sendButton.onPressed, isNotNull);
  });

  testWidgets('tapping send calls sendMessage + clears input', (tester) async {
    await pumpComposer(tester);
    await tester.enterText(find.byType(TextField), 'hello world');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(fakeController.sendMessageCount, 1);
    expect(fakeController.lastText, 'hello world');
    // Input cleared after send.
    expect(find.text('hello world'), findsNothing);
  });

  testWidgets('typing / shows slash popup', (tester) async {
    await pumpComposer(tester);
    await tester.enterText(find.byType(TextField), '/');
    await tester.pump();
    expect(find.text('/new'), findsOneWidget);
    expect(find.text('/help'), findsOneWidget);
  });

  testWidgets('pendingInput from controller pre-fills text field',
      (tester) async {
    fakeController.setPendingInput('> selected text');
    await pumpComposer(tester);
    await tester.pump();
    expect(find.text('> selected text'), findsOneWidget);
  });
}

/// Minimal [Ref] stub. Only methods/fields actually touched by
/// [ChatSessionController]'s base constructor (which only stores it) are
/// safe to leave as throwers; tests above override the methods that would
/// otherwise dereference `_ref`.
class _NullRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_NullRef.${invocation.memberName}');
}
