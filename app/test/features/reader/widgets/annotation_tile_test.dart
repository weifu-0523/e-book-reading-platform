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
}
