import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('arb zh and en contain the same keys', () {
    final zh = _loadKeys('lib/l10n/app_zh.arb');
    final en = _loadKeys('lib/l10n/app_en.arb');
    expect(en.keys.toSet(), equals(zh.keys.toSet()),
        reason: 'zh and en arb must have identical key sets');
  });

  test('critical keys present in both arb files', () {
    for (final arb in ['lib/l10n/app_zh.arb', 'lib/l10n/app_en.arb']) {
      final keys = _loadKeys(arb).keys.toSet();
      for (final required in [
        'appTitle',
        'settingsTitle',
        'settingsSectionReading',
        'settingsSectionFonts',
        'settingsSectionAppearance',
        'settingsSectionLanguage',
        'settingsSectionAbout',
      ]) {
        expect(keys, contains(required),
            reason: '$arb missing required key: $required');
      }
    }
  });
}

Map<String, dynamic> _loadKeys(String relPath) {
  final file = File(relPath);
  final raw = file.readAsStringSync();
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return Map.fromEntries(
      decoded.entries.where((e) => !e.key.startsWith('@')));
}
