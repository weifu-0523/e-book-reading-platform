// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

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
