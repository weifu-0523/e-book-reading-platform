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
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/settings/models/locale_setting.dart';
import 'package:zhiyue/features/settings/providers/locale_provider.dart';

import '../../../fakes/fake_settings_repository.dart';

void main() {
  test('LocaleNotifier defaults to system', () {
    final fake = FakeSettingsRepository();
    final container = ProviderContainer(overrides: [
      localeProvider.overrideWith((ref) => LocaleNotifier(fake)),
    ]);
    addTearDown(container.dispose);
    expect(container.read(localeProvider), LocaleSetting.system);
  });

  test('setLocale persists and updates state', () async {
    final fake = FakeSettingsRepository();
    final container = ProviderContainer(overrides: [
      localeProvider.overrideWith((ref) => LocaleNotifier(fake)),
    ]);
    addTearDown(container.dispose);
    await container
        .read(localeProvider.notifier)
        .setLocale(LocaleSetting.english);
    expect(container.read(localeProvider), LocaleSetting.english);
    expect(await fake.get<String?>('app.locale', null), 'english');
  });

  test('LocaleNotifier hydrates from persisted value', () async {
    final fake = FakeSettingsRepository();
    await fake.set<String?>('app.locale', 'chinese');
    final notifier = LocaleNotifier(fake);
    addTearDown(notifier.dispose);
    // _load runs in constructor; pump to allow the async hydration to settle.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(notifier.state, LocaleSetting.chinese);
  });
}
