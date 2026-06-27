import '../../../data/models/user_font.dart';

/// [FontImportService.importFont] 的返回结果。
///
/// 5 个互斥分支对应不同用户路径：
/// - [FontImportCancelled]：用户在系统选择器点取消
/// - [FontImportAlreadyExists]：内容哈希已存在，返回旧条目（不重复导入）
/// - [FontImportInvalid]：FontLoader.load 失败，文件不是合法 TTF/OTF
/// - [FontImportReadError]：源文件读取出错（路径为空 / I/O 异常）
/// - [FontImportSuccess]：导入成功，返回新建的 [UserFont]
sealed class FontImportResult {
  const FontImportResult();
}

class FontImportCancelled extends FontImportResult {
  const FontImportCancelled();
}

class FontImportAlreadyExists extends FontImportResult {
  final UserFont existing;
  const FontImportAlreadyExists(this.existing);
}

class FontImportInvalid extends FontImportResult {
  final String reason;
  const FontImportInvalid(this.reason);
}

class FontImportReadError extends FontImportResult {
  final String message;
  const FontImportReadError(this.message);
}

class FontImportSuccess extends FontImportResult {
  final UserFont font;
  const FontImportSuccess(this.font);
}
