import 'package:test/test.dart';
import 'package:reader_engine/core/book_ref.dart';

void main() {
  test('constructs with required fields', () {
    final ref = BookRef(
      id: 'b1',
      title: '追风筝的人',
      format: BookFormat.epub,
      filePath: '/library/abc.epub',
    );
    expect(ref.id, 'b1');
    expect(ref.title, '追风筝的人');
    expect(ref.format, BookFormat.epub);
  });

  test('equality by id', () {
    final a = BookRef(
      id: 'b1',
      title: 'A',
      format: BookFormat.epub,
      filePath: '/a',
    );
    final b = BookRef(
      id: 'b1',
      title: 'B',
      format: BookFormat.epub,
      filePath: '/b',
    );
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });
}
