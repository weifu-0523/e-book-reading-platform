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
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/features/reader/widgets/annotation_tile.dart';

Annotation _a({String? note, List<String> tags = const []}) => Annotation(
      id: 'a1',
      bookNoteId: 'bn1',
      locator: const EpubRangeLocator(
          chapterIndex: 1, startOffset: 0, endOffset: 3, quote: '选中片段'),
      quote: '选中片段',
      note: note,
      color: HighlightColor.yellow,
      tags: tags,
      source: AnnotationSource.manual,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets('renders color bar + quote + chapter', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: AnnotationTile(annotation: _a(), chapterTitle: '第 1 章'),
    )));
    expect(find.text('选中片段'), findsOneWidget);
    expect(find.text('第 1 章'), findsOneWidget);
  });

  testWidgets('shows note when present', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: AnnotationTile(annotation: _a(note: '我的批注'), chapterTitle: 'ch'),
    )));
    expect(find.text('我的批注'), findsOneWidget);
  });

  testWidgets('tap fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: AnnotationTile(
        annotation: _a(),
        chapterTitle: 'ch',
        onTap: () => tapped = true,
      ),
    )));
    await tester.tap(find.text('选中片段'));
    expect(tapped, isTrue);
  });

  testWidgets('long press fires onLongPress', (tester) async {
    var longPressed = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: AnnotationTile(
        annotation: _a(),
        chapterTitle: 'ch',
        onLongPress: () => longPressed = true,
      ),
    )));
    await tester.longPress(find.text('选中片段'));
    expect(longPressed, isTrue);
  });

  group('showMeta', () {
    Annotation annotation({
      List<String> tags = const [],
      DateTime? updatedAt,
    }) {
      final updated = updatedAt ?? DateTime(2026, 6, 27, 10, 30);
      return Annotation(
        id: 'm1',
        bookNoteId: 'b1',
        locator: const EpubRangeLocator(
            chapterIndex: 0, startOffset: 0, endOffset: 1, quote: 'q'),
        quote: 'q',
        note: null,
        color: HighlightColor.yellow,
        tags: tags,
        source: AnnotationSource.manual,
        createdAt: DateTime(2026, 6, 20),
        updatedAt: updated,
      );
    }

    testWidgets('default (showMeta omitted) hides date + tags', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnnotationTile(
            annotation: annotation(tags: const ['t1']),
          ),
        ),
      ));
      expect(find.textContaining('#t1'), findsNothing);
      expect(find.textContaining('06-27'), findsNothing);
    });

    testWidgets('showMeta=false explicitly hides date + tags', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnnotationTile(
            annotation: annotation(tags: const ['t1']),
            showMeta: false,
          ),
        ),
      ));
      expect(find.textContaining('#t1'), findsNothing);
    });

    testWidgets('showMeta=true shows tags line', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnnotationTile(
            annotation: annotation(tags: const ['t1', 't2']),
            showMeta: true,
          ),
        ),
      ));
      expect(find.textContaining('#t1'), findsOneWidget);
      expect(find.textContaining('#t2'), findsOneWidget);
    });

    testWidgets('showMeta=true shows updated date', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnnotationTile(
            annotation:
                annotation(updatedAt: DateTime(2026, 6, 27, 14, 32)),
            showMeta: true,
          ),
        ),
      ));
      expect(find.textContaining('06-27 14:32'), findsOneWidget);
    });

    testWidgets('showMeta=true joins date + tags with ·', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnnotationTile(
            annotation: annotation(
              tags: const ['psychology'],
              updatedAt: DateTime(2026, 6, 27, 14, 32),
            ),
            showMeta: true,
          ),
        ),
      ));
      expect(find.textContaining('06-27 14:32 · #psychology'), findsOneWidget);
    });

    testWidgets('showMeta=true with no tags shows date only', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnnotationTile(
            annotation: annotation(tags: const []),
            showMeta: true,
          ),
        ),
      ));
      expect(find.textContaining('06-27 10:30'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('showMeta=true with date but empty tags list omits ·',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnnotationTile(
            annotation: annotation(
              tags: const [],
              updatedAt: DateTime(2026, 6, 27, 14, 32),
            ),
            showMeta: true,
          ),
        ),
      ));
      expect(find.textContaining('06-27 14:32'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('showMeta=true does not break onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnnotationTile(
            annotation: annotation(),
            showMeta: true,
            onTap: () => tapped = true,
          ),
        ),
      ));
      await tester.tap(find.byType(AnnotationTile));
      expect(tapped, isTrue);
    });

    testWidgets('showMeta=true does not break onLongPress', (tester) async {
      var longPressed = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnnotationTile(
            annotation: annotation(),
            showMeta: true,
            onLongPress: () => longPressed = true,
          ),
        ),
      ));
      await tester.longPress(find.byType(AnnotationTile));
      expect(longPressed, isTrue);
    });
  });

  group('onSecondaryTapDown (desktop right-click)', () {
    testWidgets('right-click fires onSecondaryTapDown with global position',
        (tester) async {
      Offset? received;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnnotationTile(
            annotation: _a(),
            onSecondaryTapDown: (pos) => received = pos,
          ),
        ),
      ));
      final center = tester.getCenter(find.byType(AnnotationTile));
      final gesture = await tester.startGesture(
        center,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.up();
      await tester.pump();
      expect(received, isNotNull);
    });

    testWidgets('right-click does not fire onTap (no conflict)', (tester) async {
      var tapped = false;
      var rightClicked = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnnotationTile(
            annotation: _a(),
            onTap: () => tapped = true,
            onSecondaryTapDown: (_) => rightClicked = true,
          ),
        ),
      ));
      final center = tester.getCenter(find.byType(AnnotationTile));
      final gesture = await tester.startGesture(
        center,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.up();
      await tester.pump();
      expect(rightClicked, isTrue);
      expect(tapped, isFalse);
    });

    testWidgets('without onSecondaryTapDown, left tap still works',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnnotationTile(
            annotation: _a(),
            onTap: () => tapped = true,
          ),
        ),
      ));
      await tester.tap(find.byType(AnnotationTile));
      expect(tapped, isTrue);
    });
  });

  group('visible action buttons (M3e/Q6)', () {
    testWidgets('no actions callbacks → no action buttons rendered', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: AnnotationTile(annotation: _a())),
      ));
      expect(find.byTooltip('编辑笔记'), findsNothing);
      expect(find.byTooltip('导出'), findsNothing);
      expect(find.byTooltip('删除'), findsNothing);
    });

    testWidgets('onEdit/onExport/onDelete render 3 IconButtons', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnnotationTile(
            annotation: _a(),
            onEdit: () {},
            onExport: () {},
            onDelete: () {},
          ),
        ),
      ));
      expect(find.byTooltip('编辑笔记'), findsOneWidget);
      expect(find.byTooltip('导出'), findsOneWidget);
      expect(find.byTooltip('删除'), findsOneWidget);
    });

    testWidgets('partial callbacks render only provided buttons', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnnotationTile(annotation: _a(), onDelete: () {}),
        ),
      ));
      expect(find.byTooltip('编辑笔记'), findsNothing);
      expect(find.byTooltip('导出'), findsNothing);
      expect(find.byTooltip('删除'), findsOneWidget);
    });

    testWidgets('tapping 编辑 fires onEdit', (tester) async {
      var edited = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnnotationTile(annotation: _a(), onEdit: () => edited = true),
        ),
      ));
      await tester.tap(find.byTooltip('编辑笔记'));
      expect(edited, isTrue);
    });

    testWidgets('tapping 删除 fires onDelete', (tester) async {
      var deleted = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AnnotationTile(annotation: _a(), onDelete: () => deleted = true),
        ),
      ));
      await tester.tap(find.byTooltip('删除'));
      expect(deleted, isTrue);
    });
  });
}
