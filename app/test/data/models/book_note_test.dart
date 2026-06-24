import 'package:flutter_test/flutter_test.dart';
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
}
