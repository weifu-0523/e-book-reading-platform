import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';

void main() {
  group('EpubCfiLocator', () {
    test('serializes to JSON correctly', () {
      final locator = EpubCfiLocator(
        cfi: 'epubcfi(/6/4[chap01ref]!/4[body01]/10[para05]/3:10)',
        chapterIndex: 0,
        chapterTitle: '第一章',
      );
      expect(locator.toJson(), {
        'type': 'epubCfi',
        'cfi': 'epubcfi(/6/4[chap01ref]!/4[body01]/10[para05]/3:10)',
        'chapterIndex': 0,
        'chapterTitle': '第一章',
      });
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'type': 'epubCfi',
        'cfi': 'epubcfi(/6/4!/4/2)',
        'chapterIndex': 2,
        'chapterTitle': '附录',
      };
      final locator = Locator.fromJson(json) as EpubCfiLocator;
      expect(locator.cfi, 'epubcfi(/6/4!/4/2)');
      expect(locator.chapterIndex, 2);
      expect(locator.chapterTitle, '附录');
    });
  });

  group('PdfPageLocator', () {
    test('serializes to JSON correctly', () {
      final locator = PdfPageLocator(page: 42, offsetX: 100.5, offsetY: 200.0);
      expect(locator.toJson(), {
        'type': 'pdfPage',
        'page': 42,
        'offsetX': 100.5,
        'offsetY': 200.0,
      });
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'type': 'pdfPage',
        'page': 7,
        'offsetX': 0.0,
        'offsetY': 0.0,
      };
      final locator = Locator.fromJson(json) as PdfPageLocator;
      expect(locator.page, 7);
    });
  });

  // M3: 默认分支改抛 FormatException 而非 ArgumentError——
  // 未来 schema 演进（新增 Locator 子类型）后，旧版本读取新数据时此分支会被触发。
  // FormatException 是语义更明确的"数据格式不兼容"信号，便于上层 catch + 日志。
  test('Locator.fromJson throws FormatException on unknown type', () {
    expect(
      () => Locator.fromJson({'type': 'unknown', 'cfi': 'epubcfi(/6)'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('Locator.fromJson FormatException message mentions the unknown type', () {
    try {
      Locator.fromJson({'type': 'futureType', 'foo': 'bar'});
      fail('expected FormatException');
    } on FormatException catch (e) {
      // 消息应包含未知类型字符串，便于日志诊断
      expect(e.message, contains('futureType'));
    }
  });

  test('round-trip serialization preserves data', () {
    final original = EpubCfiLocator(cfi: 'epubcfi(/6)', chapterIndex: 0);
    final restored = Locator.fromJson(original.toJson());
    expect(restored, original);
  });

  // I4: 跨平台/外部 JSON 编码器可能输出 double 形式的整数（如 JS、备份导入），
  // `as int` 强转在此场景下抛 TypeError；应改用 (num).toInt() 容错。
  test('EpubCfiLocator.fromJson tolerates double chapterIndex', () {
    final json = {
      'type': 'epubCfi',
      'cfi': 'epubcfi(/6/4)',
      'chapterIndex': 0.0, // double 形式
      'offsetX': 0.0,
      'offsetY': 0.0,
    };
    final locator = Locator.fromJson(json);
    expect(locator, isA<EpubCfiLocator>());
    expect((locator as EpubCfiLocator).chapterIndex, 0);
  });

  test('PdfPageLocator.fromJson tolerates double page', () {
    final json = {
      'type': 'pdfPage',
      'page': 5.0, // double 形式
      'offsetX': 0.0,
      'offsetY': 0.0,
    };
    final locator = Locator.fromJson(json);
    expect(locator, isA<PdfPageLocator>());
    expect((locator as PdfPageLocator).page, 5);
  });
}
