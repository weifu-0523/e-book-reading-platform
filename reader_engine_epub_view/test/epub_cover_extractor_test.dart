import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:reader_engine_epub_view/epub_cover_extractor.dart';

void main() {
  late Directory tempDir;
  late EpubCoverExtractor extractor;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('epub_cover_test_');
    extractor = EpubCoverExtractor(coversDir: tempDir);
  });
  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('extract returns PNG path on valid EPUB with cover', () async {
    final fixture = File(p.join('..', 'app', 'test', 'fixtures', 'page-blanche.epub'));
    if (!fixture.existsSync()) {
      // CI / 工作目录差异时的 fallback
      fail('Fixture not found at ${fixture.path}; cwd=${Directory.current.path}');
    }
    final bytes = await fixture.readAsBytes();
    final path = await extractor.extract(bookId: 'b1', epubBytes: bytes);
    expect(path, isNotNull);
    expect(File(path!).existsSync(), isTrue);
    // 应该写入 PNG 文件
    expect(p.extension(path), '.png');
  });

  test('extract returns null on empty bytes', () async {
    final path = await extractor.extract(bookId: 'b2', epubBytes: Uint8List(0));
    expect(path, isNull);
  });

  test('extract returns null on corrupted bytes without throwing', () async {
    final path = await extractor.extract(
      bookId: 'b3',
      epubBytes: Uint8List.fromList([1, 2, 3, 4, 5]),
    );
    expect(path, isNull);
  });
}
