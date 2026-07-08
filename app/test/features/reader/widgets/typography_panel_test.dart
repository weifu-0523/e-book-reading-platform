import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/repositories/settings_repository.dart';
import 'package:zhiyue/features/reader/widgets/typography_panel.dart';

void main() {
  // 2026-07-08 BUG #4: TypographyPanel 改 ConsumerWidget 后需要 ProviderScope。
  // override settingsRepositoryProvider 为 in-memory fake，避免依赖 sqlite。
  Future<void> pumpPanel(
    WidgetTester tester,
    TypographySettings initial,
    ValueChanged<TypographySettings> onChanged,
  ) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(_FakeSettingsRepo()),
      ],
      child: MaterialApp(
        home: Material(
          child: SingleChildScrollView(
            child: TypographyPanel(current: initial, onChanged: onChanged),
          ),
        ),
      ),
    ));
  }

  testWidgets('shows current font size', (tester) async {
    await pumpPanel(tester, TypographySettings.defaults(), (_) {});
    // M3a/任务7: 默认字号 16→18。
    expect(find.textContaining('18'), findsOneWidget);
  });

  testWidgets('panel shows all control sections incl 段落', (tester) async {
    await pumpPanel(tester, TypographySettings.defaults(), (_) {});
    expect(find.text('字号'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('行距'), findsOneWidget);
    expect(find.text('字体'), findsOneWidget);
    expect(find.text('段落'), findsOneWidget);
    expect(find.text('页边距'), findsOneWidget);
    // 2026-07-08 BUG #4: 新增「应用主题」区块。
    expect(find.text('应用主题'), findsOneWidget);
  });

  testWidgets('tapping lineHeight chip emits new settings', (tester) async {
    TypographySettings? captured;
    await pumpPanel(
      tester,
      // 用非默认 lineHeight 起点，避免默认值已 == 1.8 导致 chip 选中态干扰。
      TypographySettings.defaults().copyWith(lineHeight: 1.5),
      (s) => captured = s,
    );
    // "宽松" appears in both 行距 and 页边距 sections — first occurrence is 行距
    await tester.tap(find.text('宽松').at(0));
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured!.lineHeight, 1.8);
  });

  testWidgets('font options are 系统/黑体/宋体/楷体/普惠体/新晰黑 (M3e/Q3)',
      (tester) async {
    await pumpPanel(tester, TypographySettings.defaults(), (_) {});
    expect(find.text('黑体'), findsOneWidget);
    expect(find.text('宋体'), findsOneWidget);
    expect(find.text('楷体'), findsOneWidget);
    // M3e/Q3: 新增 2 款字体
    expect(find.text('普惠体'), findsOneWidget);
    expect(find.text('新晰黑'), findsOneWidget);
    // old generic-family labels removed
    expect(find.text('衬线'), findsNothing);
    expect(find.text('无衬线'), findsNothing);
  });

  testWidgets('tapping 普惠体 chip emits fontFamily AlibabaPuHuiTi (M3e/Q3)',
      (tester) async {
    TypographySettings? captured;
    await pumpPanel(tester, TypographySettings.defaults(), (s) => captured = s);
    await tester.tap(find.text('普惠体'));
    await tester.pump();
    expect(captured?.fontFamily, 'AlibabaPuHuiTi');
  });

  testWidgets('tapping 黑体 chip emits fontFamily NotoSansSC', (tester) async {
    TypographySettings? captured;
    await pumpPanel(
      tester,
      TypographySettings.defaults(),
      (s) => captured = s,
    );
    await tester.tap(find.text('黑体'));
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured!.fontFamily, 'NotoSansSC');
  });

  testWidgets('tapping pageMargin chip emits new settings', (tester) async {
    TypographySettings? captured;
    await pumpPanel(
      tester,
      // 起点非 wide，避免默认选中态干扰。
      TypographySettings.defaults().copyWith(pageMargin: PageMargin.normal),
      (s) => captured = s,
    );
    // "宽松" appears in 行距 and 页边距; 页边距 is the later occurrence.
    await tester.tap(find.text('宽松').at(1));
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured!.pageMargin, PageMargin.wide);
  });

  testWidgets('tapping theme chip emits new settings', (tester) async {
    TypographySettings? captured;
    await pumpPanel(
      tester,
      TypographySettings.defaults(),
      (s) => captured = s,
    );
    // 阅读主题 '深' = ReadingTheme.dark（注意：与"应用主题"区块的"深色"区分）。
    await tester.tap(find.text('深'));
    await tester.pump();
    expect(captured, isNotNull);
    expect(captured!.theme, ReadingTheme.dark);
  });

  testWidgets('font increase button emits clamped settings', (tester) async {
    TypographySettings? captured;
    await pumpPanel(
      tester,
      TypographySettings.defaults(),
      (s) => captured = s,
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(captured, isNotNull);
    // M3a/任务7: 默认字号 16→18，+1 = 19。
    expect(captured!.fontSize, 19.0);
  });
}

/// 简单 in-memory fake，给 themeModeProvider 提供 mock 仓储。
class _FakeSettingsRepo implements SettingsRepository {
  final Map<String, dynamic> _data = {};
  @override
  Future<T> get<T>(String key, T defaultValue) async =>
      (_data[key] as T?) ?? defaultValue;
  @override
  Future<T?> getOrNull<T>(String key) async => _data[key] as T?;
  @override
  Future<void> set<T>(String key, T value) async {
    _data[key] = value;
  }
}
