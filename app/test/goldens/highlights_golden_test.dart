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
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/features/reader/widgets/annotation_tile.dart';
import 'package:zhiyue/features/reader/widgets/notes_drawer.dart';

final _sample = Annotation(
  id: 'a1',
  bookNoteId: 'bn1',
  locator: const EpubRangeLocator(
      chapterIndex: 0, startOffset: 0, endOffset: 5, quote: '活着本身就是意义'),
  quote: '活着本身就是意义',
  note: '呼应主题',
  color: HighlightColor.yellow,
  tags: const ['哲学'],
  source: AnnotationSource.manual,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  testGoldens('AnnotationTile golden', (tester) async {
    await tester.pumpWidgetBuilder(
      SizedBox(
        width: 320,
        child: AnnotationTile(
          annotation: _sample,
          chapterTitle: '第 1 章',
        ),
      ),
      wrapper: materialAppWrapper(
        theme: ThemeData.light(),
        platform: TargetPlatform.android,
      ),
    );
    await screenMatchesGolden(tester, 'highlights/annotation_tile');
  });

  testGoldens('NotesDrawer golden', (tester) async {
    await tester.pumpWidgetBuilder(
      SizedBox(
        width: 280,
        child: NotesDrawer(
          annotations: [_sample],
          chapterTitles: const {0: '第 1 章'},
          onTap: (_) {},
          onLongPress: (_) {},
          onClose: () {},
        ),
      ),
      wrapper: materialAppWrapper(
        theme: ThemeData.light(),
        platform: TargetPlatform.android,
      ),
    );
    await screenMatchesGolden(tester, 'highlights/notes_drawer');
  });
}
