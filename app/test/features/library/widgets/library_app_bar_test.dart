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
import 'package:zhiyue/features/library/models/sort_by.dart';
import 'package:zhiyue/features/library/models/view_mode.dart';
import 'package:zhiyue/features/library/widgets/library_app_bar.dart';
import 'package:zhiyue/features/sync/models/sync_status.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

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
    VoidCallback? onBatchExport,
    SyncStatus? syncStatus,
    VoidCallback? onSyncTap,
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
      onBatchExport: onBatchExport ?? () {},
      syncStatus: syncStatus,
      onSyncTap: onSyncTap,
    );
  }

  Widget wrapAppBar(LibraryAppBar appBar) => MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(appBar: appBar),
      );

  testWidgets('renders title + action icons in idle mode', (tester) async {
    await tester.pumpWidget(wrapAppBar(buildAppBar()));
    expect(find.text('智阅'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.sort), findsOneWidget);
    expect(find.byIcon(Icons.grid_view), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('list view mode shows view_list icon (switch to grid)',
      (tester) async {
    await tester.pumpWidget(wrapAppBar(buildAppBar(viewMode: ViewMode.list)));
    expect(find.byIcon(Icons.view_list), findsOneWidget);
  });

  testWidgets('tapping view-mode button toggles via callback', (tester) async {
    ViewMode? captured;
    await tester.pumpWidget(wrapAppBar(buildAppBar(
      viewMode: ViewMode.grid,
      onViewModeChanged: (v) => captured = v,
    )));
    await tester.tap(find.byIcon(Icons.grid_view));
    expect(captured, ViewMode.list);
  });

  testWidgets('tapping import button fires callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrapAppBar(buildAppBar(
      onImportTap: () => tapped = true,
    )));
    await tester.tap(find.byIcon(Icons.add));
    expect(tapped, isTrue);
  });

  testWidgets('searching mode shows text field instead of title', (tester) async {
    await tester.pumpWidget(wrapAppBar(buildAppBar(searching: true)));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('智阅'), findsNothing);
  });

  testWidgets('tapping search icon fires onEnterSearch', (tester) async {
    var entered = false;
    await tester.pumpWidget(wrapAppBar(buildAppBar(
      onEnterSearch: () => entered = true,
    )));
    await tester.tap(find.byIcon(Icons.search));
    expect(entered, isTrue);
  });

  testWidgets('searching mode hides search icon + shows back arrow',
      (tester) async {
    var exited = false;
    await tester.pumpWidget(wrapAppBar(buildAppBar(
      searching: true,
      onExitSearch: () => exited = true,
    )));
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    expect(exited, isTrue);
  });

  testWidgets('tag filter icon appears only when allTags non-empty',
      (tester) async {
    // No tags
    await tester.pumpWidget(wrapAppBar(buildAppBar(allTags: {})));
    expect(find.byIcon(Icons.label_outline), findsNothing);

    // Has tags
    await tester.pumpWidget(wrapAppBar(buildAppBar(allTags: {'心理学', '认知'})));
    expect(find.byIcon(Icons.label_outline), findsOneWidget);
  });

  testWidgets('sort popup menu contains all 6 options when opened',
      (tester) async {
    await tester.pumpWidget(wrapAppBar(buildAppBar()));
    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    expect(find.text('最近阅读'), findsOneWidget);
    expect(find.text('添加时间'), findsOneWidget);
    expect(find.text('书名'), findsOneWidget);
    expect(find.text('作者'), findsOneWidget);
    expect(find.text('阅读进度'), findsOneWidget);
    expect(find.text('手动排序'), findsOneWidget);
  });

  testWidgets('batch export icon is rendered and tappable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrapAppBar(buildAppBar(
      onBatchExport: () => tapped = true,
    )));
    expect(find.byIcon(Icons.folder_zip_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.folder_zip_outlined));
    expect(tapped, isTrue);
  });

  // v1.11.9-alpha Bug 2: library AppBar 增加立即同步按钮。
  //
  // 用户报告：「在书架级的导航条上，增加一个立即同步的按钮」。原来 library
  // AppBar 没有 sync 入口，用户必须去 settings/sync 才能触发同步。
  group('v1.11.9-alpha Bug 2: sync button', () {
    testWidgets('renders sync icon button when syncStatus provided',
        (tester) async {
      await tester.pumpWidget(wrapAppBar(buildAppBar(
        syncStatus: SyncStatus.idle,
        onSyncTap: () {},
      )));
      expect(find.byTooltip('立即同步'), findsOneWidget);
    });

    testWidgets('does NOT render sync button when syncStatus is null',
        (tester) async {
      // 调用方未配置同步（如未登录）时不渲染按钮，避免无用 UI。
      await tester.pumpWidget(wrapAppBar(buildAppBar()));
      expect(find.byTooltip('立即同步'), findsNothing);
    });

    testWidgets('tapping sync button fires callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrapAppBar(buildAppBar(
        syncStatus: SyncStatus.idle,
        onSyncTap: () => tapped = true,
      )));
      await tester.tap(find.byTooltip('立即同步'));
      expect(tapped, isTrue);
    });

    testWidgets('sync button is disabled when status is pushing',
        (tester) async {
      await tester.pumpWidget(wrapAppBar(buildAppBar(
        syncStatus: SyncStatus.pushing,
        onSyncTap: () {},
      )));
      final btn = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('立即同步'),
          matching: find.byType(IconButton),
        ),
      );
      expect(btn.onPressed, isNull,
          reason: '正在同步中应禁用按钮，防止重入');
    });

    testWidgets('sync button is disabled when status is offline',
        (tester) async {
      await tester.pumpWidget(wrapAppBar(buildAppBar(
        syncStatus: SyncStatus.offline,
        onSyncTap: () {},
      )));
      final btn = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('立即同步'),
          matching: find.byType(IconButton),
        ),
      );
      expect(btn.onPressed, isNull,
          reason: '离线状态应禁用按钮');
    });

    testWidgets('sync button rendered in compact mode too', (tester) async {
      // compact 视口（< 600dp）下 AppBar 走 _buildCompactBar 分支，仍要渲染
      // 同步按钮（用户报告特指「书架级导航条」，含手机端）。
      tester.view.physicalSize = const Size(360 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrapAppBar(buildAppBar(
        syncStatus: SyncStatus.idle,
        onSyncTap: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.byTooltip('立即同步'), findsOneWidget);
    });
  });
}
