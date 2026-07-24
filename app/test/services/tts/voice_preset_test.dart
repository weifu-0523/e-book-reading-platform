import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/cloud_tts_credentials.dart';
import 'package:zhiyue/services/tts/voice_preset.dart';

void main() {
  group('VoicePreset', () {
    test('constructs with required fields', () {
      final v = VoicePreset(
        id: 'longxiaoxia_v2',
        displayName: '龙小夏',
        gender: VoiceGender.female,
        description: '沉稳权威女',
      );
      expect(v.id, 'longxiaoxia_v2');
      expect(v.displayName, '龙小夏');
      expect(v.gender, VoiceGender.female);
      expect(v.description, '沉稳权威女');
    });

    test('optional description defaults to empty', () {
      final v = VoicePreset(
        id: 'x',
        displayName: 'X',
        gender: VoiceGender.male,
      );
      expect(v.description, '');
    });

    test('equality based on id only', () {
      final a = VoicePreset(id: 'v1', displayName: 'A', gender: VoiceGender.female);
      final b = VoicePreset(id: 'v1', displayName: 'B', gender: VoiceGender.male);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('CloudTtsVoicePresets.volcengine (v3)', () {
    test('volcengine voice list contains 8 doubao 2.0 voices', () {
      final voices = CloudTtsVoicePresets.volcengine;
      expect(voices.length, 8);
      expect(voices.any((v) => v.id == 'zh_male_shenyeboke_moon_bigtts'), isTrue);
      expect(voices.any((v) => v.id == 'zh_female_popo_mars_bigtts'), isTrue);
      expect(voices.any((v) => v.id == 'zh_female_gaolengyujie_moon_bigtts'), isTrue);
      expect(voices.any((v) => v.id == 'zh_male_aojiaobazong_moon_bigtts'), isTrue);
      expect(voices.any((v) => v.id == 'zh_female_meilinvyou_moon_bigtts'), isTrue);
      expect(voices.any((v) => v.id == 'zh_male_livelybro_mars_bigtts'), isTrue);
      expect(voices.any((v) => v.id == 'zh_male_dongfanghaoran_moon_bigtts'), isTrue);
      expect(voices.any((v) => v.id == 'zh_female_naying_mars_bigtts'), isTrue);
    });

    test('all volcengine voices have _bigtts suffix (v3 exclusive)', () {
      for (final v in CloudTtsVoicePresets.volcengine) {
        expect(v.id.endsWith('_bigtts'), isTrue, reason: '${v.id} missing _bigtts');
      }
    });
  });
}
