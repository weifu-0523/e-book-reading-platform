import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart' show userFontRepositoryProvider;
import '../../../data/models/user_font.dart';

/// 用户已导入字体的只读列表（autoDispose，每次进入字体管理页重新查 DB）。
final fontLibraryProvider =
    FutureProvider.autoDispose<List<UserFont>>((ref) async {
  final repo = ref.watch(userFontRepositoryProvider);
  return repo.getAll();
});
