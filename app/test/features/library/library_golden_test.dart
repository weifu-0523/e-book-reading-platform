import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/library/pages/library_page.dart';
import 'package:zhiyue/features/library/providers/library_controller.dart';

import '../../fakes/fake_book_repository.dart';
import '../../fakes/fake_book_tags_lookup.dart';
import '../../fakes/fake_settings_repository.dart';

/// M3.1 Library goldens：5 个场景，每个独立 ProviderScope + fake。
/// 通过 `flutter test --update-goldens` 生成基线。
void main() {
  List<Book> sampleBooks() => [
        Book(
          id: 'b1',
          title: '三体',
          author: '刘慈欣',
          format: BookFormat.epub,
          filePath: '/tmp/three_body.epub',
          fileHash: 'h1',
          fileSizeBytes: 1024,
          coverPath: null,
          addedAt: DateTime(2026, 6, 26),
          lastReadAt: null,
        ),
        Book(
          id: 'b2',
          title: '活着',
          author: '余华',
          format: BookFormat.epub,
          filePath: '/tmp/alive.epub',
          fileHash: 'h2',
          fileSizeBytes: 2048,
          coverPath: null,
          addedAt: DateTime(2026, 6, 25),
          lastReadAt: null,
        ),
        Book(
          id: 'b3',
          title: '人类简史',
          author: '尤瓦尔·赫拉利',
          format: BookFormat.pdf,
          filePath: '/tmp/sapiens.pdf',
          fileHash: 'h3',
          fileSizeBytes: 4096,
          coverPath: null,
          addedAt: DateTime(2026, 6, 24),
          lastReadAt: null,
        ),
        Book(
          id: 'b4',
          title: '深度工作',
          author: '卡尔·纽波特',
          format: BookFormat.epub,
          filePath: '/tmp/deep_work.epub',
          fileHash: 'h4',
          fileSizeBytes: 8192,
          coverPath: null,
          addedAt: DateTime(2026, 6, 23),
          lastReadAt: null,
        ),
      ];

  /// 构造一个独立 ProviderScope，注入指定 fake。
  /// list 视图通过预写 settings 让 controller hydrate 为 list。
  Widget wrappedLibrary({
    required FakeBookRepository bookRepo,
    required FakeSettingsRepository settings,
  }) {
    return ProviderScope(
      overrides: [
        bookRepositoryProvider.overrideWith((ref) => bookRepo),
        settingsRepositoryProvider.overrideWith((ref) => settings),
        libraryControllerProvider.overrideWith((ref) => LibraryController(
              bookRepository: bookRepo,
              bookTagsLookup: FakeBookTagsLookup(),
              settingsRepository: settings,
            )),
      ],
      child: const MaterialApp(home: LibraryPage()),
    );
  }

  testGoldens('library_empty', (tester) async {
    final bookRepo = FakeBookRepository();
    final settings = FakeSettingsRepository();
    await tester.pumpWidget(
      SizedBox(
        height: 600,
        child: wrappedLibrary(bookRepo: bookRepo, settings: settings),
      ),
    );
    await tester.pumpAndSettle();
    await screenMatchesGolden(tester, 'library_empty');
  });

  testGoldens('library_loaded_grid', (tester) async {
    final bookRepo = FakeBookRepository()..emitBooks(sampleBooks());
    final settings = FakeSettingsRepository();
    await tester.pumpWidget(
      SizedBox(
        height: 600,
        child: wrappedLibrary(bookRepo: bookRepo, settings: settings),
      ),
    );
    await tester.pumpAndSettle();
    await screenMatchesGolden(tester, 'library_loaded_grid');
  });

  testGoldens('library_loaded_list', (tester) async {
    final bookRepo = FakeBookRepository()..emitBooks(sampleBooks());
    final settings = FakeSettingsRepository();
    // 预设 viewMode=list，controller 启动时 hydrate 读到 'list'
    await settings.set<String>('library.viewMode', 'list');
    await tester.pumpWidget(
      SizedBox(
        height: 600,
        child: wrappedLibrary(bookRepo: bookRepo, settings: settings),
      ),
    );
    await tester.pumpAndSettle();
    await screenMatchesGolden(tester, 'library_loaded_list');
  });

  testGoldens('library_selecting', (tester) async {
    final bookRepo = FakeBookRepository()..emitBooks(sampleBooks());
    final settings = FakeSettingsRepository();
    await tester.pumpWidget(
      SizedBox(
        height: 600,
        child: wrappedLibrary(bookRepo: bookRepo, settings: settings),
      ),
    );
    await tester.pumpAndSettle();

    // 长按第一本书进入选择模式
    await tester.longPress(find.text('三体'));
    await tester.pumpAndSettle();

    await screenMatchesGolden(tester, 'library_selecting');
  });

  testGoldens('library_searching', (tester) async {
    final bookRepo = FakeBookRepository()..emitBooks(sampleBooks());
    final settings = FakeSettingsRepository();
    await tester.pumpWidget(
      SizedBox(
        height: 600,
        child: wrappedLibrary(bookRepo: bookRepo, settings: settings),
      ),
    );
    await tester.pumpAndSettle();

    // 点击搜索图标进入搜索态，键入一些文字
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '三体');
    await tester.pumpAndSettle();
    // 等 debounce 写入 state 并让 watchAll 重订阅后的 stream emit 流回 UI
    // （用 pumpAndSettle 而非 pump，确保流订阅/状态变更都 reconcile 完）
    await tester.pumpAndSettle(const Duration(milliseconds: 250));

    await screenMatchesGolden(tester, 'library_searching');
  });
}
