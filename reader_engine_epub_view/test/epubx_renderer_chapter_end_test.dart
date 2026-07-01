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

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';
import 'package:reader_engine_epub_view/src/chapter_end_event.dart';

void main() {
  // 直接测试 _maybeEmitChapterEnd 逻辑（通过 @visibleForTesting 入口）
  // 不需要 widget pump —— widget-level 集成由 app/test 集成测试覆盖。

  test('maybeEmitChapterEnd does nothing when no book is loaded', () async {
    final renderer = EpubxRenderer();
    final events = <ChapterEndEvent>[];
    final sub = renderer.chapterEndEvents.listen(events.add);

    renderer.maybeEmitChapterEndForTest();
    await Future<void>.delayed(Duration.zero);

    expect(events, isEmpty);
    await sub.cancel();
    await renderer.dispose();
  });

  test('chapterEndEvents is a broadcast Stream<ChapterEndEvent>', () {
    final renderer = EpubxRenderer();
    expect(renderer.chapterEndEvents, isA<Stream<ChapterEndEvent>>());
    // 多个 listener 都能收到（broadcast 性质）
    final a = <ChapterEndEvent>[];
    final b = <ChapterEndEvent>[];
    final subA = renderer.chapterEndEvents.listen(a.add);
    final subB = renderer.chapterEndEvents.listen(b.add);
    renderer.maybeEmitChapterEndForTest();
    // book 未加载，不 emit；但 stream 不报错即 OK
    expect(a, isEmpty);
    expect(b, isEmpty);
    subA.cancel();
    subB.cancel();
    renderer.dispose();
  });
}
