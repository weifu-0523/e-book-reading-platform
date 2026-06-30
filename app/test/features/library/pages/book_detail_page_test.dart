import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/ai/providers/book_preprocess_controller.dart';
import 'package:zhiyue/features/library/pages/book_detail_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';
import 'package:zhiyue/services/ai/book_preprocessor.dart';

import '../../../fakes/fake_book_repository.dart';

/// Inert preprocessor used to satisfy [bookPreprocessControllerProvider] in
/// widget tests that don't care about preprocessing behavior.
class _NoOpPreprocessor implements BookPreprocessorLike {
  @override
  Stream<PreprocessEvent> start(Book book) => const Stream.empty();

  @override
  void cancel() {}
}

void main() {
  late FakeBookRepository fakeRepo;
  late ProviderContainer container;

  final book = Book(
    id: 'b1',
    title: '人类简史',
    author: '尤瓦尔·赫拉利',
    format: BookFormat.epub,
    filePath: '/x.epub',
    fileHash: 'h',
    fileSizeBytes: 1024,
    coverPath: null,
    addedAt: DateTime(2026, 1, 1),
    lastReadAt: null,
  );

  setUp(() async {
    fakeRepo = FakeBookRepository();
    await fakeRepo.save(book);
    container = ProviderContainer(
      overrides: [
        bookRepositoryProvider.overrideWith((ref) => fakeRepo),
        bookPreprocessControllerProvider('b1').overrideWith(
          (ref) => BookPreprocessController(_NoOpPreprocessor()),
        ),
        bookPreprocessControllerProvider('b2').overrideWith(
          (ref) => BookPreprocessController(_NoOpPreprocessor()),
        ),
        bookPreprocessControllerProvider('missing').overrideWith(
          (ref) => BookPreprocessController(_NoOpPreprocessor()),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());

  Widget buildHarness(Widget home) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: home,
        ),
      );

  testWidgets('renders title + author + size + delete button', (tester) async {
    await tester.pumpWidget(buildHarness(const BookDetailPage(bookId: 'b1')));
    await tester.pumpAndSettle();

    expect(find.text('人类简史'), findsOneWidget);
    expect(find.textContaining('尤瓦尔·赫拉利'), findsOneWidget);
    expect(find.textContaining('1.0 KB'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('renders loading when book not found', (tester) async {
    await tester.pumpWidget(buildHarness(const BookDetailPage(bookId: 'missing')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders without author section when author null', (tester) async {
    final noAuthorBook = Book(
      id: 'b2',
      title: '无作者',
      author: null,
      format: BookFormat.epub,
      filePath: '/y.epub',
      fileHash: 'h2',
      fileSizeBytes: 2048,
      coverPath: null,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
    );
    await fakeRepo.save(noAuthorBook);

    await tester.pumpWidget(buildHarness(const BookDetailPage(bookId: 'b2')));
    await tester.pumpAndSettle();

    expect(find.text('无作者'), findsOneWidget);
    expect(find.textContaining('尤瓦尔'), findsNothing);
  });

  testWidgets('delete button triggers confirmation dialog', (tester) async {
    await tester.pumpWidget(buildHarness(const BookDetailPage(bookId: 'b1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('删除书籍？'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });

  testWidgets('confirm delete removes book from repo', (tester) async {
    await tester.pumpWidget(buildHarness(const BookDetailPage(bookId: 'b1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    // Tap the "删除" inside the dialog (second occurrence)
    final deleteButtons = find.text('删除');
    await tester.tap(deleteButtons.last);
    await tester.pumpAndSettle();

    expect(fakeRepo.deletedIds, contains('b1'));
  });
}
