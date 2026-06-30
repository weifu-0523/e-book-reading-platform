import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/core/providers.dart'
    show bookProvider, notesRepositoryProvider;
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/data/repositories/notes_repository.dart';
import 'package:zhiyue/features/notes/pages/notes_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

class _FakeNotesRepository implements NotesRepository {
  final List<Annotation> annotations;
  _FakeNotesRepository(this.annotations);

  @override
  Stream<List<Annotation>> watchAnnotations(String bookId) =>
      Stream.value(annotations);

  @override
  Future<BookNote?> getNoteByBook(String bookId) async => BookNote(
        id: 'bn1',
        bookId: bookId,
        title: 'PDF 测试书',
        summary: '',
        keyTakeaways: const [],
        annotations: annotations,
        createdAt: DateTime(2026, 6, 28),
        updatedAt: DateTime(2026, 6, 28),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('PDF annotations grouped by 第 N 页', (tester) async {
    final annotations = [
      Annotation(
        id: 'a1',
        bookNoteId: 'b1',
        locator: const PdfRangeLocator(
            page: 5, startOffset: 0, endOffset: 2, quote: 'p5'),
        quote: 'p5',
        note: null,
        color: HighlightColor.yellow,
        tags: const [],
        source: AnnotationSource.manual,
        createdAt: DateTime(2026, 6, 28),
        updatedAt: DateTime(2026, 6, 28),
      ),
      Annotation(
        id: 'a2',
        bookNoteId: 'b1',
        locator: const PdfRangeLocator(
            page: 3, startOffset: 0, endOffset: 2, quote: 'p3'),
        quote: 'p3',
        note: null,
        color: HighlightColor.red,
        tags: const [],
        source: AnnotationSource.manual,
        createdAt: DateTime(2026, 6, 28),
        updatedAt: DateTime(2026, 6, 28),
      ),
    ];

    await tester.pumpWidget(_harness(annotations));
    await tester.pumpAndSettle();

    // Both page labels rendered.
    expect(find.text('第 3 页'), findsOneWidget);
    expect(find.text('第 5 页'), findsOneWidget);
    // Should not fall through to EPUB fallback.
    expect(find.text('未分类'), findsNothing);
  });
}

Widget _harness(List<Annotation> anns) {
  return ProviderScope(
    overrides: [
      notesRepositoryProvider.overrideWithValue(_FakeNotesRepository(anns)),
      bookProvider('b1').overrideWith((ref) async => Book(
            id: 'b1',
            title: 'PDF 测试书',
            author: '作者',
            format: BookFormat.pdf,
            fileSizeBytes: 0,
            filePath: '',
            fileHash: '',
            coverPath: null,
            addedAt: DateTime(2026, 6, 28),
            lastReadAt: null,
          )),
    ],
    child: const MaterialApp(
      locale: Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NotesPage(bookId: 'b1'),
    ),
  );
}
