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

  test('Too-small file returns null', () {
    final f = writeBytes('tiny.pdf', [0x25]);
    expect(BookFormatDetector.detect(f.path), isNull);
  });

  test('PDF magic but wrong extension still detected as PDF', () {
    final f = writeBytes(
        'a.bin', [0x25, 0x50, 0x44, 0x46, 0x2D, ...List.filled(100, 0)]);
    expect(BookFormatDetector.detect(f.path), BookFormat.pdf);
  });
}
