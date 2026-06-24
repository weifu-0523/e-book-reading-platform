import 'package:zhiyue/data/local/database.dart';

/// 测试用：内存数据库 + 空表。
AppDatabase createTestDatabase() {
  return AppDatabase.forTesting();
}
