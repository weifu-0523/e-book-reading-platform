import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/library/providers/library_controller.dart';
import 'package:zhiyue/features/reader/widgets/bookshelf_dialog.dart';

import '../../../fakes/fake_book_repository.dart';
import '../../../fakes/fake_book_tags_lookup.dart';
import '../../../fakes/fake_settings_repository.dart';

Book _book(String id, {String title = 'title'}) {
  return Book(
    id: id,
    title: '$title-$id',
    author: null,
    format: BookFormat.epub,
    filePath: '/$id.epub',
    fileHash: 'h-$id',
    fileSizeBytes: 1,
    coverPath: null,
    addedAt: DateTime(2026, 1, 1),
    lastReadAt: null,
  );
}

/// Builds a ProviderScope overriding [libraryControllerProvider] to expose
/// the given [books], without touching the database layer.
Widget buildDialogApp({
  required List<Book> books,
  required String currentBookId,
}) {
  final bookRepo = FakeBookRepository();
  final tagsLookup = FakeBookTagsLookup();
  final settings = FakeSettingsRepository();
  for (final b in books) {
    bookRepo.addBook(b);
  }
  return ProviderScope(
    overrides: [
      bookRepositoryProvider.overrideWith((ref) => bookRepo),
      settingsRepositoryProvider.overrideWith((ref) => settings),
      libraryControllerProvider.overrideWith((ref) => LibraryController(
            bookRepository: bookRepo,
            bookTagsLookup: tagsLookup,
            settingsRepository: settings,
          )),
    ],
    child: MaterialApp(
      home: BookshelfDialog(currentBookId: currentBookId),
    ),
  );
}

void main() {
  group('BookshelfDialog (M3c/任务6b)', () {
    testWidgets('renders the book grid with all books', (tester) async {
      await tester.pumpWidget(buildDialogApp(
        books: [_book('b1', title: '甲'), _book('b2', title: '乙')],
        currentBookId: 'b1',
      ));
      // Let the watchAll stream emit into the controller's state.
      await tester.pumpAndSettle();

      expect(find.text('书架'), findsOneWidget);
      expect(find.text('甲-b1'), findsOneWidget);
      expect(find.text('乙-b2'), findsOneWidget);
    });

    testWidgets('marks the current book with "阅读中" badge', (tester) async {
      await tester.pumpWidget(buildDialogApp(
        books: [_book('b1'), _book('b2')],
        currentBookId: 'b1',
      ));
      await tester.pumpAndSettle();

      // Only the current book gets the 阅读中 badge.
      expect(find.text('阅读中'), findsOneWidget);
    });

    testWidgets('close button pops the dialog', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryControllerProvider.overrideWith((ref) => LibraryController(
                  bookRepository: FakeBookRepository()..addBook(_book('b1')),
                  bookTagsLookup: FakeBookTagsLookup(),
                  settingsRepository: FakeSettingsRepository(),
                )),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    useRootNavigator: true,
                    builder: (_) =>
                        const BookshelfDialog(currentBookId: 'b1'),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('书架'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bookshelf_dialog_close')));
      await tester.pumpAndSettle();

      expect(find.text('书架'), findsNothing);
    });

    testWidgets('tapping a non-current book navigates via pushReplacement',
        (tester) async {
      // A GoRouter so context.pushReplacement works.
      final router = GoRouter(
        initialLocation: '/reader',
        routes: [
          GoRoute(
            path: '/reader',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      useRootNavigator: true,
                      builder: (_) =>
                          const BookshelfDialog(currentBookId: 'b1'),
                    ),
                    child: const Text('open-dialog'),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/book/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return Scaffold(body: Text('reader:$id'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryControllerProvider.overrideWith((ref) => LibraryController(
                  bookRepository: FakeBookRepository()
                    ..addBook(_book('b1'))
                    ..addBook(_book('b2')),
                  bookTagsLookup: FakeBookTagsLookup(),
                  settingsRepository: FakeSettingsRepository(),
                )),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open-dialog'));
      await tester.pumpAndSettle();
      expect(find.text('书架'), findsOneWidget);

      // Tap the other book (b2).
      await tester.tap(find.text('title-b2'));
      await tester.pumpAndSettle();

      // pushReplacement navigates to /book/b2, rendering the reader route.
      expect(find.text('reader:b2'), findsOneWidget);
    });
  });
}
