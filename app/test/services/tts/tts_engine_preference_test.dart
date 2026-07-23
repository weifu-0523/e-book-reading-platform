import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/tts_engine_preference.dart';

void main() {
  group('TtsEnginePreference', () {
    test('has exactly 3 values: system, volcengineCloud, qwenCloud', () {
      expect(TtsEnginePreference.values, [
        TtsEnginePreference.system,
        TtsEnginePreference.volcengineCloud,
        TtsEnginePreference.qwenCloud,
      ]);
    });

    test('sherpaOnnxMelo persisted value falls back to system', () {
      expect(
        TtsEnginePreferenceX.fromPersistedValue('sherpaOnnxMelo'),
        TtsEnginePreference.system,
      );
    });

    test('volcengineCloud persists and restores', () {
      expect(
        TtsEnginePreference.volcengineCloud.persistedValue,
        'volcengineCloud',
      );
      expect(
        TtsEnginePreferenceX.fromPersistedValue('volcengineCloud'),
        TtsEnginePreference.volcengineCloud,
      );
    });

    test('qwenCloud persists and restores', () {
      expect(
        TtsEnginePreference.qwenCloud.persistedValue,
        'qwenCloud',
      );
      expect(
        TtsEnginePreferenceX.fromPersistedValue('qwenCloud'),
        TtsEnginePreference.qwenCloud,
      );
    });

    test('unknown persisted value falls back to system', () {
      expect(
        TtsEnginePreferenceX.fromPersistedValue('nonexistent'),
        TtsEnginePreference.system,
      );
      expect(
        TtsEnginePreferenceX.fromPersistedValue(null),
        TtsEnginePreference.system,
      );
    });
  });
}
