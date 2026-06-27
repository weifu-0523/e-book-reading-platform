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
