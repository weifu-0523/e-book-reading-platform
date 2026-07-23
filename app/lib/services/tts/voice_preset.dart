// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

enum VoiceGender { male, female, neutral }

/// A preset voice option exposed by a TTS engine. Used to populate the
/// voice dropdown in TTS settings.
class VoicePreset {
  final String id;
  final String displayName;
  final VoiceGender gender;
  final String description;

  const VoicePreset({
    required this.id,
    required this.displayName,
    required this.gender,
    this.description = '',
  });

  @override
  bool operator ==(Object other) => other is VoicePreset && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VoicePreset($id, $displayName)';
}
