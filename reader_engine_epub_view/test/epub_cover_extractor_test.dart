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

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
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

  test('extract returns null when EPUB has no cover image', () async {
    final fixture = File(p.join(tempDir.path, 'no-cover.epub'));
    await _writeNoCoverEpub(fixture);
    final bytes = await fixture.readAsBytes();
    final path = await extractor.extract(bookId: 'b4', epubBytes: bytes);
    expect(path, isNull);
  });
}

/// 构造一个最小合法但无封面图的 EPUB 文件用于测试。
/// 结构：mimetype + META-INF/container.xml + OEBPS/content.opf + OEBPS/toc.ncx
/// + 1 章 HTML。必须包含 NCX（epubx 要求 spine toc 引用有效项）。
Future<void> _writeNoCoverEpub(File target) async {
  final archive = Archive();
  // mimetype 必须为第一项且不压缩
  final mimetypeData = utf8.encode('application/epub+zip');
  final mimetypeFile = ArchiveFile('mimetype', mimetypeData.length, mimetypeData);
  mimetypeFile.compress = false;
  archive.addFile(mimetypeFile);
  // 其余文件用 deflate
  final containerBytes = utf8.encode(_containerXml);
  final opfBytes = utf8.encode(_noCoverOpf);
  final htmlBytes = utf8.encode(_minimalHtml);
  final ncxBytes = utf8.encode(_tocNcx);
  archive.addFile(ArchiveFile('META-INF/container.xml', containerBytes.length, containerBytes));
  archive.addFile(ArchiveFile('OEBPS/content.opf', opfBytes.length, opfBytes));
  archive.addFile(ArchiveFile('OEBPS/content.xhtml', htmlBytes.length, htmlBytes));
  archive.addFile(ArchiveFile('OEBPS/toc.ncx', ncxBytes.length, ncxBytes));
  final encoder = ZipEncoder();
  final bytes = encoder.encode(archive, level: Deflate.BEST_SPEED);
  await target.writeAsBytes(bytes!);
}

const _containerXml = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';

const _noCoverOpf = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>No Cover Test</dc:title>
    <dc:identifier id="BookId">test-no-cover</dc:identifier>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="content" href="content.xhtml" media-type="application/xhtml+xml"/>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="content"/>
  </spine>
</package>''';

const _tocNcx = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN" "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="test-no-cover"/>
  </head>
  <docTitle><text>No Cover Test</text></docTitle>
  <navMap>
    <navPoint id="navpoint-1" playOrder="1">
      <navLabel><text>Chapter 1</text></navLabel>
      <content src="content.xhtml"/>
    </navPoint>
  </navMap>
</ncx>''';

const _minimalHtml = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Test</title></head>
<body><p>Empty</p></body>
</html>''';
