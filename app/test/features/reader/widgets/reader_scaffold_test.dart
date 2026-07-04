import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/features/reader/controllers/reader_ui_controller.dart';
import 'package:zhiyue/features/reader/widgets/reader_clock.dart';
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
            // M2.6/T9: explicit margin so tap at 750 falls inside right zone
            // (right zone = [800 - 48, 800] = [752, 800]).
            marginPx: 48,
            onTapPrev: () {},
            onTapNext: () => nextTapped = true,
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(770, 400));
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
            // M2.6/T9: explicit margin so tap at 30 falls inside left zone
            // (left zone = [0, 48]).
            marginPx: 48,
            onTapPrev: () => prevTapped = true,
            onTapNext: () {},
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(30, 400));
    await tester.pumpAndSettle();

    expect(prevTapped, isTrue);
  });

  testWidgets('scroll mode tap in zones still triggers page (M2.6/T9)',
      (tester) async {
    // M2.6/T9: tap zones are mode-independent. Scroll mode also pages on
    // margin taps (only wheel-scroll is gated to paged mode now).
    var nextTapped = false;
    var prevTapped = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.scroll,
            marginPx: 48,
            onTapPrev: () => prevTapped = true,
            onTapNext: () => nextTapped = true,
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(770, 400));
    await tester.pumpAndSettle();
    expect(nextTapped, isTrue);

    await tester.tapAt(const Offset(30, 400));
    await tester.pumpAndSettle();
    expect(prevTapped, isTrue);
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

  // ── M3c：顶栏时钟 + 字号± + 书架按钮 ───────────────────────────────

  testWidgets('title is a ReaderClock when chrome is visible', (tester) async {
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
    container.read(readerUiControllerProvider.notifier).toggleChrome();
    await tester.pumpAndSettle();

    expect(find.byType(ReaderClock), findsOneWidget);
  });

  testWidgets('renders font decrease / increase icons (M3c/任务6a)',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            onTapPrev: nil,
            onTapNext: nil,
            onFontDecrease: () {},
            onFontIncrease: () {},
          ),
        ),
      ),
    );
    container.read(readerUiControllerProvider.notifier).toggleChrome();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reader_font_decrease')), findsOneWidget);
    expect(find.byKey(const Key('reader_font_increase')), findsOneWidget);
    expect(find.byIcon(Icons.text_decrease), findsOneWidget);
    expect(find.byIcon(Icons.text_increase), findsOneWidget);
  });

  testWidgets('font increase tap invokes callback (M3c/任务6a)',
      (tester) async {
    var increased = false;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            onTapPrev: nil,
            onTapNext: nil,
            onFontIncrease: () => increased = true,
          ),
        ),
      ),
    );
    container.read(readerUiControllerProvider.notifier).toggleChrome();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reader_font_increase')));
    await tester.pumpAndSettle();

    expect(increased, isTrue);
  });

  testWidgets('font decrease tap invokes callback (M3c/任务6a)',
      (tester) async {
    var decreased = false;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            onTapPrev: nil,
            onTapNext: nil,
            onFontDecrease: () => decreased = true,
          ),
        ),
      ),
    );
    container.read(readerUiControllerProvider.notifier).toggleChrome();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reader_font_decrease')));
    await tester.pumpAndSettle();

    expect(decreased, isTrue);
  });

  testWidgets('renders and triggers the bookshelf button (M3c/任务6b)',
      (tester) async {
    var bookshelfOpened = false;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            onTapPrev: nil,
            onTapNext: nil,
            onOpenBookshelf: () => bookshelfOpened = true,
          ),
        ),
      ),
    );
    container.read(readerUiControllerProvider.notifier).toggleChrome();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reader_open_bookshelf')), findsOneWidget);
    expect(find.byIcon(Icons.collections_bookmark_outlined), findsOneWidget);

    await tester.tap(find.byKey(const Key('reader_open_bookshelf')));
    await tester.pumpAndSettle();

    expect(bookshelfOpened, isTrue);
  });

  testWidgets(
      'M3e/Q4: bookshelf + font± buttons are in the AppBar leading region '
      '(left of clock)', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ReaderScaffold(
            content: const Center(child: Text('book')),
            title: 't',
            paginationMode: PaginationMode.paged,
            onTapPrev: nil,
            onTapNext: nil,
            onOpenBookshelf: () {},
            onFontDecrease: () {},
            onFontIncrease: () {},
          ),
        ),
      ),
    );
    container.read(readerUiControllerProvider.notifier).toggleChrome();
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    // leading 不再是单个 IconButton，而是含 4 个按钮的 Row。
    expect(appBar.leading, isA<Row>(),
        reason: 'M3e/Q4: leading 应为 Row（返回 + 书架 + 字号±）');
    final leadingRow = appBar.leading! as Row;
    expect(leadingRow.children.length, 4,
        reason: 'leading Row 含 4 个 IconButton');
    // 3 个关键按钮（书架/字号-/字号+）确实在 leading Row 内。
    final leadingKeys = leadingRow.children
        .whereType<IconButton>()
        .map((b) => b.key)
        .toSet();
    expect(leadingKeys, contains(const Key('reader_open_bookshelf')));
    expect(leadingKeys, contains(const Key('reader_font_decrease')));
    expect(leadingKeys, contains(const Key('reader_font_increase')));
    // leadingWidth 放宽到容纳 4 按钮。
    expect(appBar.leadingWidth, greaterThanOrEqualTo(160));
    // 时钟仍在 title。
    expect(find.byType(ReaderClock), findsOneWidget);
  });
}

void nil() {}
