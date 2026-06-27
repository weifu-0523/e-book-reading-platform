import 'package:drift/drift.dart';

/// schema v5：用户自定义字体。
///
/// 存储通过 FontImportService 导入的 .ttf/.otf 字体的元数据。字体文件本身
/// 复制到 FileStorage.fontsDir 下，本表只记录指向该副本的 absolutePath。
///
/// SHA-1 用作去重键：同一字体重复导入返回已有的 [UserFont]，
/// 不再复制文件、不再写入新行。
class UserFonts extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get fileName => text()();
  TextColumn get familyName => text()();
  TextColumn get hashSha1 => text()();
  TextColumn get absolutePath => text()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
