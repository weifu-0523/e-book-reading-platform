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

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/tts/tts_voice.dart';

void main() {
  group('TtsVoice', () {
    test('toJson round-trips via fromJson', () {
      const voice = TtsVoice(
        id: 'zh-CN-xiaoxiao|zh-CN',
        name: 'Xiaoxiao',
        locale: 'zh-CN',
        isDefault: true,
      );
      final j = voice.toJson();
      expect(j['id'], 'zh-CN-xiaoxiao|zh-CN');
      expect(j['name'], 'Xiaoxiao');
      expect(j['locale'], 'zh-CN');
      expect(j['isDefault'], true);

      final restored = TtsVoice.fromJson(j);
      expect(restored, voice);
      expect(restored.id, voice.id);
      expect(restored.isDefault, true);
    });

    test('fromJson tolerates missing isDefault (defaults to false)', () {
      final v = TtsVoice.fromJson({
        'id': 'en-US-Zira',
        'name': 'Zira',
        'locale': 'en-US',
      });
      expect(v.isDefault, false);
    });

    test('equality is by id only', () {
      const a = TtsVoice(id: 'id1', name: 'A', locale: 'zh');
      const b = TtsVoice(id: 'id1', name: 'B', locale: 'en', isDefault: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
