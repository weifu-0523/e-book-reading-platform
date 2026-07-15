// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:epubx/epubx.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

/// Synthetic EPUB mimicking Calibre-generated 道德经 structure:
/// - All 3 navPoints point to the same html file
/// - Each navPoint has a #fileposNNNNN anchor
/// - The html file contains matching <p id="filepos..."> elements
EpubBook _calibreStyleBook() {
  const html =
      '<p id="filepos10737">前言内容</p>'
      '<p id="filepos16682">道经标题</p>'
      '<p id="filepos16764">第一章 众妙之门</p>'
      '<p>第一章正文</p>';
  return EpubBook()
    ..Title = '道德经 Test'
    ..Chapters = [
      EpubChapter()
        ..Title = '前言'
        ..ContentFileName = 'index_split_001.html'
        ..Anchor = null
        ..HtmlContent = html,
      EpubChapter()
        ..Title = '道经'
        ..ContentFileName = 'index_split_001.html'
        ..Anchor = 'filepos16682'
        ..HtmlContent = html,
      EpubChapter()
        ..Title = '第一章 众妙之门'
        ..ContentFileName = 'index_split_001.html'
        ..Anchor = 'filepos16764'
        ..HtmlContent = html,
    ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EpubxRenderer TOC anchor resolution', () {
    test('all navPoints map to same deduped chapter index', () async {
      final r = EpubxRenderer();
      r.bookForTesting = _calibreStyleBook();
      final toc = await r.toc;
      expect(toc.entries.length, 3);
      for (final entry in toc.entries) {
        final loc = entry.locator;
        expect(loc, isA<EpubCfiLocator>());
        expect((loc as EpubCfiLocator).chapterIndex, 0,
            reason: 'All entries share ContentFileName → deduped idx 0');
      }
      await r.dispose();
    });

    test('前言 (no anchor) maps to charOffset 0', () async {
      final r = EpubxRenderer();
      r.bookForTesting = _calibreStyleBook();
      final toc = await r.toc;
      final loc = toc.entries[0].locator as EpubCfiLocator;
      expect(loc.cfi, '0:0',
          reason: 'Anchor=null → charOffset 0, deduped idx 0');
      await r.dispose();
    });

    test('道经 (#filepos16682) maps to non-zero charOffset', () async {
      final r = EpubxRenderer();
      r.bookForTesting = _calibreStyleBook();
      final toc = await r.toc;
      final loc = toc.entries[1].locator as EpubCfiLocator;
      // Plain text: "前言内容道经标题第一章 众妙之门第一章正文"
      //              0 1 2 3 4 5 6 7 8 9 ...
      // "道经" starts at index 4 (after "前言内容").
      expect(loc.chapterIndex, 0);
      expect(loc.cfi, startsWith('0:'));
      final offset = int.parse(loc.cfi.split(':')[1]);
      expect(offset, 4,
          reason: 'filepos16682 anchor maps to "道经" plain offset');
      await r.dispose();
    });

    test('第一章 (#filepos16764) maps to later charOffset', () async {
      final r = EpubxRenderer();
      r.bookForTesting = _calibreStyleBook();
      final toc = await r.toc;
      final loc = toc.entries[2].locator as EpubCfiLocator;
      final offset = int.parse(loc.cfi.split(':')[1]);
      // "第一章" starts at index 8 (after "前言内容道经标题").
      expect(offset, 8,
          reason: 'filepos16764 anchor maps to "第一章" plain offset');
      await r.dispose();
    });

    test('missing anchor falls back to charOffset 0', () async {
      final book = EpubBook()
        ..Title = 'Test'
        ..Chapters = [
          EpubChapter()
            ..Title = 'Ghost'
            ..ContentFileName = 'a.html'
            ..Anchor = 'nonexistent'
            ..HtmlContent = '<p>hello</p>',
        ];
      final r = EpubxRenderer();
      r.bookForTesting = book;
      final toc = await r.toc;
      final loc = toc.entries[0].locator as EpubCfiLocator;
      expect(loc.cfi, '0:0',
          reason: 'Missing anchor must fall back to offset 0, not crash');
      await r.dispose();
    });

    test('gotoLocator with anchor-derived cfi switches scroll position',
        () async {
      final r = EpubxRenderer();
      r.bookForTesting = _calibreStyleBook();
      final toc = await r.toc;
      await r.gotoLocator(toc.entries[2].locator);
      expect(r.currentChapterIndex, 0);
      await r.dispose();
    });
  });

  /// v1.11.7-alpha+1 hotfix: scroll-mode `gotoLocator` was using `html.length`
  /// as `totalChars`, but `decoded.charOffset` from TOC anchors is in
  /// PlainTextUtils plain-text coords. HTML length includes tags/attributes,
  /// so it's much larger than plain length → ratio = plain/html was too small
  /// → scroll landed at an earlier chapter than the TOC entry pointed to.
  /// 道德经 第十三章 plain offset=18381, html.length=105568, plain.length=60986
  /// → buggy ratio = 0.174 → lands at 第八章. Fix: use plain length everywhere.
  group('scroll ratio coordinate system (v1.11.7-alpha+1 hotfix)', () {
    /// Synthetic EPUB whose HTML length differs noticeably from plain length.
    /// HTML: '<p id="a">A</p><p id="b">B</p><p id="c">C</p>'
    ///   html.length = 39 (with tags)
    ///   plain text = "ABC"
    ///   plain.length = 3
    EpubBook _bookWithHtmlHeavyTags() {
      const html = '<p id="a">A</p><p id="b">B</p><p id="c">C</p>';
      return EpubBook()
        ..Title = 'TagHeavy'
        ..Chapters = [
          EpubChapter()
            ..Title = 'one'
            ..ContentFileName = 'a.html'
            ..Anchor = null
            ..HtmlContent = html,
          EpubChapter()
            ..Title = 'two'
            ..ContentFileName = 'a.html'
            ..Anchor = 'b'
            ..HtmlContent = html,
          EpubChapter()
            ..Title = 'three'
            ..ContentFileName = 'a.html'
            ..Anchor = 'c'
            ..HtmlContent = html,
        ];
    }

    test('plain text length helper returns plain length, not HTML length',
        () async {
      final r = EpubxRenderer();
      r.bookForTesting = _bookWithHtmlHeavyTags();
      // HTML length is 45 (tags + content); plain text length is 3 ("ABC").
      expect(r.flatChapterHtmlAt(0).length, 45);
      expect(r.debugPlainTextLengthForChapter(0), 3,
          reason: 'Plain length must exclude tags — was html.length=45 before fix');
      await r.dispose();
    });

    test('scroll-mode ratio for anchor at offset 2 (out of 3) lands near 67%',
        () async {
      final r = EpubxRenderer();
      r.bookForTesting = _bookWithHtmlHeavyTags();
      // Anchor "c" plain offset = 2 (after "AB").
      // totalChars: html.length=45 (buggy), plain.length=3 (fixed).
      // Buggy ratio: 2/45 = 0.0444
      // Fixed ratio: 2/3  = 0.6667
      final ratio = r.debugComputeScrollRatioForTesting(
        chapterIndex: 0,
        charOffset: 2,
      );
      expect(ratio, closeTo(2.0 / 3.0, 0.001),
          reason: 'Scroll ratio must be charOffset / plain.length, '
              'not charOffset / html.length');
      expect(ratio, isNot(closeTo(2.0 / 45.0, 0.001)),
          reason: 'Old behavior (HTML length) would compress the ratio');
      await r.dispose();
    });
  });

  /// v1.11.9-alpha Bug 4 fix: 书签偏移 regression。
  ///
  /// v1.11.8-alpha 把 `_emitCurrentLocation` 和 `gotoLocator` 的 totalChars
  /// 从 `html.length` 改成 `_plainTextLengthForChapter`（commit 5f6ef1f）。
  /// 旧书签（v1.11.7-alpha 及之前）的 charOffset 是 `scrollRatio × html.length`
  /// encoded，用新公式 `charOffset / plain.length` 会得到放大 ~1.73× 的错误
  /// ratio → 用户报告"安装新版本后原书签定位偏移"。
  ///
  /// Fix: `gotoLocator` scroll 分支加 heuristic —— charOffset > plainLen 说明
  /// 是旧格式，按 html.length 比例缩放到新坐标系。低 ratio 旧书签
  /// （charOffset ≤ plainLen）无法区分，小偏差可接受。
  group('scroll ratio legacy-aware (v1.11.9-alpha Bug 4 fix)', () {
    EpubBook _bookWithHtmlHeavyTags() {
      const html = '<p id="a">A</p><p id="b">B</p><p id="c">C</p>';
      return EpubBook()
        ..Title = 'TagHeavy'
        ..Chapters = [
          EpubChapter()
            ..Title = 'one'
            ..ContentFileName = 'a.html'
            ..Anchor = null
            ..HtmlContent = html,
        ];
    }

    test(
        'legacy bookmark charOffset (html-encoded) is rescaled to plain coords',
        () async {
      final r = EpubxRenderer();
      r.bookForTesting = _bookWithHtmlHeavyTags();
      // 模拟 v1.11.7-alpha 旧书签：用户阅读到 scroll ratio 0.667（"C" 位置）
      // 旧 _emitCurrentLocation: charOffset = 0.667 × html.length = 0.667 × 45 = 30
      // 用新公式（无 heuristic）：30 / 3 = 10 → clamp 到 1.0 → 跳到章末（错！）
      // 修复后 heuristic：30 > 3（plainLen）→ 旧 ratio = 30/45 = 0.667 →
      // 新 charOffset = 0.667 × 3 = 2 → ratio = 2/3 ≈ 0.667（正确）
      final ratio = r.debugComputeLegacyAwareScrollRatioForTesting(
        chapterIndex: 0,
        charOffset: 30,
      );
      expect(ratio, closeTo(2.0 / 3.0, 0.05),
          reason: 'Legacy html-encoded charOffset must be rescaled by '
              'htmlLen/plainLen ratio so old bookmarks land where the user '
              'originally placed them.');
      await r.dispose();
    });

    test('modern bookmark charOffset (plain-encoded) is preserved exactly',
        () async {
      final r = EpubxRenderer();
      r.bookForTesting = _bookWithHtmlHeavyTags();
      // 新书签 charOffset 是 plain 坐标，2 表示 "C" 位置（用户加书签时已是
      // v1.11.8+ 的 _emitCurrentLocation 存的 plain offset）。
      final ratio = r.debugComputeLegacyAwareScrollRatioForTesting(
        chapterIndex: 0,
        charOffset: 2,
      );
      expect(ratio, closeTo(2.0 / 3.0, 0.001),
          reason: 'Modern plain-encoded charOffset ≤ plainLen must not be '
              'rescaled — heuristic only kicks in for charOffset > plainLen.');
      await r.dispose();
    });

    test('charOffset 0 always lands at chapter start', () async {
      final r = EpubxRenderer();
      r.bookForTesting = _bookWithHtmlHeavyTags();
      final ratio = r.debugComputeLegacyAwareScrollRatioForTesting(
        chapterIndex: 0,
        charOffset: 0,
      );
      expect(ratio, 0.0);
      await r.dispose();
    });
  });
}
