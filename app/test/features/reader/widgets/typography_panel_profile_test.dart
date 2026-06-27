import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:zhiyue/data/models/typography_profile.dart';
import 'package:zhiyue/data/models/user_font.dart';
import 'package:zhiyue/features/reader/widgets/typography_panel.dart';

void main() {
  final profiles = [
    TypographyProfile(
        id: 'p1',
        name: '默认',
        settings: TypographySettings.defaults(),
        isDefault: true),
    TypographyProfile(
        id: 'p2',
        name: 'P2',
        settings: TypographySettings.defaults(),
        isDefault: false),
  ];

  testWidgets('renders profile dropdown when profiles provided', (tester) async {
    TypographyProfile? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TypographyPanel(
          current: TypographySettings.defaults(),
          onChanged: (_) {},
          profiles: profiles,
          currentProfile: profiles[0],
          onSelectProfile: (p) => selected = p,
          onSaveAsProfile:
              ({required settings, required overwrite, newName}) async {},
        ),
      ),
    ));
    await tester.tap(find.byType(DropdownButton<TypographyProfile>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('P2').last);
    await tester.pumpAndSettle();
    expect(selected?.id, 'p2');
  });

  testWidgets('tap 存为预设 opens dialog with overwrite/save-new options',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TypographyPanel(
          current: TypographySettings.defaults(),
          onChanged: (_) {},
          profiles: profiles,
          currentProfile: profiles[0],
          onSelectProfile: (_) {},
          onSaveAsProfile:
              ({required settings, required overwrite, newName}) async {},
        ),
      ),
    ));
    await tester.tap(find.text('存为预设'));
    await tester.pumpAndSettle();
    expect(find.textContaining('覆盖当前'), findsOneWidget);
    expect(find.text('另存为新预设'), findsOneWidget);
  });

  testWidgets('renders user font ChoiceChip when userFonts provided',
      (tester) async {
    final userFont = UserFont(
      id: 'u1',
      displayName: 'MyFont',
      fileName: 'myfont.ttf',
      familyName: 'MyFont',
      hashSha1: 'abc',
      absolutePath: '/tmp/myfont.ttf',
      addedAt: DateTime(2026, 6, 27),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TypographyPanel(
          current: TypographySettings.defaults().copyWith(fontFamily: 'MyFont'),
          onChanged: (_) {},
          userFonts: [userFont],
        ),
      ),
    ));
    expect(find.text('MyFont'), findsOneWidget);
  });
}
