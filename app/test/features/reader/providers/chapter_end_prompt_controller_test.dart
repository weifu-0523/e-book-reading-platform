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

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/reader_engine_epub_view.dart';
import 'package:zhiyue/data/repositories/settings_repository.dart';
import 'package:zhiyue/features/reader/providers/chapter_end_prompt_controller.dart';

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
  late StreamController<ChapterEndEvent> source;
  late _FakeSettingsRepo repo;

  setUp(() {
    source = StreamController<ChapterEndEvent>.broadcast();
    repo = _FakeSettingsRepo({'chapter_end_prompt_enabled': true});
  });

  tearDown(() {
    source.close();
  });

  test('enabled state + event → visibility visible', () async {
    final controller = ChapterEndPromptController(
      repo: repo,
      source: source.stream,
      bookId: 'b1',
    );
    addTearDown(controller.dispose);

    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.visibility, ChapterEndPromptVisibility.visible);
    expect(controller.state.chapterIndex, 3);
    expect(controller.state.hasNext, isTrue);
  });

  test('disabled setting → state stays hidden', () async {
    repo = _FakeSettingsRepo({'chapter_end_prompt_enabled': false});
    final controller = ChapterEndPromptController(
      repo: repo,
      source: source.stream,
      bookId: 'b1',
    );
    addTearDown(controller.dispose);

    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.visibility, ChapterEndPromptVisibility.hidden);
  });

  test('dismiss sets visibility hidden', () async {
    final controller = ChapterEndPromptController(
      repo: repo,
      source: source.stream,
      bookId: 'b1',
    );
    addTearDown(controller.dispose);

    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    await Future<void>.delayed(Duration.zero);
    controller.dismiss();

    expect(controller.state.visibility, ChapterEndPromptVisibility.hidden);
  });
}
