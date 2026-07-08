import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reader_engine/core/book_ref.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/page_break.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/core/router.dart';
import 'package:zhiyue/features/library/providers/library_controller.dart';
import 'package:zhiyue/features/reader/pages/reader_page.dart';
import 'package:zhiyue/features/reader/providers/reader_engine_provider.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

import '../fakes/fake_book_repository.dart';
import '../fakes/fake_book_tags_lookup.dart';
import '../fakes/fake_settings_repository.dart';

/// 用于测试的假 ReaderEngine —— 无需真实 EPUB 文件，避免 pumpAndSettle 卡住。
class _FakeReaderEngine implements ReaderEngine {
  final StreamController<Locator> _locationController =
      StreamController<Locator>.broadcast();
  final StreamController<ReaderEngineState> _stateController =
      StreamController<ReaderEngineState>.broadcast();

  @override
  TableOfContents? get toc => null;

  @override
  TypographySettings get typography => TypographySettings.defaults();

  @override
  Stream<Locator> get currentLocation$ => _locationController.stream;

  @override
  Future<String> get currentChapterPlainText => Future.value('');

  @override
  List<PageBreak> get currentChapterPageBreaks => const [];

  @override
  PageController? get pageController => null;

  @override
  Future<void> get chapterSwitchSettled => Future<void>.value();

  @override
  ReaderEngineState get state => const ReaderEngineReady();

  @override
  Stream<ReaderEngineState> get state$ => _stateController.stream;

  // ---- 以下为本测试不需要的实现 ----
  @override
  PaginationMode get paginationMode => PaginationMode.paged;

  @override
  bool get dualPageMode => false;

  @override
  int get currentSpreadCount => 0;

  @override
  int get currentSpreadIndex => 0;

  @override
  Future<void> open(BookRef book) async {}

  @override
  Future<void> gotoLocator(Locator locator) async {}

  @override
  Future<void> gotoTocEntry(TocEntry entry) async {}

  @override
  Future<void> nextSpine() async {}

  @override
  Future<void> previousSpine() async {}

  @override
  bool nextPage() => false;

  @override
  bool previousPage() => false;

  @override
  Future<void> setPaginationMode(PaginationMode mode) async {}

  @override
  void scrollBy(double delta, {Duration duration = const Duration(milliseconds: 200)}) {}

  @override
  Future<void> setTypography(TypographySettings settings) async {}

  @override
  Future<void> close() async {
    await _locationController.close();
    await _stateController.close();
  }

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('fake content'));
}

void main() {
  // LibraryPage 现在挂在 '/'；它默认会通过 appDatabaseProvider 启动 drift，
  // 测试 teardown 时 drift 会留下 zero-delay timer 导致 timersPending 断言失败。
  // 这里 override LibraryController 的依赖为 fake，避免触碰真实 drift。
  List<Override> libraryOverrides() {
    final bookRepo = FakeBookRepository();
    final tagsLookup = FakeBookTagsLookup();
    final settings = FakeSettingsRepository();
    return [
      bookRepositoryProvider.overrideWith((ref) => bookRepo),
      settingsRepositoryProvider.overrideWith((ref) => settings),
      libraryControllerProvider.overrideWith((ref) => LibraryController(
            bookRepository: bookRepo,
            bookTagsLookup: tagsLookup,
            settingsRepository: settings,
          )),
    ];
  }

  testWidgets('router initial location / renders LibraryPage', (tester) async {
    final router = createAppRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: libraryOverrides(),
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // LibraryPage AppBar 标题
    expect(find.text('智阅'), findsOneWidget);
  });

  testWidgets('router /book/:id navigates to ReaderPage', (tester) async {
    final router = createAppRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...libraryOverrides(),
          readerEngineForBookProvider.overrideWith(
            (ref, arg) async => _FakeReaderEngine(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('智阅'), findsOneWidget);

    // 跳转到 reader
    router.go('/book/test-id');
    await tester.pumpAndSettle();

    // ReaderPage 出现
    expect(find.byType(ReaderPage), findsOneWidget);
    // 不应再显示 LibraryPage 的标识（AppBar 标题）
    expect(find.text('智阅'), findsNothing);
  });

  test('router has /book/:id route defined', () {
    final router = createAppRouter();
    expect(router.configuration.routes, isNotEmpty);
    // 至少有 / 和 /book/:id
    final pathCounts = router.configuration.routes
        .whereType<GoRoute>()
        .map((r) => r.path)
        .toList();
    expect(pathCounts, contains('/'));
    expect(pathCounts, contains('/book/:id'));
  });
}
