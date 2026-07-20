// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:zhiyue/features/settings/default_reader/default_reader_detector.dart';
import 'package:zhiyue/features/settings/default_reader/widgets/default_reader_prompt_dialog.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

class _MockDetector extends Mock implements DefaultReaderDetector {}

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: child,
    );

void main() {
  testWidgets('dialog shows 设为默认 on Windows-style detector', (tester) async {
    final mock = _MockDetector();
    when(() => mock.supportsProgrammaticRegistration).thenReturn(true);
    when(() => mock.registerAsDefault(exePath: any(named: 'exePath')))
        .thenAnswer((_) async => true);

    await tester.pumpWidget(_wrap(DefaultReaderPromptDialog(detector: mock)));

    expect(find.textContaining('设为默认阅读器'), findsOneWidget);
    expect(find.text('设为默认'), findsOneWidget);
    expect(find.text('稍后再说'), findsOneWidget);
  });

  testWidgets('tap 设为默认 calls registerAsDefault + dismisses', (tester) async {
    final mock = _MockDetector();
    when(() => mock.supportsProgrammaticRegistration).thenReturn(true);
    when(() => mock.registerAsDefault(exePath: any(named: 'exePath')))
        .thenAnswer((_) async => true);

    bool dismissed = false;
    await tester.pumpWidget(_wrap(DefaultReaderPromptDialog(
      detector: mock,
      onDismissed: () => dismissed = true,
    )));

    await tester.tap(find.text('设为默认'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    verify(() => mock.registerAsDefault(exePath: any(named: 'exePath')))
        .called(1);
    expect(dismissed, isTrue);
  });

  testWidgets('tap 稍后再说 dismisses without registering', (tester) async {
    final mock = _MockDetector();
    when(() => mock.supportsProgrammaticRegistration).thenReturn(true);

    bool dismissed = false;
    await tester.pumpWidget(_wrap(DefaultReaderPromptDialog(
      detector: mock,
      onDismissed: () => dismissed = true,
    )));

    await tester.tap(find.text('稍后再说'));
    await tester.pump();

    verifyNever(() => mock.registerAsDefault(exePath: any(named: 'exePath')));
    expect(dismissed, isTrue);
  });

  testWidgets('Android dialog shows 打开系统设置 instead of 设为默认',
      (tester) async {
    final mock = _MockDetector();
    when(() => mock.supportsProgrammaticRegistration).thenReturn(false);
    when(() => mock.openSystemDefaultSettings()).thenAnswer((_) async => true);

    await tester.pumpWidget(_wrap(DefaultReaderPromptDialog(detector: mock)));

    expect(find.text('设为默认'), findsNothing);
    expect(find.text('打开系统设置'), findsOneWidget);
  });
}
