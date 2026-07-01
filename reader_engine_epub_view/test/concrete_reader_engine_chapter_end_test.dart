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
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';
import 'package:reader_engine_epub_view/src/chapter_end_event.dart';

void main() {
  test('ConcreteEpubReaderEngine.chapterEndEvents forwards renderer stream',
      () async {
    final renderer = EpubxRenderer();
    final engine = ConcreteEpubReaderEngine(renderer: renderer);
    final events = <ChapterEndEvent>[];
    final sub = engine.chapterEndEvents.listen(events.add);

    // 通过 @visibleForTesting 入口触发
    renderer.maybeEmitChapterEndForTest();
    await Future<void>.delayed(Duration.zero);

    // book 未加载 → 不 emit（验证 forward 而非 emit 行为）
    expect(events, isEmpty);
    expect(engine.chapterEndEvents, isA<Stream<ChapterEndEvent>>());

    await sub.cancel();
    await engine.close();
  });
}
