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
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:reader_engine/reader_engine.dart';
import 'package:zhiyue/features/reader/widgets/toc_drawer.dart';
import 'package:zhiyue/features/reader/widgets/reader_bottom_bar.dart';

void main() {
  testGoldens('TocDrawer golden', (tester) async {
    const toc = TableOfContents(entries: [
      TocEntry(title: '第一章 引子', locator: EpubCfiLocator(cfi: '/6', chapterIndex: 0)),
      TocEntry(title: '第二章 起点', locator: EpubCfiLocator(cfi: '/8', chapterIndex: 1)),
      TocEntry(title: '第三章 转折', locator: EpubCfiLocator(cfi: '/10', chapterIndex: 2)),
    ]);

    await tester.pumpWidgetBuilder(
      SizedBox(
        height: 400,
        child: TocDrawer(toc: toc, onSelect: (_) {}),
      ),
      wrapper: materialAppWrapper(
        theme: ThemeData.light(),
        platform: TargetPlatform.android,
      ),
    );
    await screenMatchesGolden(tester, 'toc_drawer');
  });

  testGoldens('ReaderBottomBar golden', (tester) async {
    final builder = GoldenBuilder.column()
      ..addScenario(
        'Has title',
        const ReaderBottomBar(chapterTitle: '第三章 风暴', percent: 0.42),
      )
      ..addScenario(
        'No title',
        const ReaderBottomBar(chapterTitle: null, percent: 0.0),
      );

    await tester.pumpWidgetBuilder(
      builder.build(),
      wrapper: materialAppWrapper(
        theme: ThemeData.light(),
        platform: TargetPlatform.android,
      ),
    );
    await screenMatchesGolden(tester, 'reader_bottom_bar_states');
  });
}
