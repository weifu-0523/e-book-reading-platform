import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/app.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/features/library/providers/library_controller.dart';

import 'fakes/fake_book_repository.dart';
import 'fakes/fake_book_tags_lookup.dart';
import 'fakes/fake_settings_repository.dart';

/// 启动冒烟测试：验证 ZhiYueApp 能成功构建并显示 LibraryPage 的 AppBar 标题。
///
/// M0+M1 阶段此处检查 HomePage 的占位文本；M3.1 后 '/' 路由切到 LibraryPage，
/// 该页通过 LibraryController 监听 drift，测试需 override 相关 provider 为 fake
/// 以避免 teardown 时 drift 残留 zero-delay timer。
void main() {
  testWidgets('App boots and shows LibraryPage', (tester) async {
    final bookRepo = FakeBookRepository();
    final tagsLookup = FakeBookTagsLookup();
    final settings = FakeSettingsRepository();
    await tester.pumpWidget(
      ProviderScope(
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
      ),
    );
    await tester.pumpAndSettle();

    // LibraryPage 的 AppBar 标题
    expect(find.text('智阅'), findsOneWidget);
    // 空库时显示空态文案
    expect(find.text('书库为空'), findsOneWidget);
  });
}
