import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/sync/providers/sync_controller.dart';
import '../services/sync/sync_credentials.dart';
import 'providers.dart';

/// 全局 ProviderScope override 列表。
///
/// M2.0a：注入 [SyncController]（依赖 [appDatabaseProvider] + [SyncCredentials]）。
/// Riverpod 会延迟求值，所以 SyncController 真正实例化时 AppDatabase 已就绪。
final providers = <Override>[
  syncControllerProvider.overrideWith(
    (ref) => SyncController(
      database: ref.watch(appDatabaseProvider),
      credentials: SyncCredentials(),
    ),
  ),
];
