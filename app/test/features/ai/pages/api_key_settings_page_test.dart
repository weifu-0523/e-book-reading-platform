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

/// v1.12.2-alpha P2: ApiKeySettingsPage now has 3 TextField + 3 Slider +
/// help text, total content height > the default 800x600 viewport. Pump
/// with a taller surface so the save / clear buttons stay tappable.
Future<void> _pumpPage(WidgetTester tester, ApiKeyStore store) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_wrap(ApiKeySettingsPage(store: store)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders form with 3 TextFields and a save button',
      (tester) async {
    await _pumpPage(tester, _MemStore(null));
    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('保存'), findsOneWidget);
    expect(find.text('清空'), findsOneWidget);
  });

  testWidgets('save button disabled when api key is empty', (tester) async {
    await _pumpPage(tester, _MemStore(null));
    final saveBtn = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(saveBtn.onPressed, isNull);
  });

  testWidgets('entering api key enables save; tapping calls store.save',
      (tester) async {
    final store = _MemStore(null);
    await _pumpPage(tester, store);
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
    await _pumpPage(tester, store);
    await tester.tap(find.text('清空'));
    await tester.pump();
    expect(store.c, isNull);
  });

  testWidgets('show/hide toggle changes obscureText', (tester) async {
    await _pumpPage(tester, _MemStore(null));
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

  // B5 (2026-07-14)：baseUrl HTTPS 校验。
  // 默认 safe（HTTPS 或 localhost）直接保存；非 safe 弹 AlertDialog 二次确认。

  testWidgets('HTTPS baseUrl saves without confirmation dialog',
      (tester) async {
    final store = _MemStore(null);
    await _pumpPage(tester, store);
    await tester.enterText(find.byType(TextField).first, 'sk-test');
    await tester.enterText(find.byType(TextField).at(1), 'https://api.openai.com');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.c, isNotNull);
    expect(store.c!.baseUrl, 'https://api.openai.com');
    expect(find.byType(AlertDialog), findsNothing,
        reason: 'HTTPS safe URL must not trigger confirmation dialog');
  });

  testWidgets('HTTP localhost saves without confirmation dialog',
      (tester) async {
    final store = _MemStore(null);
    await _pumpPage(tester, store);
    await tester.enterText(find.byType(TextField).first, 'sk-test');
    await tester.enterText(find.byType(TextField).at(1), 'http://localhost:8080');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.c, isNotNull);
    expect(store.c!.baseUrl, 'http://localhost:8080');
    expect(find.byType(AlertDialog), findsNothing,
        reason: 'localhost is safe for local dev');
  });

  testWidgets('HTTP public domain triggers confirmation; cancel does not save',
      (tester) async {
    final store = _MemStore(null);
    await _pumpPage(tester, store);
    await tester.enterText(find.byType(TextField).first, 'sk-test');
    await tester.enterText(
        find.byType(TextField).at(1), 'http://api.deepseek.com');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget,
        reason: 'unsafe HTTP public domain must trigger confirmation');
    // Cancel
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(store.c, isNull, reason: 'cancel must not save');
  });

  testWidgets(
      'HTTP public domain confirmation; confirm proceeds with save',
      (tester) async {
    final store = _MemStore(null);
    await _pumpPage(tester, store);
    await tester.enterText(find.byType(TextField).first, 'sk-test');
    await tester.enterText(
        find.byType(TextField).at(1), 'http://api.deepseek.com');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('确认继续'));
    await tester.pumpAndSettle();
    expect(store.c, isNotNull, reason: 'confirm must proceed with save');
    expect(store.c!.baseUrl, 'http://api.deepseek.com');
  });

  testWidgets('invalid scheme (ftp) triggers confirmation; cancel blocks save',
      (tester) async {
    final store = _MemStore(null);
    await _pumpPage(tester, store);
    await tester.enterText(find.byType(TextField).first, 'sk-test');
    await tester.enterText(find.byType(TextField).at(1), 'ftp://example.com');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(store.c, isNull);
  });

  testWidgets('empty baseUrl falls back to default (HTTPS, safe)',
      (tester) async {
    final store = _MemStore(null);
    await _pumpPage(tester, store);
    await tester.enterText(find.byType(TextField).first, 'sk-test');
    await tester.pump();
    // Leave baseUrl empty
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(store.c, isNotNull);
    expect(store.c!.baseUrl, ApiCredentialsDefaults.baseUrl);
    expect(find.byType(AlertDialog), findsNothing,
        reason: 'default baseUrl is HTTPS, must not trigger confirmation');
  });
}
