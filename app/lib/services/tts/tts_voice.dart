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

/// A single TTS voice exposed by the platform's speech engine.
///
/// [id] is the platform-unique identifier (Android Voice.name + locale,
/// Windows SAPI5 voice name). Stable across launches for the same engine,
/// but **not portable across devices** (different ROMs / engine installs
/// produce different voice sets).
///
/// [locale] is BCP47 (e.g. "zh-CN", "en-US"). Used to filter voices when
/// the user's book language is known.
class TtsVoice {
  final String id;
  final String name;
  final String locale;
  final bool isDefault;

  const TtsVoice({
    required this.id,
    required this.name,
    required this.locale,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'locale': locale,
        'isDefault': isDefault,
      };

  factory TtsVoice.fromJson(Map<String, dynamic> j) => TtsVoice(
        id: j['id'] as String,
        name: j['name'] as String,
        locale: j['locale'] as String,
        isDefault: (j['isDefault'] as bool?) ?? false,
      );

  @override
  bool operator ==(Object other) => other is TtsVoice && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'TtsVoice(id=$id, name=$name, locale=$locale, isDefault=$isDefault)';
}
