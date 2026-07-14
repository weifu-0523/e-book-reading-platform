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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/features/reader/pages/reader_page.dart';
import 'package:zhiyue/features/reader/widgets/reader_scaffold.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

import '../../helpers/drift_test_helper.dart';
import '../../helpers/fixture_loader.dart';

/// M2.5-5：非 skip 的 reader 流程 widget-level integration test。
///
/// 这是在本地（Windows）能跑通的真实端到端用例，覆盖：
/// AppDatabase → BooksDao → readerEngineForBookProvider →
/// ConcreteEpubReaderEngine → EpubxRenderer → ReaderPage → ReaderScaffold。
///
/// `integration_test/reader_flow_test.dart` 中的同款测试在 CI（开启 Developer
/// Mode 的 Windows 或 Linux）上跑；本测试用普通 `flutter test` 即可运行，
/// 不依赖 Windows symlink 支持。
void main() {
  final fixtureFile = FixtureLoader.tryLoad('page-blanche.epub');
  final skipReason = fixtureFile == null
      ? 'fixture page-blanche.epub not available in this environment'
      : null;

  group(
    'Reader flow (widget-level integration)',
    () {
    testWidgets('open book → state becomes ready → tap next page',
        (tester) async {
      if (fixtureFile == null) {
        // fixture 在 .gitignore 中；CI 提供后即可跑，本地缺则跳过。
        return;
      }

      // 1. 内存数据库 + 插入一本指向真实 fixture 的书。
      final db = createTestDatabase();
      addTearDown(db.close);

      await BooksDao(db).insertOne(
        id: 'b1',
        title: 'Page Blanche',
        format: 'epub',
        filePath: fixtureFile.absolute.path,
        fileHash: 'widget-integration-hash',
        fileSizeBytes: fixtureFile.lengthSync(),
      );

      // 2. 直接 pump ReaderPage，注入 in-memory DB。
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ReaderPage(bookId: 'b1'),
          ),
        ),
      );

      // 3. 等待 engine open + spine 加载 + 首页渲染（pagination 是异步）。
      //    page-blanche.epub 很小，5 秒通常足够。
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 4. 验证 ReaderScaffold 出现（engine 已 ready 且无错误）。
      expect(
        find.byType(ReaderScaffold),
        findsOneWidget,
        reason: 'Engine should reach ready state with real fixture',
      );

      // 5. 在 paged 模式下，点击右侧 1/3 区域 → onTapNext。
      //    使用屏幕右侧 80% 位置避开任何边缘 hit-test 死区。
      final size = tester.getSize(find.byType(ReaderScaffold));
      await tester.tapAt(Offset(size.width * 0.8, size.height / 2));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // 6. 验证未崩溃：ReaderScaffold 仍在树中。
      expect(find.byType(ReaderScaffold), findsOneWidget);
    });
  },
    skip: skipReason,
  );
}
