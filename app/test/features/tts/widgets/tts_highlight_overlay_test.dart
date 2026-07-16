// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/rendering/highlight_range.dart';
import 'package:zhiyue/features/tts/widgets/tts_highlight_overlay.dart';
import 'package:zhiyue/services/tts/tts_service.dart';

void main() {
  group('TtsHighlightOverlay', () {
    test('overlay color is 半透明金黄 Color(0x66FFD700)', () {
      expect(TtsHighlightOverlay.color, const Color(0x66FFD700));
    });

    test('colorKey is "tts" (distinct from user highlight 5 colors)', () {
      expect(TtsHighlightOverlay.colorKey, 'tts');
    });

    test('colorRgba matches Color(0x66FFD700) (gold @ 40% alpha)', () {
      // Color(0x66FFD700) = ARGB(0x66=102/255≈40%, R=FF, G=D7, B=00)
      // → rgba(255, 215, 0, 0.4) (the same alpha granularity used by
      // reader_body._highlightColorRgba for user colors).
      expect(TtsHighlightOverlay.colorRgba, 'rgba(255, 215, 0, 0.4)');
    });

    test('rangeFor returns HighlightRange with sentence CFI offsets + gold '
        'color + chapterIndex + hasNote=false', () {
      const sentence = Sentence(
        text: 'Hello.',
        locale: 'en-US',
        charStart: 0,
        charEnd: 6,
        startCfi: '0:0',
        endCfi: '0:6',
      );
      final range = TtsHighlightOverlay.rangeFor(sentence, chapterIndex: 3);
      expect(range, isA<HighlightRange>());
      expect(range.startOffset, 0);
      expect(range.endOffset, 6);
      expect(range.colorRgba, TtsHighlightOverlay.colorRgba);
      expect(range.chapterIndex, 3);
      expect(range.hasNote, false); // TTS overlay never carries a note dot
    });

    test('rangeFor uses charStart/charEnd when CFI absent (defensive)', () {
      // Sentences without CFI (e.g. PDF / fallback) fall back to char offsets.
      // rangeFor should still produce a valid range so the renderer does not
      // silently swallow the highlight.
      const sentence = Sentence(
        text: 'Hi.',
        locale: 'en-US',
        charStart: 10,
        charEnd: 13,
        // startCfi / endCfi intentionally null
      );
      final range = TtsHighlightOverlay.rangeFor(sentence, chapterIndex: 0);
      expect(range.startOffset, 10);
      expect(range.endOffset, 13);
      expect(range.colorRgba, TtsHighlightOverlay.colorRgba);
    });

    test('colorKey distinct from each user HighlightColor name', () {
      // The user highlight system uses the HighlightColor enum (yellow/green/
      // blue/red/purple). 'tts' must not collide with any name() so future
      // serialization / search filters can disambiguate.
      const userColorNames = <String>[
        'yellow',
        'green',
        'blue',
        'red',
        'purple',
      ];
      for (final name in userColorNames) {
        expect(TtsHighlightOverlay.colorKey, isNot(name));
      }
    });
  });
}
