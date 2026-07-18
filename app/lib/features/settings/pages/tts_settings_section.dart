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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../gen_l10n/app_localizations.dart';
import '../../../services/tts/sentence_segmenter.dart';
import '../../../services/tts/self_built_tts_service.dart';
import '../../../services/tts/tts_availability.dart';
import '../../tts/providers/tts_playback_controller.dart';
import '../../tts/providers/tts_settings_provider.dart';

/// TTS section in [SettingsPage] (T8, 2026-07-16).
///
/// Renders three sliders (语速/音调/音量) bound to [ttsSettingsProvider],
/// a [SegmentedButton] for chapter-boundary behaviour, and a 测试朗读 button
/// that pushes a sample sentence queue into [TtsPlaybackController]. The
/// button's playback uses a sentinel messageId so it doesn't collide with
/// real chat messages.
///
/// Ranges match `flutter_tts` native defaults:
/// * rate: -1.0 (slower) .. 1.0 (faster); 0.0 = normal.
/// * pitch: 0.5 .. 2.0; 1.0 = normal.
/// * volume: 0.0 .. 1.0; 1.0 = full.
class TtsSettingsSection extends ConsumerWidget {
  const TtsSettingsSection({super.key});

  /// Sentinel messageId used by the 测试朗读 button so the playback scope
  /// doesn't collide with real AI chat message ids. TtsMiniControls and any
  /// other listener can special-case this id if needed.
  static const String testPlaybackMessageId = '__tts_test__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(ttsSettingsProvider);
    final notifier = ref.read(ttsSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(Icons.speed),
          title: Text(l10n.ttsRateLabel),
          subtitle: Slider(
            min: -1.0,
            max: 1.0,
            divisions: 20,
            value: settings.rate,
            label: settings.rate.toStringAsFixed(1),
            onChanged: notifier.setRate,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.music_note),
          title: Text(l10n.ttsPitchLabel),
          subtitle: Slider(
            min: 0.5,
            max: 2.0,
            divisions: 15,
            value: settings.pitch,
            label: settings.pitch.toStringAsFixed(1),
            onChanged: notifier.setPitch,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.volume_up),
          title: Text(l10n.ttsVolumeLabel),
          subtitle: Slider(
            min: 0.0,
            max: 1.0,
            divisions: 10,
            value: settings.volume,
            label: settings.volume.toStringAsFixed(1),
            onChanged: notifier.setVolume,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(l10n.ttsChapterBoundaryLabel),
              ),
              SegmentedButton<TtsChapterBoundary>(
                segments: [
                  ButtonSegment<TtsChapterBoundary>(
                    value: TtsChapterBoundary.continuous,
                    label: Text(l10n.ttsChapterBoundaryContinuous),
                  ),
                  ButtonSegment<TtsChapterBoundary>(
                    value: TtsChapterBoundary.askAtEnd,
                    label: Text(l10n.ttsChapterBoundaryAskAtEnd),
                  ),
                ],
                selected: {settings.chapterBoundary},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    notifier.setChapterBoundary(selection.first);
                  }
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.volume_up),
            label: Text(l10n.ttsTestSpeak),
            onPressed: () {
              final sentences = SentenceSegmenter.split(l10n.ttsTestSpeechText);
              if (sentences.isEmpty) return;
              ref.read(ttsPlaybackControllerProvider.notifier).play(
                    scope: const TtsScope.aiMessage(
                        messageId: testPlaybackMessageId),
                    sentences: sentences,
                  );
            },
          ),
        ),
        // T26 (2026-07-17): Check TTS engine availability + guide user when
        // Samsung SMT engine detected or voice data missing. Pending l10n
        // batch update, button + dialog copy are hardcoded zh-CN.
        // TODO(l10n): extract these strings into AppLocalizations.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('检查 TTS 引擎'),
            onPressed: () => _checkTtsEngine(ref, context),
          ),
        ),
        // v1.13.1-alpha: in-app debug log dump for Android self-built TTS.
        // Lets users without adb paste plugin/service state back so we can
        // diagnose startup / speak failures on Chinese-ROM devices.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.bug_report),
            label: const Text('TTS 调试日志'),
            onPressed: () => _showTtsDebugLogs(ref, context),
          ),
        ),
      ],
    );
  }

  /// v1.13.1-alpha: dump plugin + service debug state. Shows a dialog with
  /// a scrollable, copy-pasteable text view so the user can screenshot or
  /// copy the contents back to the developer.
  Future<void> _showTtsDebugLogs(WidgetRef ref, BuildContext context) async {
    final service = ref.read(ttsServiceProvider);
    if (service is! SelfBuiltTtsServiceImpl) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('TTS 调试日志'),
          content: Text('当前 TTS 实现不是自研 Android plugin（$service），'
              '此调试功能仅 Android 端可用。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Trigger a fresh debug snapshot. Also re-init so plugin/service state
    // is fresh even if the user hasn't clicked 「朗读」 yet.
    try {
      await service.init();
    } catch (_) {
      // Surface the init error in the dialog below.
    }
    final state = await service.getDebugState();
    if (!context.mounted) return;

    final pretty = _prettyDebugState(
      state,
      dartEventReceivedCount: service.eventReceivedCountForDebug,
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('TTS 调试日志'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              pretty,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// Pretty-print the debug state map as a readable multi-line string for
  /// the dialog body. Keys ordered roughly by data flow (plugin → service
  /// onCreate → onStartCommand → TTS engine).
  ///
  /// v1.13.4-alpha: added EventChannel pipeline section so we can pinpoint
  /// where events vanish between Kotlin `emit()` and Dart `_handleEvent`.
  static String _prettyDebugState(
    Map<String, dynamic> state, {
    int? dartEventReceivedCount,
  }) {
    final b = StringBuffer();
    b.writeln('=== Plugin ===');
    b.writeln('attached         : ${state['pluginAttached']}');
    b.writeln('isServiceCreated : ${state['isServiceCreated']}');
    b.writeln('initCallCount    : ${state['initCallCount']}');
    b.writeln('speakCallCount   : ${state['speakCallCount']}');
    b.writeln('lastStartError   : ${state['lastStartError'] ?? '(none)'}');
    b.writeln();
    b.writeln('=== Service onCreate ===');
    b.writeln('completed         : ${state['serviceOnCreateDone']}');
    b.writeln('exception         : ${state['serviceOnCreateException'] ?? '(none)'}');
    b.writeln('startForegroundOk : ${state['serviceStartForegroundDone']}');
    b.writeln('phoneStateSkipped : ${state['phoneStateListenerSetupSkipped']} '
        '(v1.13.3: SecurityException 时降级，不影响朗读)');
    b.writeln();
    b.writeln('=== TTS engine ===');
    b.writeln('initStatus       : ${state['ttsInitStatus']} '
        '(-999=未回调, 0=SUCCESS, -1=ERROR)');
    b.writeln('lastSpeakReturn  : ${state['ttsLastSpeakReturn']} '
        '(0=success, -1=error)');
    b.writeln();
    b.writeln('=== onStartCommand ===');
    b.writeln('count            : ${state['onStartCommandCount']}');
    b.writeln('lastAction       : ${state['lastStartCommandAction'] ?? '(none)'}');
    b.writeln('utteranceCallbacks: ${state['utteranceCallbacks']}');
    b.writeln();
    b.writeln('=== MethodChannel callback pipeline (v1.13.5) ===');
    b.writeln('onListenCalled   : ${state['onListenCalled']} '
        '(true=plugin attached)');
    b.writeln('channelReady     : ${state['realEventSinkReady']} '
        '(false=plugin 已 detach)');
    b.writeln('invokeAttempt    : ${state['emitCount']} '
        '(emitEvent 进入 invoke 路径次数)');
    b.writeln('invokeChannelNull: ${state['emitDroppedCount']} '
        '(channel 为 null 时丢弃次数)');
    b.writeln('invokeSucceeded  : ${state['invokeSucceededCount']} '
        '(invokeMethod 成功返回次数)');
    b.writeln('invokeException  : ${state['invokeExceptionCount']} '
        '(invokeMethod 抛异常次数)');
    b.writeln('dartReceivedCount: $dartEventReceivedCount '
        '(Dart _handleEvent 调用次数)');
    b.writeln('诊断推理: '
        'invokeSucceeded==dartReceivedCount → 管道正常；'
        'invokeSucceeded>0 && dartReceivedCount==0 → 仍丢包（极不寻常）；'
        'invokeException>0 → MethodChannel 反向调用失败（看日志异常类型）；'
        'invokeChannelNull>0 → 插件未 attach（看 attached 字段）。');
    b.writeln();
    b.writeln('=== Service debugLogs ===');
    final logs = state['serviceDebugLogs'];
    if (logs is List) {
      for (final line in logs) {
        b.writeln(line);
      }
    } else {
      b.writeln(logs);
    }
    return b.toString();
  }

  Future<void> _checkTtsEngine(WidgetRef ref, BuildContext context) async {
    final service = ref.read(ttsServiceProvider);
    final availability = await checkTtsAvailability(service);
    if (!context.mounted) return;

    final guidance = _availabilityGuidance(availability);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(guidance.title),
        content: Text(guidance.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Returns (title, body) copy for a given [TtsAvailability] state.
  ///
  /// Extracted as a static method so widget tests can assert on the copy
  /// without driving the real `checkTtsAvailability` future.
  // TODO(l10n): localized strings pending batch update.
  static ({String title, String body}) _availabilityGuidance(
      TtsAvailability availability) {
    switch (availability) {
      case TtsAvailability.ready:
        return (
          title: 'TTS 引擎就绪',
          body: 'TTS 引擎就绪，可以正常朗读。',
        );
      case TtsAvailability.engineMissing:
        return (
          title: '未检测到 TTS 引擎',
          body: '未检测到支持中文/英文的 TTS 引擎。请在应用商店安装 Google TTS（或同等引擎）后重试。',
        );
      case TtsAvailability.voiceDownloadRequired:
        return (
          title: '缺少语音数据',
          body: 'TTS 引擎已安装但缺少语音数据。请到 系统设置 → 语言和输入 → 文字转语音输出 下载对应语言的语音包。',
        );
      case TtsAvailability.samsungRestricted:
        return (
          title: '检测到 Samsung TTS 引擎',
          body: '检测到 Samsung 默认 TTS 引擎（com.samsung.SMT），该引擎对中文支持不佳。建议在 系统设置 → 文字转语音输出 切换到 Google TTS 引擎，或在 Samsung Voice Assistant 设置中下载中文语音数据。',
        );
    }
  }
}
