import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart' show settingsRepositoryProvider;
import '../../../data/repositories/settings_repository.dart';
import '../models/theme_mode_setting.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeModeSetting>((ref) {
  return ThemeModeNotifier(ref.watch(settingsRepositoryProvider));
});

class ThemeModeNotifier extends StateNotifier<ThemeModeSetting> {
  ThemeModeNotifier(this._repo) : super(ThemeModeSetting.system) {
    _loaded = _load();
  }

  final SettingsRepository _repo;
  late final Future<void> _loaded;

  Future<void> _load() async {
    final name = await _repo.get<String?>('app.themeMode', null);
    if (!mounted) return;
    state = ThemeModeSetting.fromName(name);
  }

  Future<void> setThemeMode(ThemeModeSetting v) async {
    await _loaded;
    if (!mounted) return;
    state = v;
    await _repo.set<String?>('app.themeMode', v.name);
  }
}
