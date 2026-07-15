// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:zhiyue/features/reader/pages/reader_body.dart';

/// v1.11.9-alpha Bug 3：添加书签的默认 label 应该用 reader 实际显示的
/// 章节名（来自 `_chapterTitlesCache`，例如「译者序」「第一章 众妙之门」），
/// 而非 raw `chapterIndex + 1`（包含译者序、引言等前置内容 → 与 reader 顶部
/// 显示的章节名不一致 → 用户报告「显示的目前多少章和标题不一致」）。
void main() {
  group('computeDefaultBookmarkLabel (v1.11.9-alpha Bug 3)', () {
    test('uses chapter title from cache (not raw index+1)', () {
      final locator = EpubCfiLocator(cfi: '2:0', chapterIndex: 2);
      final label = computeDefaultBookmarkLabel(
        locator,
        chapterTitles: const {
          0: '译者序',
          1: '引言',
          2: '第一章 众妙之门',
        },
        epubPageLabel: null,
      );
      expect(label, '第一章 众妙之门',
          reason: '应优先用 chapterTitles[2]，而非「第 3 章」（含前置内容）');
    });

    test(
        'front matter (译者序/引言) shows its actual title, not 第 N 章 format',
        () {
      final locator = EpubCfiLocator(cfi: '0:0', chapterIndex: 0);
      final label = computeDefaultBookmarkLabel(
        locator,
        chapterTitles: const {0: '译者序', 1: '引言', 2: '第一章'},
        epubPageLabel: null,
      );
      expect(label, '译者序',
          reason: '前置内容应显示为「译者序」而非「第 1 章」——与 reader 顶部'
              '显示的章节名一致');
    });

    test('falls back to 第 N 章 when chapter title is null', () {
      final locator = EpubCfiLocator(cfi: '0:0', chapterIndex: 2);
      final label = computeDefaultBookmarkLabel(
        locator,
        chapterTitles: const {},
        epubPageLabel: null,
      );
      expect(label, '第 3 章',
          reason: '无 title 缓存时 fallback 到 raw index+1');
    });

    test('appends epub page label when provided', () {
      final locator = EpubCfiLocator(cfi: '2:0', chapterIndex: 2);
      final label = computeDefaultBookmarkLabel(
        locator,
        chapterTitles: const {2: '第一章 众妙之门'},
        epubPageLabel: '第 5 页',
      );
      expect(label, '第一章 众妙之门 · 第 5 页');
    });

    test('EpubRangeLocator also uses chapter title', () {
      final locator = EpubRangeLocator(
        chapterIndex: 1,
        startOffset: 10,
        endOffset: 20,
        quote: 'sample quote text',
      );
      final label = computeDefaultBookmarkLabel(
        locator,
        chapterTitles: const {0: '译者序', 1: '引言'},
        epubPageLabel: null,
      );
      expect(label, '引言');
    });

    test('PdfPageLocator returns 第 N 页', () {
      final locator = PdfPageLocator(page: 42, offsetX: 0.0, offsetY: 0.0);
      final label = computeDefaultBookmarkLabel(
        locator,
        chapterTitles: const {},
      );
      expect(label, '第 42 页');
    });

    test('PdfRangeLocator returns 第 N 页', () {
      final locator = PdfRangeLocator(
        page: 42,
        startOffset: 0,
        endOffset: 100,
        quote: 'sample',
      );
      final label = computeDefaultBookmarkLabel(
        locator,
        chapterTitles: const {},
      );
      expect(label, '第 42 页');
    });
  });
}
