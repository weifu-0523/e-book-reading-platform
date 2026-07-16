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

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/zhiyue_audio_handler.dart';

void main() {
  late ZhiYueAudioHandler handler;
  late int resumeCalls, pauseCalls, stopCalls, nextCalls, prevCalls;

  setUp(() {
    resumeCalls = pauseCalls = stopCalls = nextCalls = prevCalls = 0;
    handler = ZhiYueAudioHandler(
      onResume: () async {
        resumeCalls++;
      },
      onPause: () async {
        pauseCalls++;
      },
      onStop: () async {
        stopCalls++;
      },
      onSkipNext: () async {
        nextCalls++;
      },
      onSkipPrevious: () async {
        prevCalls++;
      },
    );
  });

  group('play', () {
    test('calls onResume exactly once', () async {
      await handler.play();
      expect(resumeCalls, 1);
    });

    test('sets playbackState playing=true', () async {
      await handler.play();
      expect(handler.playbackState.value.playing, isTrue);
    });

    test('exposes pause control (so notification shows pause button)',
        () async {
      await handler.play();
      expect(handler.playbackState.value.controls, contains(MediaControl.pause));
    });
  });

  group('pause', () {
    test('calls onPause exactly once', () async {
      await handler.pause();
      expect(pauseCalls, 1);
    });

    test('sets playbackState playing=false', () async {
      await handler.pause();
      expect(handler.playbackState.value.playing, isFalse);
    });

    test('exposes play control (so notification shows play button)', () async {
      await handler.pause();
      expect(handler.playbackState.value.controls, contains(MediaControl.play));
    });
  });

  group('stop', () {
    test('calls onStop exactly once', () async {
      await handler.stop();
      expect(stopCalls, 1);
    });

    test('sets processingState idle', () async {
      await handler.stop();
      expect(handler.playbackState.value.processingState,
          AudioProcessingState.idle);
    });
  });

  test('skipToNext calls onSkipNext', () async {
    await handler.skipToNext();
    expect(nextCalls, 1);
  });

  test('skipToPrevious calls onSkipPrevious', () async {
    await handler.skipToPrevious();
    expect(prevCalls, 1);
  });

  group('publishMediaItem', () {
    test('sets id as bookId:sentenceIdx', () async {
      handler.publishMediaItem(
        bookId: 'b1',
        bookTitle: 'Test Book',
        chapterTitle: 'Chapter 1',
        sentenceIdx: 2,
        total: 10,
        coverPath: null,
      );
      final item = handler.mediaItem.value;
      expect(item, isNotNull);
      expect(item!.id, 'b1:2');
    });

    test('sets album = bookTitle', () async {
      handler.publishMediaItem(
        bookId: 'b1',
        bookTitle: 'My Book',
        chapterTitle: 'Chapter 1',
        sentenceIdx: 0,
        total: 5,
      );
      expect(handler.mediaItem.value!.album, 'My Book');
    });

    test('sets title = chapterTitle', () async {
      handler.publishMediaItem(
        bookId: 'b1',
        bookTitle: 'My Book',
        chapterTitle: 'Intro',
        sentenceIdx: 0,
        total: 5,
      );
      expect(handler.mediaItem.value!.title, 'Intro');
    });

    test('artist contains 1-based sentence index + total', () async {
      handler.publishMediaItem(
        bookId: 'b1',
        bookTitle: 'My Book',
        chapterTitle: 'Intro',
        sentenceIdx: 2, // 0-based
        total: 10,
      );
      // sentenceIdx=2 → display 第 3 句 (1-based)
      expect(handler.mediaItem.value!.artist, contains('第 3 句'));
      expect(handler.mediaItem.value!.artist, contains('共 10 句'));
    });

    test('null coverPath → null artUri', () async {
      handler.publishMediaItem(
        bookId: 'b1',
        bookTitle: 'Test',
        chapterTitle: 'Ch',
        sentenceIdx: 0,
        total: 5,
        coverPath: null,
      );
      expect(handler.mediaItem.value!.artUri, isNull);
    });

    test('non-null coverPath → non-null artUri', () async {
      handler.publishMediaItem(
        bookId: 'b1',
        bookTitle: 'Test',
        chapterTitle: 'Ch',
        sentenceIdx: 0,
        total: 5,
        coverPath: '/tmp/cover.png',
      );
      expect(handler.mediaItem.value!.artUri, isNotNull);
    });
  });
}
