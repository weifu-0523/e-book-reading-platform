import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/models/search_result.dart';

void main() {
  group('SearchResult equality', () {
    final locator = EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0);

    test('equals by content', () {
      final a = SearchResult(
        bookId: 'b1',
        bookTitle: '与天为敌',
        locator: locator,
        snippet: '风险即未来',
        matchCount: 2,
      );
      final b = SearchResult(
        bookId: 'b1',
        bookTitle: '与天为敌',
        locator: locator,
        snippet: '风险即未来',
        matchCount: 2,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('not equals when bookId differs', () {
      final a = SearchResult(
        bookId: 'b1',
        bookTitle: 't',
        locator: locator,
        snippet: '',
        matchCount: 1,
      );
      final b = SearchResult(
        bookId: 'b2',
        bookTitle: 't',
        locator: locator,
        snippet: '',
        matchCount: 1,
      );
      expect(a, isNot(equals(b)));
    });

    test('not equals when snippet differs', () {
      final a = SearchResult(
        bookId: 'b1',
        bookTitle: 't',
        locator: locator,
        snippet: 's1',
        matchCount: 1,
      );
      final b = SearchResult(
        bookId: 'b1',
        bookTitle: 't',
        locator: locator,
        snippet: 's2',
        matchCount: 1,
      );
      expect(a, isNot(equals(b)));
    });

    test('not equals when matchCount differs', () {
      final a = SearchResult(
        bookId: 'b1',
        bookTitle: 't',
        locator: locator,
        snippet: '',
        matchCount: 1,
      );
      final b = SearchResult(
        bookId: 'b1',
        bookTitle: 't',
        locator: locator,
        snippet: '',
        matchCount: 2,
      );
      expect(a, isNot(equals(b)));
    });

    test('not equals when locator differs', () {
      final a = SearchResult(
        bookId: 'b1',
        bookTitle: 't',
        locator: EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
        snippet: '',
        matchCount: 1,
      );
      final b = SearchResult(
        bookId: 'b1',
        bookTitle: 't',
        locator: EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 1),
        snippet: '',
        matchCount: 1,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
