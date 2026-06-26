import 'dart:io';
import 'dart:typed_data';

import 'package:epubx/epubx.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// 从 EPUB 字节流提取封面图片，重编码为 PNG 后写入 [coversDir]。
///
/// 失败（空字节 / 解析异常 / 无封面）返回 null，调用方降级到占位图。
class EpubCoverExtractor {
  final Directory coversDir;

  EpubCoverExtractor({required this.coversDir});

  /// 解析 [epubBytes]，提取封面图，重编码为 PNG 写入 [coversDir]/[bookId].png。
  ///
  /// 返回写入文件的绝对路径；任何步骤失败均返回 null（不抛异常）。
  Future<String?> extract({
    required String bookId,
    required Uint8List epubBytes,
  }) async {
    if (epubBytes.isEmpty) return null;
    try {
      final book = await EpubReader.readBook(epubBytes);
      final coverImage = book.CoverImage;
      if (coverImage == null) return null;
      final pngBytes = img.encodePng(coverImage);
      final file = File(p.join(coversDir.path, '$bookId.png'));
      await file.writeAsBytes(pngBytes);
      return file.path;
    } catch (e, st) {
      // 保留 null 返回以让调用方降级，但记录诊断信息以便排查
      debugPrint('EpubCoverExtractor.extract failed for $bookId: $e\n$st');
      return null;
    }
  }
}
