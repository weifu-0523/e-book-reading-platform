import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/library/models/sort_by.dart';
import 'package:zhiyue/features/library/models/view_mode.dart';
import 'package:zhiyue/features/library/widgets/library_app_bar.dart';

void main() {
  LibraryAppBar buildAppBar({
    ViewMode viewMode = ViewMode.grid,
    SortBy sortBy = SortBy.recentlyRead,
    Set<String> allTags = const {},
    Set<String> activeTagFilters = const {},
    bool searching = false,
    ValueChanged<ViewMode>? onViewModeChanged,
    ValueChanged<SortBy>? onSortChanged,
    ValueChanged<String>? onSearch,
    ValueChanged<String>? onTagFilterToggled,
    VoidCallback? onImportTap,
    VoidCallback? onEnterSearch,
    VoidCallback? onExitSearch,
  }) {
    return LibraryAppBar(
      viewMode: viewMode,
      sortBy: sortBy,
      allTags: allTags,
      activeTagFilters: activeTagFilters,
      searching: searching,
      onViewModeChanged: onViewModeChanged ?? (_) {},
      onSortChanged: onSortChanged ?? (_) {},
      onSearch: onSearch ?? (_) {},
      onTagFilterToggled: onTagFilterToggled ?? (_) {},
      onImportTap: onImportTap ?? () {},
      onEnterSearch: onEnterSearch ?? () {},
      onExitSearch: onExitSearch ?? () {},
    );
  }

  testWidgets('renders title + action icons in idle mode', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(appBar: buildAppBar()),
    ));
    expect(find.text('智阅'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.sort), findsOneWidget);
    expect(find.byIcon(Icons.grid_view), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('list view mode shows view_list icon (switch to grid)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(appBar: buildAppBar(viewMode: ViewMode.list)),
    ));
    expect(find.byIcon(Icons.view_list), findsOneWidget);
  });

  testWidgets('tapping view-mode button toggles via callback', (tester) async {
    ViewMode? captured;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: buildAppBar(
          viewMode: ViewMode.grid,
          onViewModeChanged: (v) => captured = v,
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.grid_view));
    expect(captured, ViewMode.list);
  });

  testWidgets('tapping import button fires callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: buildAppBar(onImportTap: () => tapped = true),
      ),
    ));
    await tester.tap(find.byIcon(Icons.add));
    expect(tapped, isTrue);
  });

  testWidgets('searching mode shows text field instead of title', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(appBar: buildAppBar(searching: true)),
    ));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('智阅'), findsNothing);
  });

  testWidgets('tapping search icon fires onEnterSearch', (tester) async {
    var entered = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: buildAppBar(onEnterSearch: () => entered = true),
      ),
    ));
    await tester.tap(find.byIcon(Icons.search));
    expect(entered, isTrue);
  });

  testWidgets('searching mode hides search icon + shows back arrow',
      (tester) async {
    var exited = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: buildAppBar(
          searching: true,
          onExitSearch: () => exited = true,
        ),
      ),
    ));
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    expect(exited, isTrue);
  });

  testWidgets('tag filter icon appears only when allTags non-empty',
      (tester) async {
    // No tags
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(appBar: buildAppBar(allTags: {})),
    ));
    expect(find.byIcon(Icons.label_outline), findsNothing);

    // Has tags
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(appBar: buildAppBar(allTags: {'心理学', '认知'})),
    ));
    expect(find.byIcon(Icons.label_outline), findsOneWidget);
  });

  testWidgets('sort popup menu contains all 6 options when opened',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(appBar: buildAppBar()),
    ));
    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    expect(find.text('最近阅读'), findsOneWidget);
    expect(find.text('添加时间'), findsOneWidget);
    expect(find.text('书名'), findsOneWidget);
    expect(find.text('作者'), findsOneWidget);
    expect(find.text('阅读进度'), findsOneWidget);
    expect(find.text('手动排序'), findsOneWidget);
  });
}
