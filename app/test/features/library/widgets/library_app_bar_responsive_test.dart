// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/library/models/sort_by.dart';
import 'package:zhiyue/features/library/models/view_mode.dart';
import 'package:zhiyue/features/library/widgets/library_app_bar.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

void main() {
  Widget buildBar(double width, {bool searching = false, VoidCallback? onExitSearch}) {
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
            searching: searching,
            onViewModeChanged: (_) {},
            onSortChanged: (_) {},
            onSearch: (_) {},
            onTagFilterToggled: (_) {},
            onImportTap: () {},
            onEnterSearch: () {},
            onExitSearch: onExitSearch ?? () {},
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

  // Mobile MVP S1 — compact searching branch coverage (library_app_bar.dart:76-93).
  // When searching=true on compact, the bar swaps:
  //   leading: menu → arrow_back
  //   title  : Text → TextField
  //   actions: [add, more_vert] → [] (search toggle icon hidden)
  group('compact searching branch', () {
    testWidgets(
        'searching=true at 390px shows arrow_back (not menu) + TextField + no search toggle',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildBar(390, searching: true));
      await tester.pump();

      // arrow_back should be present as the leading icon (exit-search affordance).
      expect(find.byIcon(Icons.arrow_back), findsOneWidget,
          reason: 'searching branch replaces hamburger with back arrow');
      // menu icon should NOT be present (it's hidden in searching state).
      expect(find.byIcon(Icons.menu), findsNothing,
          reason: 'hamburger is hidden while searching');

      // TextField should be mounted in the title slot.
      expect(find.byType(TextField), findsOneWidget,
          reason: 'searching branch renders a TextField as the title');

      // The standalone search-toggle icon (Icons.search) is only rendered on
      // the expanded branch when NOT searching. On compact searching the
      // text field itself is the search affordance, so Icons.search must be
      // absent to avoid duplicate / confusing affordances.
      expect(find.byIcon(Icons.search), findsNothing,
          reason: 'compact searching hides the search toggle icon');
    });

    testWidgets('tapping arrow_back in searching state fires onExitSearch',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var exitSearchCalls = 0;
      await tester.pumpWidget(buildBar(
        390,
        searching: true,
        onExitSearch: () => exitSearchCalls++,
      ));
      await tester.pump();

      // Initial state: no callback fired yet.
      expect(exitSearchCalls, 0);

      // Tap the arrow_back button — this is the only IconButton in the
      // searching branch (actions is empty).
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      expect(exitSearchCalls, 1,
          reason: 'arrow_back tap should invoke onExitSearch exactly once');
    });
  });
}
