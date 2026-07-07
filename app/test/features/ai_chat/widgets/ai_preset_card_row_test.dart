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
import 'package:zhiyue/features/ai_chat/widgets/ai_preset_card_row.dart';

/// Fake [ChatSessionController] that records preset-card method calls.
///
/// We override [runChapterGuide] and [runSocraticBootstrap] so the test never
/// touches the LLM/repo wiring. The base constructor only stores [Ref] +
/// [bookId]; those fields are not used because both overridden methods skip
/// the `_ref.read(...)` path entirely.
class _FakeController extends ChatSessionController {
  _FakeController(super.ref, super.bookId);

  int chapterGuideCalls = 0;
  int socraticCalls = 0;
  int? lastChapterIndex;
  String? lastSource;

  @override
  Future<void> runChapterGuide({
    required int chapterIndex,
    required String source,
  }) async {
    chapterGuideCalls++;
    lastChapterIndex = chapterIndex;
    lastSource = source;
  }

  @override
  Future<void> runSocraticBootstrap({required int chapterIndex}) async {
    socraticCalls++;
    lastChapterIndex = chapterIndex;
  }
}

void main() {
  testWidgets('renders two preset cards', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        chatSessionControllerProvider('b1')
            .overrideWith((ref) => _FakeController(ref, 'b1')),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: AiPresetCardRow(bookId: 'b1', chapterIndex: 0),
        ),
      ),
    ));
    expect(find.textContaining('本章导读'), findsOneWidget);
    expect(find.textContaining('苏格拉底'), findsOneWidget);
  });

  testWidgets(
      'tapping chapter card calls runChapterGuide with source=card.chapter',
      (tester) async {
    final fakeHolder = <_FakeController>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        chatSessionControllerProvider('b1').overrideWith((ref) {
          final c = _FakeController(ref, 'b1');
          fakeHolder.add(c);
          return c;
        }),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: AiPresetCardRow(bookId: 'b1', chapterIndex: 3),
        ),
      ),
    ));
    await tester.tap(find.textContaining('本章导读'));
    await tester.pump();
    expect(fakeHolder.single.chapterGuideCalls, 1);
    expect(fakeHolder.single.lastSource, 'card.chapter');
    expect(fakeHolder.single.lastChapterIndex, 3);
  });

  testWidgets('tapping socratic card calls runSocraticBootstrap',
      (tester) async {
    final fakeHolder = <_FakeController>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        chatSessionControllerProvider('b1').overrideWith((ref) {
          final c = _FakeController(ref, 'b1');
          fakeHolder.add(c);
          return c;
        }),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: AiPresetCardRow(bookId: 'b1', chapterIndex: 5),
        ),
      ),
    ));
    await tester.tap(find.textContaining('苏格拉底'));
    await tester.pump();
    expect(fakeHolder.single.socraticCalls, 1);
    expect(fakeHolder.single.lastChapterIndex, 5);
  });

  testWidgets('cards are disabled while streaming', (tester) async {
    // Stream controller whose state we can mutate to isStreaming=true.
    final fakeHolder = <_FakeController>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        chatSessionControllerProvider('b1').overrideWith((ref) {
          final c = _FakeController(ref, 'b1');
          fakeHolder.add(c);
          return c;
        }),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: AiPresetCardRow(bookId: 'b1', chapterIndex: 0),
        ),
      ),
    ));
    // Flip the controller's state to streaming.
    fakeHolder.single.setStreamingForTest();
    await tester.pump();
    // Tapping should be a no-op (InkWell onTap=null when disabled).
    await tester.tap(find.textContaining('本章导读'), warnIfMissed: false);
    await tester.pump();
    expect(fakeHolder.single.chapterGuideCalls, 0);
    // Find the InkWell ancestors of the cards; both should be disabled.
    final inkWells = find.byType(InkWell);
    final renderBoxes = tester.widgetList<InkWell>(inkWells);
    expect(renderBoxes.every((w) => w.onTap == null), isTrue);
  });
}

extension on ChatSessionController {
  /// Test-only helper to push a streaming state without invoking any use case.
  void setStreamingForTest() {
    state = state.copyWith(isStreaming: true);
  }
}
