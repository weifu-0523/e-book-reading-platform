import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/services/book_format_detector.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('book_format_detector_test');
  });
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File writeBytes(String name, List<int> bytes) {
    return File(p.join(tempDir.path, name))..writeAsBytesSync(bytes);
  }

  test('PDF magic bytes detected', () {
    final f = writeBytes(
        'a.pdf', [0x25, 0x50, 0x44, 0x46, 0x2D, ...List.filled(100, 0)]);
    expect(BookFormatDetector.detect(f.path), BookFormat.pdf);
  });

  test('EPUB by extension fallback (PK zip)', () {
    final f = writeBytes(
        'a.epub', [0x50, 0x4B, 0x03, 0x04, ...List.filled(100, 0)]);
    expect(BookFormatDetector.detect(f.path), BookFormat.epub);
  });

  test('Unknown format returns null', () {
    final f = writeBytes('a.unknown', [0x00, 0x01, 0x02, ...List.filled(100, 0)]);
    expect(BookFormatDetector.detect(f.path), isNull);
  });

  test('Too-small PDF (magic incomplete) returns null', () {
    // M4.5: < 5 guard 改成 isEmpty。1 字节 0x25 不够 PDF magic，扩展名 .pdf
    // 又不匹配 md/txt → null（语义从"太小"变成"magic 不足且非文本扩展名"）。
    final f = writeBytes('tiny.pdf', [0x25]);
    expect(BookFormatDetector.detect(f.path), isNull);
  });

  test('PDF magic but wrong extension still detected as PDF', () {
    final f = writeBytes(
        'a.bin', [0x25, 0x50, 0x44, 0x46, 0x2D, ...List.filled(100, 0)]);
    expect(BookFormatDetector.detect(f.path), BookFormat.pdf);
  });

  // ---- M4.5: Markdown / TXT 扩展名检测 ----

  test('M4.5: .md extension detected as markdown', () {
    final f = writeBytes('notes.md', utf8.encode('# Title\n\nbody'));
    expect(BookFormatDetector.detect(f.path), BookFormat.markdown);
  });

  test('M4.5: .markdown extension detected as markdown', () {
    final f = writeBytes('book.markdown', utf8.encode('content'));
    expect(BookFormatDetector.detect(f.path), BookFormat.markdown);
  });

  test('M4.5: .txt extension detected as text', () {
    final f = writeBytes('novel.txt', utf8.encode('第一章'));
    expect(BookFormatDetector.detect(f.path), BookFormat.text);
  });

  test('M4.5: extension detection is case-insensitive', () {
    final f = writeBytes('NOTES.MD', utf8.encode('body'));
    expect(BookFormatDetector.detect(f.path), BookFormat.markdown);
  });

  test('M4.5: empty .txt file detected as text (not null)', () {
    // M4.5: 空文件 isEmpty 返回 null，但 1 字节 .txt 仍按扩展名判 text。
    final f = writeBytes('empty.txt', [0x20]);
    expect(BookFormatDetector.detect(f.path), BookFormat.text);
  });

  test('M4.5: truly empty file (0 bytes) returns null regardless of ext', () {
    final f = writeBytes('blank.txt', <int>[]);
    expect(BookFormatDetector.detect(f.path), isNull);
  });
}
