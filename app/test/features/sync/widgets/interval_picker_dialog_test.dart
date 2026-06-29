import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/sync/widgets/interval_picker_dialog.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

Widget _wrapped(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('shows current interval with check mark', (tester) async {
    await tester.pumpWidget(_wrapped(
      IntervalPickerDialog(
        current: const Duration(minutes: 5),
        onChanged: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('每 5 分钟'), findsOneWidget);
  });

  testWidgets('tapping an option calls onChanged and pops', (tester) async {
    Duration? picked;
    await tester.pumpWidget(_wrapped(
      IntervalPickerDialog(
        current: const Duration(minutes: 5),
        onChanged: (d) => picked = d,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('每 15 分钟'));
    await tester.pumpAndSettle();

    expect(picked, const Duration(minutes: 15));
  });

  testWidgets('off option shows "关闭" label', (tester) async {
    await tester.pumpWidget(_wrapped(
      IntervalPickerDialog(
        current: Duration.zero,
        onChanged: (_) {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('关闭（仅手动）'), findsOneWidget);
  });
}
