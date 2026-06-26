import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/features/reader/widgets/note_editor_sheet.dart';

Annotation _sample({HighlightColor c = HighlightColor.yellow, String? note}) =>
    Annotation(
      id: 'a1',
      bookNoteId: 'bn1',
      locator: const EpubRangeLocator(
          chapterIndex: 0, startOffset: 0, endOffset: 3, quote: 'xyz'),
      quote: 'xyz',
      note: note,
      color: c,
      tags: const ['哲学'],
      source: AnnotationSource.manual,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets('shows quote as read-only + initial note + tags', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: NoteEditorSheet(
        annotation: _sample(note: '初始笔记'),
        suggestions: const [],
        onSave: (_, __) async {},
        onDelete: () async {},
      ),
    )));
    expect(find.text('xyz'), findsOneWidget);
    expect(find.text('初始笔记'), findsOneWidget);
    expect(find.text('哲学'), findsOneWidget);
  });

  testWidgets('tapping save fires with edited note + color', (tester) async {
    String? savedNote;
    HighlightColor? savedColor;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: NoteEditorSheet(
        annotation: _sample(note: '初始'),
        suggestions: const [],
        onSave: (note, color) async {
          savedNote = note;
          savedColor = color;
        },
        onDelete: () async {},
      ),
    )));
    await tester.enterText(find.byKey(const Key('note_field')), '修改后');
    await tester.tap(find.text('蓝色'));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(savedNote, '修改后');
    expect(savedColor, HighlightColor.blue);
  });

  testWidgets('delete button triggers confirm then onDelete', (tester) async {
    var deleted = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: NoteEditorSheet(
        annotation: _sample(),
        suggestions: const [],
        onSave: (_, __) async {},
        onDelete: () async => deleted = true,
      ),
    )));
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });
}
