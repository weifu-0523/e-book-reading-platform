import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// 启动时一次性加载所有 user_fonts 到 FontLoader，让字体在渲染前可用。
///
/// 调用方 await 这个 provider 的 future 后再渲染 reader。
/// Flutter SDK 的 [FontLoader.addFont] 接受 `Future<ByteData>`，因此
/// 这里把每个字体文件读成 bytes → ByteData 后注入。
final fontBootstrapProvider = FutureProvider<void>((ref) async {
  final repo = ref.watch(userFontRepositoryProvider);
  final fonts = await repo.getAll();
  for (final f in fonts) {
    final file = File(f.absolutePath);
    if (!await file.exists()) continue;
    final loader = FontLoader(f.familyName)
      ..addFont(_readAsByteData(file));
    await loader.load();
  }
});

Future<ByteData> _readAsByteData(File file) async {
  final bytes = await file.readAsBytes();
  return ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
}
