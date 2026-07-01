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
import 'package:zhiyue/features/reader/services/chapter_end_detector.dart';

void main() {
  late StreamController<ChapterEndEvent> source;
  late ChapterEndDetector detector;

  setUp(() {
    source = StreamController<ChapterEndEvent>.broadcast();
    detector = ChapterEndDetector(source: source.stream, bookId: 'b1');
  });

  tearDown(() {
    detector.dispose();
    source.close();
  });

  test('first event for a chapter emits PromptRequest', () async {
    final reqs = <PromptRequest>[];
    detector.promptRequests.listen(reqs.add);
    // ignore: cascade_invocations - interleaving source.add, cannot cascade
    detector.start();

    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    await Future<void>.delayed(Duration.zero);

    expect(reqs.length, 1);
    expect(reqs.first.bookId, 'b1');
    expect(reqs.first.chapterIndex, 3);
    expect(reqs.first.hasNext, isTrue);
  });

  test('second event for same chapter is suppressed (dedup)', () async {
    final reqs = <PromptRequest>[];
    detector.promptRequests.listen(reqs.add);
    // ignore: cascade_invocations - interleaving source.add, cannot cascade
    detector.start();

    source
      ..add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false))
      ..add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    await Future<void>.delayed(Duration.zero);

    expect(reqs.length, 1);
  });

  test('event for different chapter emits again', () async {
    final reqs = <PromptRequest>[];
    detector.promptRequests.listen(reqs.add);
    // ignore: cascade_invocations - interleaving source.add, cannot cascade
    detector.start();

    source
      ..add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false))
      ..add(const ChapterEndEvent(chapterIndex: 4, isLastChapter: false));
    await Future<void>.delayed(Duration.zero);

    expect(reqs.length, 2);
    expect(reqs[0].chapterIndex, 3);
    expect(reqs[1].chapterIndex, 4);
  });

  test('isLastChapter true → hasNext false', () async {
    final reqs = <PromptRequest>[];
    detector.promptRequests.listen(reqs.add);
    detector.start();

    source.add(const ChapterEndEvent(chapterIndex: 9, isLastChapter: true));
    await Future<void>.delayed(Duration.zero);

    expect(reqs.single.hasNext, isFalse);
  });

  test('start is idempotent (no duplicate subscription)', () async {
    final reqs = <PromptRequest>[];
    detector.promptRequests.listen(reqs.add);
    detector
      ..start()
      ..start(); // second call should be no-op

    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    await Future<void>.delayed(Duration.zero);

    expect(reqs.length, 1);
  });

  test('different bookId → different dedup keys', () async {
    final source2 = StreamController<ChapterEndEvent>.broadcast();
    final det2 = ChapterEndDetector(source: source2.stream, bookId: 'b2');
    addTearDown(() {
      det2.dispose();
      source2.close();
    });

    final reqs1 = <PromptRequest>[];
    final reqs2 = <PromptRequest>[];
    detector.promptRequests.listen(reqs1.add);
    det2.promptRequests.listen(reqs2.add);
    detector.start();
    det2.start();

    // Both detectors see chapter 3, but different book → each emits.
    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    source2.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    await Future<void>.delayed(Duration.zero);

    expect(reqs1.length, 1);
    expect(reqs2.length, 1);
  });
}
