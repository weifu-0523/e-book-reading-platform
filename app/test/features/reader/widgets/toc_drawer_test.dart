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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:zhiyue/features/reader/widgets/toc_drawer.dart';

void main() {
  testWidgets('renders TOC entries', (tester) async {
    const toc = TableOfContents(entries: [
      TocEntry(
        title: '第一章',
        locator: EpubCfiLocator(cfi: '/6', chapterIndex: 0),
      ),
      TocEntry(
        title: '第二章',
        locator: EpubCfiLocator(cfi: '/8', chapterIndex: 1),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TocDrawer(toc: toc, onSelect: (_) {}),
          ),
        ),
      ),
    );

    expect(find.text('第一章'), findsOneWidget);
    expect(find.text('第二章'), findsOneWidget);
  });

  testWidgets('tap entry triggers onSelect', (tester) async {
    const toc = TableOfContents(entries: [
      TocEntry(title: 'A', locator: EpubCfiLocator(cfi: '/6', chapterIndex: 0)),
    ]);

    TocEntry? selected;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TocDrawer(toc: toc, onSelect: (e) => selected = e),
          ),
        ),
      ),
    );

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(selected?.title, 'A');
  });
}
