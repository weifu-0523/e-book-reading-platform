import 'package:meta/meta.dart';

/// 用户导入的字体的不可变模型。
///
/// 与 [UserFonts] drift 表行一一对应，但脱离 drift runtime 暴露给上层使用。
/// 不包含 [addedAt] 之外的数据库默认值，所有字段构造时显式传入。
@immutable
class UserFont {
  final String id;
  final String displayName;
  final String fileName;
  final String familyName;
  final String hashSha1;
  final String absolutePath;
  final DateTime addedAt;

  const UserFont({
    required this.id,
    required this.displayName,
    required this.fileName,
    required this.familyName,
    required this.hashSha1,
    required this.absolutePath,
    required this.addedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserFont &&
          id == other.id &&
          displayName == other.displayName &&
          fileName == other.fileName &&
          familyName == other.familyName &&
          hashSha1 == other.hashSha1 &&
          absolutePath == other.absolutePath;

  @override
  int get hashCode =>
      Object.hash(id, displayName, fileName, familyName, hashSha1, absolutePath);
}
