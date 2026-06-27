import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../data/models/user_font.dart';
import '../../../data/repositories/user_font_repository.dart';

import '../models/font_import_result.dart';

/// 用户字体导入服务。
///
/// 流程：
/// 1. 弹出 FilePicker（限定 .ttf/.otf），用户取消返回 [FontImportCancelled]
/// 2. 读取源文件字节、计算 SHA-1；命中已有条目则返回 [FontImportAlreadyExists]
/// 3. 复制字节到 [fontsDir] 下 {stamp}_{safeName} 文件
/// 4. 用 [FontLoader] 加载副本字节验证有效性；失败回滚删除文件并返回 [FontImportInvalid]
/// 5. 写入 user_fonts 表，返回 [FontImportSuccess]
///
/// FontLoader 的 `addFont` 接受 `Future<ByteData>` —— 没有 FontAsset 类
/// （flutter SDK 没有该符号），我们直接把文件 bytes 转 ByteData 注入。
class FontImportService {
  FontImportService(this._repo, this._fontsDir);

  final UserFontRepository _repo;
  final Directory _fontsDir;

  Future<FontImportResult> importFont() async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ttf', 'otf'],
    );
    if (pick == null || pick.files.isEmpty) return const FontImportCancelled();

    final pickedPath = pick.files.single.path;
    if (pickedPath == null) {
      return const FontImportReadError('picked file path is null');
    }

    final List<int> bytes;
    try {
      bytes = await File(pickedPath).readAsBytes();
    } catch (e) {
      return FontImportReadError('readAsBytes failed: $e');
    }

    final hash = sha1.convert(bytes).toString();
    final existing = await _repo.findByHash(hash);
    if (existing != null) return FontImportAlreadyExists(existing);

    final originalName = pick.files.single.name;
    final safeName = _sanitize(originalName);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final destPath = p.join(_fontsDir.path, '${stamp}_$safeName');
    final destFile = File(destPath);
    await destFile.writeAsBytes(bytes);

    final familyName = p.basenameWithoutExtension(destPath);
    final loader = FontLoader(familyName)
      ..addFont(_bytesToByteDataFuture(destFile));
    try {
      await loader.load();
    } catch (e) {
      // FontLoader 抛错（无效 TTF/OTF）→ 删除已写的副本，避免脏文件残留
      if (await destFile.exists()) await destFile.delete();
      return FontImportInvalid('FontLoader.load failed: $e');
    }

    final font = UserFont(
      id: const Uuid().v4(),
      displayName: familyName,
      fileName: p.basename(destPath),
      familyName: familyName,
      hashSha1: hash,
      absolutePath: destPath,
      addedAt: DateTime.now(),
    );
    await _repo.insert(font);
    return FontImportSuccess(font);
  }

  /// 读文件字节并转 [ByteData]，作为 FontLoader.addFont 的入参。
  /// Future 延迟求值——只有 FontLoader.load 时才会真正读取。
  Future<ByteData> _bytesToByteDataFuture(File file) async {
    final bytes = await file.readAsBytes();
    return ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
  }

  /// 把文件名中的非 [\w.\-] 字符替换为 `_`，避免 Windows 路径里出现非法字符。
  /// 空字符串兜底为 `font.ttf`。
  String _sanitize(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^\w.\-]'), '_');
    return cleaned.isEmpty ? 'font.ttf' : cleaned;
  }
}
