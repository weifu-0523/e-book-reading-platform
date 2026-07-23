// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/tts/providers/tts_fallback_notifier.dart';

void main() {
  group('TtsFallbackNotifier', () {
    test('initial state has no fallback', () {
      final n = TtsFallbackNotifier();
      expect(n.state.hasFallback, isFalse);
      expect(n.state.message, isEmpty);
      expect(n.state.fromEngine, isEmpty);
      expect(n.state.timestamp, isNull);
    });

    test('reportFallback sets message + fromEngine + timestamp', () {
      final n = TtsFallbackNotifier();
      n.reportFallback(
        fromEngine: 'volcengineCloud',
        message: '网络异常',
      );
      expect(n.state.hasFallback, isTrue);
      expect(n.state.fromEngine, 'volcengineCloud');
      expect(n.state.message, contains('网络异常'));
      expect(n.state.timestamp, isNotNull);
    });

    test('clear resets state', () {
      final n = TtsFallbackNotifier()
        ..reportFallback(fromEngine: 'x', message: 'y');
      n.clear();
      expect(n.state.hasFallback, isFalse);
      expect(n.state.message, isEmpty);
      expect(n.state.fromEngine, isEmpty);
      expect(n.state.timestamp, isNull);
    });

    test('multiple reportFallback calls overwrite (latest wins)', () {
      final n = TtsFallbackNotifier()
        ..reportFallback(fromEngine: 'volcengineCloud', message: 'first')
        ..reportFallback(fromEngine: 'qwenCloud', message: 'second');
      expect(n.state.fromEngine, 'qwenCloud');
      expect(n.state.message, 'second');
    });
  });
}
