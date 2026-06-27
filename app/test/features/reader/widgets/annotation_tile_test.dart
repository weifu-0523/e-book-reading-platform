import 'package:flutter/material.dart';
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
    Annotation _annotation({
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
            annotation: _annotation(tags: const ['t1']),
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
            annotation: _annotation(tags: const ['t1']),
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
            annotation: _annotation(tags: const ['t1', 't2']),
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
                _annotation(updatedAt: DateTime(2026, 6, 27, 14, 32)),
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
            annotation: _annotation(
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
            annotation: _annotation(tags: const []),
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
            annotation: _annotation(
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
            annotation: _annotation(),
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
            annotation: _annotation(),
            showMeta: true,
            onLongPress: () => longPressed = true,
          ),
        ),
      ));
      await tester.longPress(find.byType(AnnotationTile));
      expect(longPressed, isTrue);
    });
  });
}
