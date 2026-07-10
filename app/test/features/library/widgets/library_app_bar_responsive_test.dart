// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/library/models/sort_by.dart';
import 'package:zhiyue/features/library/models/view_mode.dart';
import 'package:zhiyue/features/library/widgets/library_app_bar.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

void main() {
  Widget buildBar(double width) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Scaffold(
          appBar: LibraryAppBar(
            viewMode: ViewMode.grid,
            sortBy: SortBy.recentlyRead,
            allTags: const {' fiction ', 'tech'},
            activeTagFilters: const {},
            onViewModeChanged: (_) {},
            onSortChanged: (_) {},
            onSearch: (_) {},
            onTagFilterToggled: (_) {},
            onImportTap: () {},
            onEnterSearch: () {},
            onExitSearch: () {},
            onBatchExport: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('compact (390px) shows hamburger menu button', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildBar(390));
    await tester.pump();

    // compact 分支应该有 hamburger menu 按钮
    expect(find.byIcon(Icons.menu), findsOneWidget);
  });

  testWidgets('expanded (1200px) shows inline search + sort icons', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildBar(1200));
    await tester.pump();

    // expanded 不应有 hamburger
    expect(find.byIcon(Icons.menu), findsNothing);
    // 应有 inline search icon
    expect(find.byIcon(Icons.search), findsOneWidget);
  });
}
