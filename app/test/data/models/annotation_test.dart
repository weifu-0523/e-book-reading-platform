import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/data/models/annotation.dart';

void main() {
  group('Annotation', () {
    test('is a highlight when note is null', () {
      final a = Annotation(
        id: 'a1',
        bookNoteId: 'bn1',
        locator: const EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
        quote: '风险即未来的不确定性',
        note: null,
        color: HighlightColor.yellow,
        tags: const [],
        source: AnnotationSource.manual,
        createdAt: DateTime(2026, 6, 24),
        updatedAt: DateTime(2026, 6, 24),
      );
      expect(a.isHighlightOnly, isTrue);
      expect(a.hasNote, isFalse);
    });

    test('is a note when note is non-null', () {
      final a = Annotation(
        id: 'a1',
        bookNoteId: 'bn1',
        locator: const EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
        quote: '风险即未来的不确定性',
        note: '我的思考：...',
        color: HighlightColor.green,
        tags: const ['风险管理'],
        source: AnnotationSource.manual,
        createdAt: DateTime(2026, 6, 24),
        updatedAt: DateTime(2026, 6, 24),
      );
      expect(a.isHighlightOnly, isFalse);
      expect(a.hasNote, isTrue);
    });

    test('tags are unmodifiable', () {
      final a = Annotation(
        id: 'a1',
        bookNoteId: 'bn1',
        locator: const EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0),
        quote: '',
        note: null,
        color: HighlightColor.yellow,
        tags: const ['t1'],
        source: AnnotationSource.manual,
        createdAt: DateTime(2026, 6, 24),
        updatedAt: DateTime(2026, 6, 24),
      );
      expect(() => a.tags.add('t2'), throwsUnsupportedError);
    });
  });
}
