import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/book_open_bridge.dart';

void main() {
  group('BookOpenBridge.isSupportedBookPath', () {
    test('accepts .epub paths', () {
      expect(BookOpenBridge.isSupportedBookPath('/tmp/book.epub'), isTrue);
      expect(BookOpenBridge.isSupportedBookPath('C:\\Users\\me\\book.epub'), isTrue);
    });

    test('accepts .pdf paths', () {
      expect(BookOpenBridge.isSupportedBookPath('/tmp/paper.pdf'), isTrue);
      expect(BookOpenBridge.isSupportedBookPath('C:\\docs\\paper.pdf'), isTrue);
    });

    test('rejects non-book extensions', () {
      expect(BookOpenBridge.isSupportedBookPath('/tmp/readme.txt'), isFalse);
      expect(BookOpenBridge.isSupportedBookPath('/tmp/image.png'), isFalse);
      expect(BookOpenBridge.isSupportedBookPath('/tmp/'), isFalse);
    });

    test('rejects empty / null-like paths', () {
      expect(BookOpenBridge.isSupportedBookPath(''), isFalse);
      expect(BookOpenBridge.isSupportedBookPath('book'), isFalse);
    });

    test('case-insensitive on extensions', () {
      expect(BookOpenBridge.isSupportedBookPath('/tmp/BOOK.EPUB'), isTrue);
      expect(BookOpenBridge.isSupportedBookPath('/tmp/Paper.PDF'), isTrue);
    });
  });
}
