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
