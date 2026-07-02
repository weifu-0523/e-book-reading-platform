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

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:go_router/go_router.dart';
import 'package:reader_engine/core/locator.dart';

import '../features/ai/pages/api_key_settings_page.dart';
import '../features/bookmarks/pages/bookmarks_page.dart';
import '../features/library/pages/book_detail_page.dart';
import '../features/library/pages/library_page.dart';
import '../features/notes/pages/notes_page.dart';
import '../features/reader/pages/reader_page.dart';
import '../features/search/pages/search_highlights_page.dart';
import '../features/settings/pages/about_page.dart';
import '../features/settings/pages/font_management_page.dart';
import '../features/settings/pages/settings_page.dart';
import '../features/settings/pages/typography_profiles_page.dart';
import '../features/sync/pages/sync_settings_page.dart';
import '../features/sync/pages/sync_status_page.dart';
import 'app_providers.dart';

/// 应用路由配置。
///
/// M3.1 用 go_router 替换 M2 的 onGenerateRoute，便于后续扩展
/// （详情页、笔记页、设置页等）。
GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LibraryPage(),
      ),
      GoRoute(
        path: '/book/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final locator = state.extra as Locator?;
          return ReaderPage(bookId: id, initialLocator: locator);
        },
      ),
      GoRoute(
        path: '/book/:id/details',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BookDetailPage(bookId: id);
        },
      ),
      GoRoute(
        path: '/book/:id/notes',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return NotesPage(bookId: id);
        },
      ),
      GoRoute(
        path: '/book/:id/bookmarks',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return BookmarksPage(bookId: id);
        },
      ),
      GoRoute(
        path: '/search/highlights',
        builder: (context, state) => const SearchHighlightsPage(),
      ),
      // 注意：go_router 按顺序匹配，更具体的子路径必须放在 /settings 之前
      GoRoute(
        path: '/settings/typography',
        builder: (context, state) => const TypographyProfilesPage(),
      ),
      GoRoute(
        path: '/settings/fonts',
        builder: (context, state) => const FontManagementPage(),
      ),
      GoRoute(
        path: '/settings/about',
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: '/settings/sync',
        builder: (context, state) => const SyncSettingsPage(),
      ),
      GoRoute(
        path: '/settings/sync/status',
        builder: (context, state) => const SyncStatusPage(),
      ),
      GoRoute(
        path: '/settings/ai',
        builder: (context, state) => Consumer(
          builder: (ctx, ref, _) =>
              ApiKeySettingsPage(store: ref.watch(apiKeyStoreProvider)),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
}

/// 应用级 [GoRouter] 实例 provider。
///
/// M7 重构：原来 [createAppRouter] 在 ZhiYueApp.build 里每次重建都新建 router
/// （Flutter 反模式）；改为 Riverpod 单例后，BookOpenBridge 和 ZhiYueApp
/// 共用同一 router 实例。
final routerProvider = Provider<GoRouter>((ref) {
  return createAppRouter();
});
