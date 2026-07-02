import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';
import 'package:zhiyue/features/reader/widgets/reader_scaffold.dart';

void main() {
  testWidgets('paged mode tap right triggers next', (tester) async {
    var nextTapped = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            onTapPrev: () {},
            onTapNext: () => nextTapped = true,
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(750, 400));
    await tester.pumpAndSettle();

    expect(nextTapped, isTrue);
  });

  testWidgets('paged mode tap left triggers prev', (tester) async {
    var prevTapped = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            onTapPrev: () => prevTapped = true,
            onTapNext: () {},
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(50, 400));
    await tester.pumpAndSettle();

    expect(prevTapped, isTrue);
  });

  testWidgets('scroll mode tap right does NOT trigger prev/next', (tester) async {
    var nextTapped = false;
    var prevTapped = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.scroll,
            onTapPrev: () => prevTapped = true,
            onTapNext: () => nextTapped = true,
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(750, 400));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(50, 400));
    await tester.pumpAndSettle();

    expect(nextTapped, isFalse);
    expect(prevTapped, isFalse);
  });

  testWidgets('chrome is revealed by toggling readerUiControllerProvider',
      (tester) async {
    // Center-tap no longer reveals chrome (T5 removed it; T6/T9 own chrome UI).
    // Verify the canonical way to reveal chrome in tests is via the provider.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ReaderScaffold(
            content: Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            onTapPrev: nil,
            onTapNext: nil,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('reader_app_bar')), findsNothing);
    container.read(readerUiControllerProvider.notifier).toggleChrome();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader_app_bar')), findsOneWidget);
  });
}

void nil() {}
