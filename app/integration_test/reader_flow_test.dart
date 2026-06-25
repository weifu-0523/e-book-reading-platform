import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zhiyue/core/app.dart';
import 'package:zhiyue/data/local/database.dart';
import 'package:zhiyue/data/local/daos/books_dao.dart';
import 'package:zhiyue/data/local/file_storage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Reader flow end-to-end', () {
    testWidgets('open book → state becomes ready', (tester) async {
      // 准备一本真实书到 FileStorage
      // ignore: unused_local_variable
      final storage = await FileStorage.create();
      final db = AppDatabase();

      addTearDown(db.close);

      await BooksDao(db).insertOne(
        id: 'b1',
        title: '测试书',
        format: 'epub',
        filePath: '/library/test.epub',
        fileHash: 'h',
        fileSizeBytes: 0,
      );

      await tester.pumpWidget(
        const ProviderScope(child: ZhiYueApp()),
      );
      await tester.pumpAndSettle();

      // 导航到 /book/b1
      // 注：完整测试需要 Navigator.pushNamed('/book/b1')
      // 此处简化，仅验证 app 启动
      expect(find.byType(MaterialApp), findsOneWidget);
    },
        // 需要 fixture EPUB + 真实路径注入；CI 上跑
        skip: true,
        timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('CFI restoration: reopen book returns to last position',
        (tester) async {
      // 1. 打开书，跳到某 CFI
      // 2. 关闭
      // 3. 重新打开
      // 4. 验证 engine 从 LocalReadingProgressRepository 取的 CFI 一致
      //    容差 < 100 字符（spec §9.4）
    },
        // 依赖 fixture + 真实 reader widget；M2 W5 末尾补完
        skip: true,
        timeout: const Timeout(Duration(seconds: 60)));
  });
}
