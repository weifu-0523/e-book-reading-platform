// 探索性 spike —— 验证 epubx 能否解析真实 EPUB。
// spike 验证通过后整个文件可删；不放进 test/ 以免 CI 长期依赖 fixture。
import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // fixture 路径：包目录是 reader_engine_epub_view/，fixture 在 ../app/test/fixtures/
  // 这样无论从项目根还是从包目录跑 flutter test 都能定位到（spike 用，不放进 test/）。
  const fixturePath = '../app/test/fixtures/page-blanche.epub';

  test('spike: epubx parses real EPUB', () async {
    final file = File(fixturePath);
    if (!file.existsSync()) {
      // skip 模式：fixture 未准备好（Task 8 未完成），spike 推迟
      debugPrint('SKIP spike: $fixturePath not present. '
          'Run Task 8 to download the fixture.');
      return;
    }

    final bytes = await file.readAsBytes();
    final book = await EpubReader.readBook(bytes);

    // 1. 标题非空
    expect(book.Title, isNotNull, reason: 'epubx 未返回 Title');
    expect(
      book.Title!.isNotEmpty,
      isTrue,
      reason: 'epubx 返回空 Title — 可能解析损坏',
    );

    // 2. 章节列表非空（epubx 把 spine 项扁平化到 Chapters + SubChapters）
    final flatChapters = _flattenChapters(book.Chapters ?? const []);
    expect(
      flatChapters,
      isNotEmpty,
      reason: 'epubx 返回 0 章节 — spine 是否丢失？',
    );

    debugPrint('OK: Title="${book.Title}", chapters=${flatChapters.length}');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('spike: chapter HTML is reasonable', () async {
    final file = File(fixturePath);
    if (!file.existsSync()) {
      debugPrint('SKIP spike: $fixturePath not present.');
      return;
    }

    final bytes = await file.readAsBytes();
    final book = await EpubReader.readBook(bytes);
    final flatChapters = _flattenChapters(book.Chapters ?? const []);
    if (flatChapters.isEmpty) {
      debugPrint('SKIP spike HTML check: 0 chapters parsed.');
      return;
    }

    final html = flatChapters.first.HtmlContent ?? '';
    // 3. HTML 非空
    expect(
      html.isNotEmpty,
      isTrue,
      reason: 'epubx 返回空 HtmlContent — 内容文件丢失？',
    );

    // 4. 剥离标签后纯文本非空（粗糙检查 flutter_widget_from_html 能渲染出内容）
    final plainText = _stripHtml(html);
    expect(
      plainText.trim().isNotEmpty,
      isTrue,
      reason: 'HTML 剥离后为空字符串 — HTML 结构异常？',
    );

    debugPrint(
      'OK: html length=${html.length}, plainText preview='
      '${plainText.length > 80 ? plainText.substring(0, 80) : plainText}',
    );
  }, timeout: const Timeout(Duration(seconds: 30)));
}

/// 递归展开 Chapters + SubChapters 为扁平列表。
List<EpubChapter> _flattenChapters(List<EpubChapter> chapters) {
  final result = <EpubChapter>[];
  for (final c in chapters) {
    result.add(c);
    result.addAll(_flattenChapters(c.SubChapters ?? const []));
  }
  return result;
}

/// 粗糙剥离 HTML 标签 —— spike 用，非生产代码。
/// 生产代码用 flutter_widget_from_html 渲染，不需要这步。
String _stripHtml(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
