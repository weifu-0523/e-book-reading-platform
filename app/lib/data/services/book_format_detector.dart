import 'dart:io';

import 'package:zhiyue/data/models/book.dart';

/// 通过文件 magic bytes 检测 [BookFormat]。
///
/// 当前规则：
/// - `%PDF-`（5 字节前缀）→ [BookFormat.pdf]
/// - `PK\x03\x04` ZIP 头 + `.epub` 扩展名 → [BookFormat.epub]
/// - 文件小于 5 字节或未知特征 → `null`
///
/// 注意：EPUB 本质是 ZIP，但其他 ZIP 派生格式（如 .docx/.jar）也可能拥有
/// 相同前缀；为避免误判，EPUB 判定在 ZIP 基础上要求扩展名为 `.epub`。
/// PDF 的 `%PDF-` 前缀足够独特，扩展名不参与判定。
class BookFormatDetector {
  const BookFormatDetector._();

  /// 检测 [path] 指向文件的格式；无法识别时返回 `null`。
  static BookFormat? detect(String path) {
    final bytes = File(path).readAsBytesSync();
    if (bytes.length < 5) return null;

    // PDF magic: %PDF-
    if (bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D) {
      return BookFormat.pdf;
    }

    // EPUB: ZIP header (PK..) + .epub extension.
    // ZIP 家族格式众多，仅靠 magic bytes 不足以下定论，扩展名做二次约束。
    if (bytes[0] == 0x50 && bytes[1] == 0x4B) {
      final pathLower = path.toLowerCase();
      if (pathLower.endsWith('.epub')) return BookFormat.epub;
    }

    return null;
  }
}
