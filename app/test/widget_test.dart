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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/app.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/features/library/providers/library_controller.dart';

import 'fakes/fake_book_repository.dart';
import 'fakes/fake_book_tags_lookup.dart';
import 'fakes/fake_settings_repository.dart';

/// 启动冒烟测试：验证 ZhiYueApp 能成功构建并显示 LibraryPage 的 AppBar 标题。
///
/// M0+M1 阶段此处检查 HomePage 的占位文本；M3.1 后 '/' 路由切到 LibraryPage，
/// 该页通过 LibraryController 监听 drift，测试需 override 相关 provider 为 fake
/// 以避免 teardown 时 drift 残留 zero-delay timer。
void main() {
  testWidgets('App boots and shows LibraryPage', (tester) async {
    final bookRepo = FakeBookRepository();
    final tagsLookup = FakeBookTagsLookup();
    // Pin locale to zh so the Chinese assertion on '书库为空' stays stable.
    final settings = FakeSettingsRepository()
      ..setSync<String?>('app.locale', 'chinese');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepositoryProvider.overrideWith((ref) => bookRepo),
          settingsRepositoryProvider.overrideWith((ref) => settings),
          libraryControllerProvider.overrideWith((ref) => LibraryController(
                bookRepository: bookRepo,
                bookTagsLookup: tagsLookup,
                settingsRepository: settings,
              )),
        ],
        child: const ZhiYueApp(),
      ),
    );
    await tester.pumpAndSettle();

    // LibraryPage 的 AppBar 标题
    expect(find.text('智阅'), findsOneWidget);
    // 空库时显示空态文案
    expect(find.text('书库为空'), findsOneWidget);
  });
}
