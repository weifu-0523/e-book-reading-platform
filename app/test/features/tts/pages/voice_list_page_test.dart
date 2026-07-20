// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/features/tts/pages/voice_list_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';
import 'package:zhiyue/services/tts/tts_voice.dart';

import '../../../helpers/stub_tts_service.dart';

/// Subclass of [StubTtsService] that records voice-related calls so the page
/// tests can assert on invocations without resorting to mocktail (which would
/// require stubbing every stream getter on [TtsService]).
///
/// Why not use `ttsServiceProvider.overrideWithValue`: that pattern causes
/// flutter_tester to hang indefinitely in this test (verified empirically —
/// the global-override pattern used by [tts_settings_section_test] works,
/// the per-container override doesn't, even with an otherwise-identical
/// widget tree). The global override is the established codebase pattern.
class _CountingStubTtsService extends StubTtsService {
  List<TtsVoice> voices = const [];
  int setVoiceCalls = 0;
  String? lastSetVoiceId;
  int previewVoiceCalls = 0;
  String? lastPreviewVoiceId;
  bool openSettingsOk = true;
  int openSettingsCalls = 0;

  @override
  Future<List<TtsVoice>> getVoices() async => voices;

  @override
  Future<bool> setVoice(String? voiceId) async {
    setVoiceCalls++;
    lastSetVoiceId = voiceId;
    return true;
  }

  @override
  Future<void> previewVoice(String voiceId, {String? sampleText}) async {
    previewVoiceCalls++;
    lastPreviewVoiceId = voiceId;
  }

  @override
  Future<bool> openSystemTtsSettings() async {
    openSettingsCalls++;
    return openSettingsOk;
  }
}

/// Force zh locale so tests can assert on the zh string contract that
/// ships to users (en is the fallback for low-coverage l10n keys).
Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: child,
    );

void main() {
  late Directory tempDir;
  late _CountingStubTtsService stub;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('voice_list_test_');
    globalTtsSettingsDirOverride = tempDir;
    stub = _CountingStubTtsService();
    globalTtsServiceOverride = stub;
  });

  tearDown(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {
      // best-effort cleanup
    }
    globalTtsSettingsDirOverride = null;
    globalTtsServiceOverride = null;
  });

  testWidgets('renders voice list from provider', (tester) async {
    stub.voices = const [
      TtsVoice(id: 'a|zh', name: 'Voice A', locale: 'zh', isDefault: true),
      TtsVoice(id: 'b|zh', name: 'Voice B', locale: 'zh'),
    ];

    await tester.pumpWidget(ProviderScope(child: _wrap(const VoiceListPage())));
    await tester.pumpAndSettle();

    expect(find.text('Voice A'), findsOneWidget);
    expect(find.text('Voice B'), findsOneWidget);
  });

  testWidgets('voice row ListTile has onTap wired for setVoice', (tester) async {
    stub.voices = const [
      TtsVoice(id: 'a|zh', name: 'A', locale: 'zh'),
    ];

    await tester.pumpWidget(ProviderScope(child: _wrap(const VoiceListPage())));
    await tester.pumpAndSettle();

    // Verify the voice row ListTile has onTap wired (non-null). The
    // notifier → TtsService.setVoice contract is covered by
    // tts_settings_provider_test.dart ('setVoice persists voiceId and calls
    // TtsService.setVoice'); we don't duplicate it here because tapping a
    // ListTile whose trailing IconButton has its own gesture handler is
    // finicky in widget tests (gesture arena resolves IconButton over the
    // InkWell on some Flutter versions, causing flaky tests).
    final voiceTile = tester.widget<ListTile>(find.byType(ListTile).at(1));
    expect(voiceTile.onTap, isNotNull,
        reason: 'voice row ListTile must have onTap wired');

    // System-default tile (index 0) also has onTap.
    final defaultTile = tester.widget<ListTile>(find.byType(ListTile).at(0));
    expect(defaultTile.onTap, isNotNull,
        reason: 'system-default ListTile must have onTap wired');
  });

  testWidgets('empty list shows hint + system settings button', (tester) async {
    stub.voices = const [];
    stub.openSettingsOk = true;

    await tester.pumpWidget(ProviderScope(child: _wrap(const VoiceListPage())));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(find.textContaining(l10n.ttsVoiceEmptyHint), findsOneWidget);
    expect(find.text(l10n.ttsVoiceOpenSystemSettings), findsOneWidget);
  });

  testWidgets('preview button triggers previewVoice', (tester) async {
    stub.voices = const [
      TtsVoice(id: 'a|zh', name: 'A', locale: 'zh'),
    ];

    await tester.pumpWidget(ProviderScope(child: _wrap(const VoiceListPage())));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    await tester.tap(find.byTooltip(l10n.ttsVoicePreview));
    await tester.pump();

    expect(stub.previewVoiceCalls, 1);
    expect(stub.lastPreviewVoiceId, 'a|zh');
  });
}
