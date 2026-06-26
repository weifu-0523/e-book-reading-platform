import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/app.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/library/providers/library_controller.dart';

import '../../fakes/fake_book_repository.dart';
import '../../fakes/fake_book_tags_lookup.dart';
import '../../fakes/fake_settings_repository.dart';

/// M3.1 端到端集成测试：通过完整 [ZhiYueApp] + 路由启动，覆盖 LibraryPage
/// 的核心用户流。Provider 全部 override 为 fake，避免触碰真实 drift/文件系统。
///
/// 覆盖场景：
/// 1. 空库：显示「书库为空」空态
/// 2. 加载：emit 几本书后，书名出现在网格中
/// 3. 搜索：点击搜索图标 → 输入关键字 → 搜索框回显
///    （注：当前 [LibraryController] 只把 searchQuery 存到 state，未对 books
///    做过滤；真实过滤需在仓库层 watchAll(searchQuery:) 完成，T19.5 仅做了
///    搜索 UI 接入。此处只断言可观察的搜索 UI 行为，不断言过滤结果。）
/// 4. 跳转阅读器：跳过 — 真实 ReaderEngine 需要 epub 文件 fixture，widget
///    测试无法满足，会在集成测试环境抛文件不存在异常。
/// 5. 选择模式：长按书卡 → 底部 BatchSelectionBar 显示「已选 N 本」
/// 6. 视图切换：点击视图切换图标 → AppBar 图标在 grid_view / view_list 间切换
void main() {
  late FakeBookRepository bookRepo;
  late FakeBookTagsLookup tagsLookup;
  late FakeSettingsRepository settings;

  setUp(() {
    bookRepo = FakeBookRepository();
    tagsLookup = FakeBookTagsLookup();
    settings = FakeSettingsRepository();
  });

  Widget buildApp() {
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
      child: const ZhiYueApp(),
    );
  }

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
      ];

  testWidgets('empty state: shows 书库为空 on boot', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('智阅'), findsOneWidget);
    expect(find.text('书库为空'), findsOneWidget);
    expect(find.text('导入第一本书'), findsOneWidget);
  });

  testWidgets('loaded state: book titles render after emitBooks', (tester) async {
    bookRepo.emitBooks(sampleBooks());
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('三体'), findsOneWidget);
    expect(find.text('活着'), findsOneWidget);
    expect(find.text('人类简史'), findsOneWidget);
    // 作者作为副标题也应渲染
    expect(find.text('刘慈欣'), findsOneWidget);
  });

  testWidgets(
      'search: tapping search icon reveals text field and accepts input',
      (tester) async {
    bookRepo.emitBooks(sampleBooks());
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // 初始：AppBar 标题「智阅」，无 TextField
    expect(find.text('智阅'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    // 点击搜索图标进入搜索态
    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();

    // 标题被 TextField 替换
    expect(find.text('智阅'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);

    // 输入查询关键字，回显在 TextField 的 EditableText 中
    await tester.enterText(find.byType(TextField), '三体');
    await tester.pumpAndSettle();
    // 搜索框内的 EditableText 持有输入文本（书卡中的同名 Text 仍存在，
    // 因为当前实现不做过滤；这里只断言输入文本成功落进搜索框）
    expect(find.byType(EditableText), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '三体',
    );

    // 等待 debounce 结束，让 controller 把 query 写入 state
    await tester.pump(const Duration(milliseconds: 250));

    // 退出搜索：点击返回箭头，恢复 AppBar 标题
    await tester.tap(find.byTooltip('退出搜索'));
    await tester.pumpAndSettle();
    expect(find.text('智阅'), findsOneWidget);

    // 注：当前实现下 books 不会按 searchQuery 过滤（仓库层未接线）。
    // 真正的「过滤结果」断言留给仓库层 watchAll(searchQuery:) 完成后补回。
  });

  // 跳转阅读器场景：跳过。
  // 真实 ReaderEngine 在加载时需要磁盘上的 epub 文件，且会启动 Isolate /
  // 平台通道，在 widget 测试环境无法满足；如需端到端覆盖请使用
  // integration_test_driver，配合真实 fixture 文件。
  testWidgets('selection mode: long press shows 已选 N 本 in batch bar',
      (tester) async {
    bookRepo.emitBooks(sampleBooks());
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // 进入选择模式前：没有 BatchSelectionBar
    expect(find.textContaining('已选'), findsNothing);

    await tester.longPress(find.text('三体'));
    await tester.pumpAndSettle();

    // 进入选择模式：底部条出现，初始选中 1 本
    expect(find.text('已选 1 本'), findsOneWidget);
    expect(find.byTooltip('全选'), findsOneWidget);
    expect(find.byTooltip('删除'), findsOneWidget);
  });

  testWidgets('view mode toggle: grid -> list flips the appbar icon',
      (tester) async {
    bookRepo.emitBooks(sampleBooks());
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // 默认 grid：视图切换按钮显示 grid_view（点击切到 list）
    expect(find.byIcon(Icons.grid_view), findsOneWidget);
    expect(find.byIcon(Icons.view_list), findsNothing);

    await tester.tap(find.byTooltip('切换视图'));
    await tester.pumpAndSettle();

    // 切到 list 后：按钮翻成 view_list（点击切回 grid）
    expect(find.byIcon(Icons.view_list), findsOneWidget);
    expect(find.byIcon(Icons.grid_view), findsNothing);

    // 切回 grid
    await tester.tap(find.byTooltip('切换视图'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.grid_view), findsOneWidget);
  });
}
