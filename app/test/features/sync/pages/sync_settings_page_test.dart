import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/features/sync/pages/sync_settings_page.dart';
import 'package:zhiyue/features/sync/providers/sync_controller.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';
import 'package:zhiyue/services/sync/sync_credentials.dart';

/// Minimal stub controller that exposes the same surface as [SyncController]
/// so the page can render. Constructing a real [SyncController] would require
/// a live drift [AppDatabase] + flutter_secure_storage-backed
/// [SyncCredentials], neither of which we want in a widget test that only
/// asserts on label text.
///
/// We override every method the page calls so no real sync work happens.
class _StubSyncController extends StateNotifier<SyncState>
    implements SyncController {
  _StubSyncController() : super(const SyncState());

  @override
  AppDatabase get database => throw UnimplementedError();

  @override
  SyncCredentials get credentials => throw UnimplementedError();

  @override
  Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {}

  @override
  Future<void> clearCredentials() async {}

  @override
  Future<bool> hasCredentials() async => false;

  @override
  Future<void> syncNow() async {}
}

void main() {
  testWidgets('renders username/password fields + save button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncControllerProvider.overrideWith((ref) => _StubSyncController()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: SyncSettingsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('账号'), findsOneWidget); // zh default
    expect(find.text('应用密码'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
  });

  testWidgets('shows sync now button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncControllerProvider.overrideWith((ref) => _StubSyncController()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: SyncSettingsPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('立即同步'), findsOneWidget);
  });
}
