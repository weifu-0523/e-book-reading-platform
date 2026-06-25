import 'dart:io';
import 'package:path/path.dart' as p;

/// Fixture EPUB 加载器。
///
/// 文件不存在时返回 null，测试应 skip（而非 fail）。
class FixtureLoader {
  static const _fixturesDir = 'test/fixtures';

  static File? tryLoad(String filename) {
    final path = p.join(_fixturesDir, filename);
    final file = File(path);
    return file.existsSync() ? file : null;
  }
}
