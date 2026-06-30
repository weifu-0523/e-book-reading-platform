import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart'
    show bookProvider, notesRepositoryProvider;
import 'package:zhiyue/core/widgets/empty_view.dart';
import 'package:zhiyue/core/widgets/error_view.dart';
import 'package:zhiyue/core/widgets/loading_view.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/data/repositories/notes_repository.dart';
import 'package:zhiyue/features/notes/pages/notes_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

class _EmptyNotesRepository implements NotesRepository {
  @override
  Stream<List<Annotation>> watchAnnotations(String bookId) =>
      Stream.value(const []);

  @override
  Future<BookNote?> getNoteByBook(String bookId) async => BookNote(
        id: 'bn1',
        bookId: bookId,
        title: '测试书名',
        summary: '',
        keyTakeaways: const [],
        annotations: const [],
        createdAt: DateTime(2026, 6, 27),
        updatedAt: DateTime(2026, 6, 27),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ErrorNotesRepository implements NotesRepository {
  @override
  Stream<List<Annotation>> watchAnnotations(String bookId) =>
      Stream.error(Exception('db locked'));

  @override
  Future<BookNote?> getNoteByBook(String bookId) async => BookNote(
        id: 'bn1',
        bookId: bookId,
        title: '测试书名',
        summary: '',
        keyTakeaways: const [],
        annotations: const [],
        createdAt: DateTime(2026, 6, 27),
        updatedAt: DateTime(2026, 6, 27),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LoadingNotesRepository implements NotesRepository {
  @override
  Stream<List<Annotation>> watchAnnotations(String bookId) =>
      const Stream.empty();

  @override
  Future<BookNote?> getNoteByBook(String bookId) async => BookNote(
        id: 'bn1',
        bookId: bookId,
        title: '测试书名',
        summary: '',
        keyTakeaways: const [],
        annotations: const [],
        createdAt: DateTime(2026, 6, 27),
        updatedAt: DateTime(2026, 6, 27),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness(NotesRepository repo) {
  return ProviderScope(
    overrides: [
      notesRepositoryProvider.overrideWithValue(repo),
      bookProvider('b1').overrideWith((ref) async => Book(
            id: 'b1',
            title: '测试书',
            author: '作者',
            format: BookFormat.epub,
            fileSizeBytes: 0,
            filePath: '',
            fileHash: '',
            coverPath: null,
            addedAt: DateTime(2026, 6, 27),
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

void main() {
  testWidgets('notes_page_displays EmptyView when no annotations exist',
      (tester) async {
    await tester.pumpWidget(_harness(_EmptyNotesRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyView), findsOneWidget);
    expect(find.text('本书暂无高亮与笔记'), findsOneWidget);
  });

  testWidgets('notes_page_displays LoadingView while annotations stream is pending',
      (tester) async {
    await tester.pumpWidget(_harness(_LoadingNotesRepository()));
    await tester.pump();

    expect(find.byType(LoadingView), findsOneWidget);
  });

  testWidgets('notes_page_displays ErrorView with retry when stream errors',
      (tester) async {
    await tester.pumpWidget(_harness(_ErrorNotesRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
}
