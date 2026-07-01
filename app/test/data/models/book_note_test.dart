import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book_note.dart';

void main() {
  group('BookNote', () {
    test('creates empty note', () {
      final note = BookNote.empty(
        id: 'bn1',
        bookId: 'b1',
        bookTitle: '与天为敌',
      );
      expect(note.title, '《与天为敌》读书笔记');
      expect(note.summary, '');
      expect(note.keyTakeaways, isEmpty);
      expect(note.annotations, isEmpty);
    });

    test('copyWith replaces keyTakeaways immutably', () {
      final note = BookNote.empty(id: 'bn1', bookId: 'b1', bookTitle: 't');
      final updated = note.copyWith(
        keyTakeaways: const ['点 1', '点 2'],
      );
      expect(updated.keyTakeaways, ['点 1', '点 2']);
      expect(note.keyTakeaways, isEmpty); // 原对象不变
    });
  });

  group('BookNote equality', () {
    const locator = EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0);
    final created = DateTime(2026, 6, 24);
    final updated = DateTime(2026, 6, 25);

    Annotation annotation(String id) => Annotation(
          id: id,
          bookNoteId: 'bn1',
          locator: locator,
          quote: '引文',
          note: null,
          color: HighlightColor.yellow,
          tags: const ['t'],
          source: AnnotationSource.manual,
          createdAt: created,
          updatedAt: created,
        );

    test('equals by content (including List fields)', () {
      // 用共享 annotation 实例：Annotation 自身未实现 ==，
      // BookNote 的 == 通过 listEquals 比较列表元素，
      // 元素按引用相等时才能匹配；这是 BookNote == 的契约。
      final ann = annotation('a1');
      final a = BookNote(
        id: 'bn1',
        bookId: 'b1',
        title: 't',
        summary: 's',
        keyTakeaways: const ['点 1', '点 2'],
        annotations: [ann],
        createdAt: created,
        updatedAt: updated,
      );
      final b = BookNote(
        id: 'bn1',
        bookId: 'b1',
        title: 't',
        summary: 's',
        keyTakeaways: const ['点 1', '点 2'],
        annotations: [ann],
        createdAt: created,
        updatedAt: updated,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('not equals when keyTakeaways content differs', () {
      final a = BookNote(
        id: 'bn1',
        bookId: 'b1',
        title: 't',
        summary: 's',
        keyTakeaways: const ['点 1'],
        annotations: const [],
        createdAt: created,
        updatedAt: updated,
      );
      final b = BookNote(
        id: 'bn1',
        bookId: 'b1',
        title: 't',
        summary: 's',
        keyTakeaways: const ['点 1', '点 2'],
        annotations: const [],
        createdAt: created,
        updatedAt: updated,
      );
      expect(a, isNot(equals(b)));
    });

    test('not equals when annotations content differs', () {
      final a = BookNote(
        id: 'bn1',
        bookId: 'b1',
        title: 't',
        summary: 's',
        keyTakeaways: const [],
        annotations: [annotation('a1')],
        createdAt: created,
        updatedAt: updated,
      );
      final b = BookNote(
        id: 'bn1',
        bookId: 'b1',
        title: 't',
        summary: 's',
        keyTakeaways: const [],
        annotations: [annotation('a2')],
        createdAt: created,
        updatedAt: updated,
      );
      expect(a, isNot(equals(b)));
    });

    test('not equals when summary differs', () {
      final a = BookNote(
        id: 'bn1',
        bookId: 'b1',
        title: 't',
        summary: 's1',
        keyTakeaways: const [],
        annotations: const [],
        createdAt: created,
        updatedAt: updated,
      );
      final b = BookNote(
        id: 'bn1',
        bookId: 'b1',
        title: 't',
        summary: 's2',
        keyTakeaways: const [],
        annotations: const [],
        createdAt: created,
        updatedAt: updated,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
