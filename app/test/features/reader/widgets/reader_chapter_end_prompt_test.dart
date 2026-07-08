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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/reader_engine_epub_view.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/repositories/settings_repository.dart';
import 'package:zhiyue/features/reader/widgets/chapter_end_prompt_snackbar.dart';
import 'package:zhiyue/features/reader/widgets/reader_chapter_end_prompt.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

/// Minimal fake engine exposing a controllable [ChapterEndEvent] stream.
class _FakeEpubEngine extends Fake implements ConcreteEpubReaderEngine {
  _FakeEpubEngine(this.events);

  final Stream<ChapterEndEvent> events;

  @override
  Stream<ChapterEndEvent> get chapterEndEvents => events;
}

class _FakeSettingsRepo implements SettingsRepository {
  _FakeSettingsRepo(this._values);
  final Map<String, Object?> _values;

  @override
  Future<T> get<T>(String key, T defaultValue) async =>
      (_values[key] as T?) ?? defaultValue;

  @override
  Future<T?> getOrNull<T>(String key) async => _values[key] as T?;

  @override
  Future<void> set<T>(String key, T value) async {
    _values[key] = value;
  }
}

void main() {
  group('ReaderChapterEndPrompt', () {
    testWidgets('mounts without crashing and renders no visual content',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReaderChapterEndPrompt(
                engine: _FakeEpubEngine(const Stream.empty()),
                bookId: 'test-book',
                onReview: (_) {},
                onNext: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ReaderChapterEndPrompt), findsOneWidget);
      // The widget renders SizedBox.shrink — no ChapterEndPromptSnackBar in tree
      // until the controller state goes visible.
      expect(find.byType(ChapterEndPromptSnackBar), findsNothing);
    });

    testWidgets('build returns SizedBox.shrink (no interactive descendants)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ReaderChapterEndPrompt(
                engine: _FakeEpubEngine(const Stream.empty()),
                bookId: 'test-book',
                onReview: (_) {},
                onNext: () {},
              ),
            ),
          ),
        ),
      );
      // No buttons, no text, no interactive widgets inside the prompt widget itself.
      final promptFinder = find.byType(ReaderChapterEndPrompt);
      final interactiveDescendants = find.descendant(
        of: promptFinder,
        matching: find.bySubtype<ElevatedButton>(),
      );
      expect(interactiveDescendants, findsNothing);
    });

    // 2026-07-08 FEAT 3：章末卡片渲染 + 点击回调。
    testWidgets('chapter end event → 渲染「上一章 / 下一章」卡片 + 点击触发回调',
        (tester) async {
      final eventController = StreamController<ChapterEndEvent>();
      bool prevCalled = false;
      bool nextCalled = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo(
                const {'chapter_end_prompt_enabled': true})),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ReaderChapterEndPrompt(
                engine: _FakeEpubEngine(eventController.stream),
                bookId: 'test-book',
                onReview: (_) {},
                onNext: () => nextCalled = true,
                onPrev: () => prevCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 默认 hidden：无卡片（SnackBar 也没出现）
      final promptFinder = find.byType(ReaderChapterEndPrompt);
      expect(find.descendant(of: promptFinder, matching: find.text('上一章')),
          findsNothing);
      expect(find.descendant(of: promptFinder, matching: find.text('下一章')),
          findsNothing);

      // 发个 chapter end event → 触发 visibility.visible
      eventController.add(const ChapterEndEvent(
        chapterIndex: 0,
        isLastChapter: false,
      ));
      await tester.pumpAndSettle();

      // 卡片出现（限定在 ReaderChapterEndPrompt 子树，SnackBar 的「下一章」不算）
      expect(find.descendant(of: promptFinder, matching: find.text('上一章')),
          findsOneWidget);
      expect(find.descendant(of: promptFinder, matching: find.text('下一章')),
          findsOneWidget);

      // 点击「上一章」→ onPrev 触发
      await tester.tap(
          find.descendant(of: promptFinder, matching: find.text('上一章')));
      await tester.pump();
      expect(prevCalled, isTrue);

      // 点击「下一章」→ onNext 触发
      await tester.tap(
          find.descendant(of: promptFinder, matching: find.text('下一章')));
      await tester.pump();
      expect(nextCalled, isTrue);

      await eventController.close();
    });

    testWidgets('onPrev 为 null（第一章）→ 仅渲染「下一章」+ Spacer 占位',
        (tester) async {
      final eventController = StreamController<ChapterEndEvent>();
      bool nextCalled = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo(
                const {'chapter_end_prompt_enabled': true})),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ReaderChapterEndPrompt(
                engine: _FakeEpubEngine(eventController.stream),
                bookId: 'test-book',
                onReview: (_) {},
                onNext: () => nextCalled = true,
                // onPrev 不传 —— 模拟第一章
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      eventController.add(const ChapterEndEvent(
        chapterIndex: 0,
        isLastChapter: false,
      ));
      await tester.pumpAndSettle();

      final promptFinder = find.byType(ReaderChapterEndPrompt);
      expect(find.descendant(of: promptFinder, matching: find.text('上一章')),
          findsNothing);
      expect(find.descendant(of: promptFinder, matching: find.text('下一章')),
          findsOneWidget);

      // 点击「下一章」卡片应触发 onNext 回调。
      await tester.tap(find.descendant(
        of: promptFinder,
        matching: find.text('下一章'),
      ));
      await tester.pump();
      expect(nextCalled, isTrue);

      await eventController.close();
    });
  });
}
