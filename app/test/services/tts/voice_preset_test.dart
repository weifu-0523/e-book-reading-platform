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

  // V1 -> V3 backward-compat fallback contract.
  //
  // Background: v1.16.0-alpha shipped Volcengine V1 protocol with voices like
  // `BV001_streaming`. v1.16.1-alpha upgraded to V3 with `_bigtts` voices.
  // Users upgrading from v1.16.0-alpha may have a persisted V1 voice id in
  // secure storage that no longer exists in the V3 voice list. The data
  // contract: V1 voice ids must NOT silently match V3 ids (no overlap); the
  // defaultVoice must be a valid V3 voice so the controller layer can fall
  // back to it when the persisted voice is missing from the list.
  group('V1 -> V3 backward-compat fallback', () {
    const v1Voices = <String>[
      'BV001_streaming',
      'BV002_streaming',
      'BV001_compatible',
      'BV002_compatible',
      'speaker-uncle',
    ];

    test('V1 voice ids are not in V3 voice list', () {
      final v3VoiceIds = CloudTtsVoicePresets.volcengine.map((v) => v.id).toSet();
      for (final v1 in v1Voices) {
        expect(v3VoiceIds.contains(v1), isFalse,
            reason: 'V1 voice $v1 unexpectedly present in V3 list');
      }
    });

    test('defaultVoice is a valid V3 voice in the list', () {
      const expected = VolcengineTtsCredentials.defaultVoice;
      expect(expected, 'zh_male_shenyeboke_moon_bigtts');
      final inList =
          CloudTtsVoicePresets.volcengine.any((v) => v.id == expected);
      expect(inList, isTrue,
          reason: 'defaultVoice must be a valid V3 voice: $expected');
    });

    test('V1 persisted voice differs from V3 defaultVoice (sanity)', () {
      // Sanity check: a V1 voice is not accidentally equal to the V3 default.
      const v1Voice = 'BV001_streaming';
      const v3Default = VolcengineTtsCredentials.defaultVoice;
      expect(v1Voice == v3Default, isFalse);
    });
  });
}
