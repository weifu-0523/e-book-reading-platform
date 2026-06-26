import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reader_engine/core/book_ref.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:zhiyue/core/router.dart';
import 'package:zhiyue/features/reader/pages/reader_page.dart';
import 'package:zhiyue/features/reader/providers/reader_engine_provider.dart';

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
  ReaderEngineState get state => const ReaderEngineReady();

  @override
  Stream<ReaderEngineState> get state$ => _stateController.stream;

  // ---- 以下为本测试不需要的实现 ----
  @override
  PaginationMode get paginationMode => PaginationMode.paged;

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
  Future<void> setPaginationMode(PaginationMode mode) async {}

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
  testWidgets('router initial location / renders HomePage', (tester) async {
    final router = createAppRouter();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // HomePage AppBar 标题
    expect(find.text('智阅'), findsOneWidget);
  });

  testWidgets('router /book/:id navigates to ReaderPage', (tester) async {
    final router = createAppRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readerEngineForBookProvider.overrideWith(
            (ref, arg) async => _FakeReaderEngine(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('智阅'), findsOneWidget);

    // 跳转到 reader
    router.go('/book/test-id');
    await tester.pumpAndSettle();

    // ReaderPage 出现
    expect(find.byType(ReaderPage), findsOneWidget);
    // 不应再显示 HomePage 的标识
    expect(find.text('M0 + M1 数据层脚手架'), findsNothing);
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
