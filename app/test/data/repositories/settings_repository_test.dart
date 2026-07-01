import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart' as db;
import 'package:zhiyue/data/repositories/local_settings_repository.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  late db.AppDatabase database;
  late LocalSettingsRepository repo;

  setUp(() {
    database = createTestDatabase();
    repo = LocalSettingsRepository(database);
  });

  tearDown(() async => database.close());

  test('get returns default for missing key', () async {
    expect(await repo.get<String>('missing', 'fallback'), 'fallback');
  });

  test('set then get', () async {
    await repo.set<int>('fontSize', 18);
    expect(await repo.get<int>('fontSize', 0), 18);
  });

  test('set then get bool', () async {
    await repo.set<bool>('isDark', true);
    expect(await repo.get<bool>('isDark', false), isTrue);
  });

  test('set then get double', () async {
    await repo.set<double>('lineHeight', 1.6);
    expect(await repo.get<double>('lineHeight', 1.5), 1.6);
  });

  // I6: 泛型擦除导致 `decoded is T`（T=List<String>/Map<String,dynamic>）返回 false
  // （jsonDecode 实际返回 List<dynamic>/Map<String,dynamic>），落到 throw StateError。
  // 这是常用场景（recent_books、theme_overrides 等），必须支持。
  test('set<List<String>> and get<List<String>> round-trips', () async {
    await repo.set<List<String>>('recent_books', ['b1', 'b2', 'b3']);
    final result = await repo.get<List<String>>('recent_books', const <String>[]);
    expect(result, ['b1', 'b2', 'b3']);
  });

  test('set<Map<String, dynamic>> and get<Map<String, dynamic>> round-trips', () async {
    await repo.set<Map<String, dynamic>>('theme_overrides', {'dark': true, 'primary': '#000'});
    final result = await repo.get<Map<String, dynamic>>('theme_overrides', const <String, dynamic>{});
    expect(result, {'dark': true, 'primary': '#000'});
  });

  // M2.2/T5: getOrNull 用于区分 "key 未设置" 与 "显式设置为默认值"
  // （首发启动种子化 chapter_end_prompt_enabled 等场景必需）。
  test('getOrNull returns null when key not set', () async {
    final v = await repo.getOrNull<bool>('missing_key');
    expect(v, isNull);
  });

  test('getOrNull returns value when key set', () async {
    await repo.set<bool>('k', true);
    final v = await repo.getOrNull<bool>('k');
    expect(v, isTrue);
  });

  test('getOrNull distinguishes unset from explicit false', () async {
    // unset → null
    expect(await repo.getOrNull<bool>('unset'), isNull);
    // set to false explicitly → false (not null)
    await repo.set<bool>('explicit', false);
    expect(await repo.getOrNull<bool>('explicit'), isFalse);
  });
}
