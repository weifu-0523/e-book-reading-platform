import 'package:flutter_test/flutter_test.dart';
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
}
