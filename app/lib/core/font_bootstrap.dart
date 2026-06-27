import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user_font.dart';
import 'providers.dart';

/// 启动时一次性加载所有 user_fonts 到 FontLoader，让字体在渲染前可用。
/// 调用方 await 这个 provider 的 future 后再渲染 reader。
///
/// 单个字体加载失败（文件损坏、磁盘错误等）不会中断整个 bootstrap——
/// 跳过坏字体继续加载其余，避免一个坏文件让 reader 整页崩溃。
final fontBootstrapProvider = FutureProvider<void>((ref) async {
  final repo = ref.watch(userFontRepositoryProvider);
  final fonts = await repo.getAll();
  for (final f in fonts) {
    await _loadOne(f);
  }
});

Future<void> _loadOne(UserFont f) async {
  final file = File(f.absolutePath);
  if (!await file.exists()) return;
  try {
    final loader = FontLoader(f.familyName)..addFont(_readAsByteData(file));
    await loader.load();
  } catch (e) {
    debugPrint('font_bootstrap: skipping unloadable font ${f.familyName}: $e');
  }
}

Future<ByteData> _readAsByteData(File file) async {
  final bytes = await file.readAsBytes();
  return ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
}
