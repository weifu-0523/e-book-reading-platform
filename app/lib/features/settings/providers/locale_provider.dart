import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart' show settingsRepositoryProvider;
import '../../../data/repositories/settings_repository.dart';
import '../models/locale_setting.dart';

final localeProvider =
    StateNotifierProvider<LocaleNotifier, LocaleSetting>((ref) {
  return LocaleNotifier(ref.watch(settingsRepositoryProvider));
});

class LocaleNotifier extends StateNotifier<LocaleSetting> {
  LocaleNotifier(this._repo) : super(LocaleSetting.system) {
    _loaded = _load();
  }

  final SettingsRepository _repo;
  late final Future<void> _loaded;

  Future<void> _load() async {
    final name = await _repo.get<String?>('app.locale', null);
    if (!mounted) return;
    state = LocaleSetting.fromName(name);
  }

  Future<void> setLocale(LocaleSetting v) async {
    await _loaded;
    if (!mounted) return;
    state = v;
    await _repo.set<String?>('app.locale', v.name);
  }
}
