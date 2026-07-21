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
import 'package:zhiyue/services/tts/samsung_tts_detector.dart';
import 'package:zhiyue/services/tts/tts_availability.dart';
import 'package:zhiyue/services/tts/tts_service.dart';
import 'package:zhiyue/services/tts/tts_voice.dart';

/// Fake [TtsService] for [checkTtsAvailability] unit tests.
///
/// Implements all abstract methods as no-ops so we can configure just the
/// three values that [checkTtsAvailability] consults:
/// * [engineReturn] — value returned by [getDefaultEngine].
/// * [availableLocales] — set of locales for which [isLanguageAvailable]
///   returns true.
/// * [installedLocales] — set of locales for which [isLanguageInstalled]
///   returns true.
class _FakeTtsService implements TtsService {
  String? engineReturn;
  Set<String> availableLocales = <String>{};
  Set<String> installedLocales = <String>{};

  @override
  Stream<TtsState> get state => const Stream<TtsState>.empty();
  @override
  Stream<TtsProgress> get progress => const Stream<TtsProgress>.empty();
  @override
  Stream<String> get error => const Stream<String>.empty();
  @override
  bool get isInitialized => true;
  @override
  int? get eventReceivedCountForDebug => null;

  @override
  Future<void> init() async {}
  @override
  Future<void> speakSentence(Sentence s) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  void setCurrentSentenceIndex(int idx) {}
  @override
  Future<void> hintNext(Sentence? next) async {}
  @override
  Future<void> setSpeechRate(double r) async {}
  @override
  Future<void> setPitch(double p) async {}
  @override
  Future<void> setVolume(double v) async {}

  @override
  Future<bool> isLanguageAvailable(String locale) async =>
      availableLocales.contains(locale);
  @override
  Future<bool> isLanguageInstalled(String locale) async =>
      installedLocales.contains(locale);
  @override
  Future<String?> getDefaultEngine() async => engineReturn;

  // === v1.14.0-alpha: Voice selection stubs (T1) ===

  @override
  Future<List<TtsVoice>> getVoices() async => const [];

  @override
  Future<bool> setVoice(String? voiceId) async => false;

  @override
  Future<void> previewVoice(String voiceId, {String? sampleText}) async {}

  @override
  Future<bool> openSystemTtsSettings() async => false;

  @override
  Future<void> dispose() async {}
}

void main() {
  group('checkTtsAvailability', () {
    late _FakeTtsService service;

    setUp(() {
      service = _FakeTtsService();
    });

    test('returns samsungRestricted when engine = com.samsung.SMT', () async {
      service.engineReturn = 'com.samsung.SMT';
      // Even if languages report installed, Samsung state takes priority.
      service.availableLocales = {'zh-CN', 'en-US'};
      service.installedLocales = {'zh-CN', 'en-US'};
      expect(await checkTtsAvailability(service),
          TtsAvailability.samsungRestricted);
    });

    test(
        'returns samsungRestricted when engine = com.samsung.android.app.SMT',
        () async {
      service.engineReturn = 'com.samsung.android.app.SMT';
      service.availableLocales = {'zh-CN', 'en-US'};
      service.installedLocales = {'zh-CN', 'en-US'};
      expect(await checkTtsAvailability(service),
          TtsAvailability.samsungRestricted);
    });

    test(
        'samsungRestricted short-circuits even when no language is available',
        () async {
      // Samsung engine lies about availability anyway — the engine check
      // runs first and reports the actionable state.
      service.engineReturn = 'com.samsung.SMT';
      service.availableLocales = <String>{};
      service.installedLocales = <String>{};
      expect(await checkTtsAvailability(service),
          TtsAvailability.samsungRestricted);
    });

    test('returns engineMissing when neither zh nor en available', () async {
      service.engineReturn = 'com.google.android.tts';
      service.availableLocales = <String>{};
      service.installedLocales = <String>{};
      expect(await checkTtsAvailability(service),
          TtsAvailability.engineMissing);
    });

    test('returns engineMissing when engine is null and no language available',
        () async {
      // iOS returns null engine; if no language available either, treat
      // the same as engineMissing (iOS uses built-in voices but a fresh
      // install with no TTS data should still warn).
      service.engineReturn = null;
      service.availableLocales = <String>{};
      expect(await checkTtsAvailability(service),
          TtsAvailability.engineMissing);
    });

    test(
        'returns voiceDownloadRequired when zh available but not installed',
        () async {
      service.engineReturn = 'com.google.android.tts';
      service.availableLocales = {'zh-CN'};
      service.installedLocales = <String>{};
      expect(await checkTtsAvailability(service),
          TtsAvailability.voiceDownloadRequired);
    });

    test(
        'returns voiceDownloadRequired when en available but not installed',
        () async {
      service.engineReturn = 'com.google.android.tts';
      service.availableLocales = {'en-US'};
      service.installedLocales = <String>{};
      expect(await checkTtsAvailability(service),
          TtsAvailability.voiceDownloadRequired);
    });

    test(
        'returns voiceDownloadRequired when zh installed but en available and '
        'missing', () async {
      // Even if one language is fully ready, the other available one
      // lacking voice data still reports voiceDownloadRequired so the
        // user is prompted to install the missing voice.
      service.engineReturn = 'com.google.android.tts';
      service.availableLocales = {'zh-CN', 'en-US'};
      service.installedLocales = {'zh-CN'};
      expect(await checkTtsAvailability(service),
          TtsAvailability.voiceDownloadRequired);
    });

    test('returns ready when both zh and en available + installed', () async {
      service.engineReturn = 'com.google.android.tts';
      service.availableLocales = {'zh-CN', 'en-US'};
      service.installedLocales = {'zh-CN', 'en-US'};
      expect(await checkTtsAvailability(service), TtsAvailability.ready);
    });

    test('returns ready when only en available + installed (zh not available)',
        () async {
      service.engineReturn = 'com.google.android.tts';
      service.availableLocales = {'en-US'};
      service.installedLocales = {'en-US'};
      expect(await checkTtsAvailability(service), TtsAvailability.ready);
    });

    test('returns ready when only zh available + installed (en not available)',
        () async {
      service.engineReturn = 'com.google.android.tts';
      service.availableLocales = {'zh-CN'};
      service.installedLocales = {'zh-CN'};
      expect(await checkTtsAvailability(service), TtsAvailability.ready);
    });

    test(
        'returns ready when engine is null and languages fully installed '
        '(iOS-style)', () async {
      service.engineReturn = null;
      service.availableLocales = {'zh-CN', 'en-US'};
      service.installedLocales = {'zh-CN', 'en-US'};
      expect(await checkTtsAvailability(service), TtsAvailability.ready);
    });
  });

  group('SamsungTtsDetector.isSamsungEngine', () {
    test('returns false for null engine name', () {
      expect(SamsungTtsDetector.isSamsungEngine(null), isFalse);
    });

    test('returns false for empty string', () {
      expect(SamsungTtsDetector.isSamsungEngine(''), isFalse);
    });

    test('returns false for Google TTS package', () {
      expect(SamsungTtsDetector.isSamsungEngine('com.google.android.tts'),
          isFalse);
    });

    test('returns false for iFlytek engine package', () {
      expect(
          SamsungTtsDetector.isSamsungEngine(
              'com.iflytek.cuteflyspeechclient'),
          isFalse);
    });

    test('returns true for com.samsung.SMT', () {
      expect(SamsungTtsDetector.isSamsungEngine('com.samsung.SMT'), isTrue);
    });

    test('returns true for com.samsung.android.app.SMT', () {
      expect(SamsungTtsDetector.isSamsungEngine('com.samsung.android.app.SMT'),
          isTrue);
    });

    test('is case-sensitive (no fuzzy match)', () {
      // Real package names are case-sensitive on Android; we match exactly.
      expect(SamsungTtsDetector.isSamsungEngine('COM.SAMSUNG.SMT'), isFalse);
    });
  });
}
