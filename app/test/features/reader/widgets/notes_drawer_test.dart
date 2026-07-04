import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/features/reader/widgets/notes_drawer.dart';

Annotation _a(String id, int chapterIdx, {String? note}) => Annotation(
      id: id,
      bookNoteId: 'bn1',
      locator: EpubRangeLocator(
          chapterIndex: chapterIdx, startOffset: 0, endOffset: 3, quote: 'q$id'),
      quote: 'q$id',
      note: note,
      color: HighlightColor.yellow,
      tags: const [],
      source: AnnotationSource.manual,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets('groups annotations by chapterTitle', (tester) async {
    final annotations = [_a('a1', 0), _a('a2', 1), _a('a3', 0)];
    final chapters = {0: '第 1 章', 1: '第 2 章'};
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: NotesDrawer(
        annotations: annotations,
        chapterTitles: chapters,
        onTap: (_) {},
        onLongPress: (_) {},
        onClose: () {},
      ),
    )));
    expect(find.text('第 1 章'), findsOneWidget);
    expect(find.text('第 2 章'), findsOneWidget);
    expect(find.text('qa1'), findsOneWidget);
    expect(find.text('qa2'), findsOneWidget);
    expect(find.text('qa3'), findsOneWidget);
  });

  testWidgets('empty annotations shows hint', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: NotesDrawer(
        annotations: const [],
        chapterTitles: const {},
        onTap: (_) {},
        onLongPress: (_) {},
        onClose: () {},
      ),
    )));
    expect(find.text('本书暂无高亮与笔记'), findsOneWidget);
  });

  testWidgets('tap annotation fires onTap with id', (tester) async {
    String? tappedId;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: NotesDrawer(
        annotations: [_a('a1', 0)],
        chapterTitles: const {0: 'ch'},
        onTap: (id) => tappedId = id,
        onLongPress: (_) {},
        onClose: () {},
      ),
    )));
    await tester.tap(find.text('qa1'));
    expect(tappedId, 'a1');
  });

  group('M3e/Q7: right-click + visible action buttons', () {
    testWidgets('no callbacks → no action buttons / no right-click wiring',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: NotesDrawer(
          annotations: [_a('a1', 0)],
          chapterTitles: const {0: 'ch'},
          onTap: (_) {},
          onLongPress: (_) {},
          onClose: () {},
        ),
      )));
      // 旧行为：无可见按钮、无右键（向后兼容）。
      expect(find.byTooltip('编辑笔记'), findsNothing);
      expect(find.byTooltip('删除'), findsNothing);
      expect(find.byTooltip('导出'), findsNothing);
    });

    testWidgets('providing callbacks renders visible 编辑/导出/删除 buttons',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: NotesDrawer(
          annotations: [_a('a1', 0)],
          chapterTitles: const {0: 'ch'},
          onTap: (_) {},
          onLongPress: (_) {},
          onClose: () {},
          onEdit: (_) {},
          onExport: (_) {},
          onDelete: (_) {},
        ),
      )));
      expect(find.byTooltip('编辑笔记'), findsOneWidget);
      expect(find.byTooltip('导出'), findsOneWidget);
      expect(find.byTooltip('删除'), findsOneWidget);
    });

    testWidgets('right-click fires onSecondaryTapDown with id + position',
        (tester) async {
      String? clickedId;
      Offset? clickedPos;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: NotesDrawer(
          annotations: [_a('a1', 0)],
          chapterTitles: const {0: 'ch'},
          onTap: (_) {},
          onLongPress: (_) {},
          onClose: () {},
          onSecondaryTapDown: (id, pos) {
            clickedId = id;
            clickedPos = pos;
          },
        ),
      )));
      // 模拟右键（secondary mouse tap）。
      final location = tester.getCenter(find.text('qa1'));
      final gesture = await tester.startGesture(
        location,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(clickedId, 'a1');
      expect(clickedPos, isNotNull);
    });

    testWidgets('visible 编辑 button fires onEdit with id', (tester) async {
      String? editedId;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: NotesDrawer(
          annotations: [_a('a1', 0)],
          chapterTitles: const {0: 'ch'},
          onTap: (_) {},
          onLongPress: (_) {},
          onClose: () {},
          onEdit: (id) => editedId = id,
        ),
      )));
      await tester.tap(find.byTooltip('编辑笔记'));
      expect(editedId, 'a1');
    });

    testWidgets('visible 删除 button fires onDelete with id', (tester) async {
      String? deletedId;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: NotesDrawer(
          annotations: [_a('a1', 0)],
          chapterTitles: const {0: 'ch'},
          onTap: (_) {},
          onLongPress: (_) {},
          onClose: () {},
          onDelete: (id) => deletedId = id,
        ),
      )));
      await tester.tap(find.byTooltip('删除'));
      expect(deletedId, 'a1');
    });
  });
}
