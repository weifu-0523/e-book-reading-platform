import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 生产环境数据库连接：写入应用文档目录下的 app.db。
LazyDatabase createDatabaseConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.db'));
    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        // 启用外键约束
        rawDb.execute('PRAGMA foreign_keys = ON;');
      },
    );
  });
}
