import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/book.dart';

void main() {
  group('Book', () {
    test('creates instance with required fields', () {
      final book = Book(
        id: 'b1',
        title: '与天为敌',
        author: '彼得·伯恩斯坦',
        format: BookFormat.epub,
        filePath: '/library/abc.epub',
        fileHash: 'abc123',
        fileSizeBytes: 1024,
        coverPath: null,
        addedAt: DateTime(2026, 6, 24),
        lastReadAt: null,
      );
      expect(book.title, '与天为敌');
      expect(book.format, BookFormat.epub);
    });

    test('copyWith updates only specified fields', () {
      final book = Book(
        id: 'b1',
        title: 't',
        author: null,
        format: BookFormat.epub,
        filePath: 'p',
        fileHash: 'h',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: DateTime(2026, 6, 24),
        lastReadAt: null,
      );
      final updated = book.copyWith(lastReadAt: DateTime(2026, 6, 25));
      expect(updated.lastReadAt, DateTime(2026, 6, 25));
      expect(updated.title, 't'); // 未变
    });

    test('equality by id', () {
      final b1 = Book(
        id: 'x',
        title: 'a',
        author: null,
        format: BookFormat.pdf,
        filePath: '',
        fileHash: '',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: DateTime(2026, 6, 24),
        lastReadAt: null,
      );
      final b2 = Book(
        id: 'x',
        title: 'b',
        author: null,
        format: BookFormat.pdf,
        filePath: '',
        fileHash: '',
        fileSizeBytes: 0,
        coverPath: null,
        addedAt: DateTime(2026, 6, 24),
        lastReadAt: null,
      );
      expect(b1, b2); // 仅 id 相等即视为相等
    });
  });
}
