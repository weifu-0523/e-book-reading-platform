import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/ai/pages/api_key_settings_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';
import 'package:zhiyue/services/ai/api_key_store.dart';

class _MemStore implements ApiKeyStore {
  AiCredentials? c;
  _MemStore(this.c);
  @override
  Future<AiCredentials?> load() async => c;
  @override
  Future<void> save(AiCredentials v) async => c = v;
  @override
  Future<void> clear() async => c = null;
}

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: child,
    );

void main() {
  testWidgets('renders form with 3 TextFields and a save button',
      (tester) async {
    await tester.pumpWidget(_wrap(ApiKeySettingsPage(store: _MemStore(null))));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('清空'), findsOneWidget);
  });

  testWidgets('save button disabled when api key is empty', (tester) async {
    await tester.pumpWidget(_wrap(ApiKeySettingsPage(store: _MemStore(null))));
    await tester.pumpAndSettle();
    final saveBtn = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(saveBtn.onPressed, isNull);
  });

  testWidgets('entering api key enables save; tapping calls store.save',
      (tester) async {
    final store = _MemStore(null);
    await tester.pumpWidget(_wrap(ApiKeySettingsPage(store: store)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'sk-test');
    await tester.pump();
    final saveBtn = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(saveBtn.onPressed, isNotNull);
    await tester.tap(find.text('保存'));
    await tester.pump();
    expect(store.c, isNotNull);
    expect(store.c!.apiKey, 'sk-test');
  });

  testWidgets('clear button calls store.clear and resets fields',
      (tester) async {
    final store = _MemStore(const AiCredentials(
      apiKey: 'k',
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-chat',
    ));
    await tester.pumpWidget(_wrap(ApiKeySettingsPage(store: store)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空'));
    await tester.pump();
    expect(store.c, isNull);
  });

  testWidgets('show/hide toggle changes obscureText', (tester) async {
    await tester.pumpWidget(_wrap(ApiKeySettingsPage(store: _MemStore(null))));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).obscureText,
      true,
    );
    await tester.tap(find.byTooltip('显示'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).obscureText,
      false,
    );
  });
}
