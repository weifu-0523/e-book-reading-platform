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
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/reader_engine_epub_view.dart';
import 'package:zhiyue/data/repositories/settings_repository.dart';
import 'package:zhiyue/features/reader/providers/chapter_end_prompt_controller.dart';
import 'package:zhiyue/features/reader/widgets/chapter_end_prompt_snackbar.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

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

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

/// Test harness that mirrors reader_body's wiring: registers a listener on
/// the controller in initState, and shows the SnackBar when visibility
/// flips to visible. StateNotifier state updates are async (the controller
/// awaits SettingsRepository.get before publishing), so a plain
/// StatefulBuilder without a listener would never observe the transition.
class _PromptHost extends StatefulWidget {
  const _PromptHost({required this.controller});
  final ChapterEndPromptController controller;
  @override
  State<_PromptHost> createState() => _PromptHostState();
}

class _PromptHostState extends State<_PromptHost> {
  ChapterEndPromptVisibility _lastVisibility =
      ChapterEndPromptVisibility.hidden;
  // StateNotifier.addListener returns a removal function.
  late final void Function() _removeListener;

  @override
  void initState() {
    super.initState();
    _removeListener = widget.controller.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  void _onStateChanged(ChapterEndPromptState s) {
    if (!mounted) return;
    if (s.visibility == ChapterEndPromptVisibility.visible &&
        _lastVisibility != ChapterEndPromptVisibility.visible) {
      _lastVisibility = s.visibility;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          ChapterEndPromptSnackBar(
            context: context,
            hasNext: s.hasNext,
            onReview: () {},
            onNext: () {},
            onDismiss: () {},
          ),
        );
      });
    } else {
      _lastVisibility = s.visibility;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  // Integration test 1: controller visible → SnackBar shows
  testWidgets('SnackBar shows when controller state becomes visible',
      (tester) async {
    final source = StreamController<ChapterEndEvent>.broadcast();
    addTearDown(source.close);

    final repo = _FakeSettingsRepo({'chapter_end_prompt_enabled': true});
    final controller = ChapterEndPromptController(
      repo: repo,
      source: source.stream,
      bookId: 'b1',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(_PromptHost(controller: controller)));

    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    await tester.pumpAndSettle();

    expect(find.text('回顾本章'), findsOneWidget);
    expect(find.text('下一章'), findsOneWidget);
  });

  // Integration test 2: disabled setting → state stays hidden, no SnackBar
  testWidgets('SnackBar hidden when settings disabled', (tester) async {
    final source = StreamController<ChapterEndEvent>.broadcast();
    addTearDown(source.close);

    final repo = _FakeSettingsRepo({'chapter_end_prompt_enabled': false});
    final controller = ChapterEndPromptController(
      repo: repo,
      source: source.stream,
      bookId: 'b1',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(_PromptHost(controller: controller)));

    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    await tester.pumpAndSettle();

    expect(controller.state.visibility, ChapterEndPromptVisibility.hidden);
    expect(find.byType(SnackBar), findsNothing);
  });
}
