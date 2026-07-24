# EPUB Anchor TOC Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix EPUB books whose NCX TOC points to anchor fragments within a single HTML file (e.g., Calibre-generated `index_split_001.html#filepos16764`) — clicking TOC entries must jump to the corresponding in-chapter position instead of staying at offset 0 with duplicated full-file chapters.

**Architecture:** Three-layer fix in `reader_engine_epub_view`: (1) a pure utility `PlainTextUtils.anchorToPlainOffset` to map an HTML anchor id to a plain-text character offset (same coordinate system as cfi_codec's charOffset), (2) renderer-level chapter dedup — collapse EpubChapters that share the same `ContentFileName` into one `_chapters` entry, (3) TOC builder uses deduped chapter index + anchor-derived charOffset per navPoint. No `epubx_patched` changes; no Locator protocol extensions.

**Tech Stack:** Dart, Flutter test framework, `epubx_patched`, `reader_engine_epub_view` (in-repo path dependency), cfi_codec (`chapterIndex:charOffset` round-trip).

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `reader_engine_epub_view/lib/plain_text_utils.dart` | HTML→plain conversion + anchor lookup | Add `anchorToPlainOffset` static method |
| `reader_engine_epub_view/test/plain_text_utils_test.dart` | Unit tests for PlainTextUtils | Add anchor offset test group |
| `reader_engine_epub_view/lib/epubx_renderer.dart` | EPUB renderer: holds `_chapters`, builds TOC | Add `_dedupedChapters` field + `_buildDedupedChaptersAndMaps` + rewrite `_chaptersToToc` |
| `reader_engine_epub_view/test/epubx_renderer_anchor_toc_test.dart` | New test file for anchor TOC behavior | Create |
| `reader_engine_epub_view/test/epubx_renderer_test.dart` | Existing tests | Add dedup regression test |
| `app/pubspec.yaml` | Version bump for hotfix | 1.11.4-alpha → 1.11.5-alpha |
| `CHANGELOG.md` | User-facing change notes | Add v1.11.5-alpha entry |
| `docs/releases/release-notes-v1.11.5-alpha.md` | Release notes | Create |

---

### Task 1: Add `PlainTextUtils.anchorToPlainOffset` utility

**Files:**
- Modify: `reader_engine_epub_view/lib/plain_text_utils.dart`
- Test: `reader_engine_epub_view/test/plain_text_utils_test.dart`

- [ ] **Step 1: Write failing tests for `anchorToPlainOffset`**

Append to `reader_engine_epub_view/test/plain_text_utils_test.dart` (after existing tests, before `main()`'s closing `}`):

```dart
group('anchorToPlainOffset', () {
  test('returns null when anchor id not present in html', () {
    const html = '<p>hello</p><p>world</p>';
    expect(PlainTextUtils.anchorToPlainOffset(html, 'missing'), isNull);
  });

  test('returns 0 when anchor is at the very start of plain text', () {
    const html = '<p id="ch1">第一章</p><p>正文内容</p>';
    expect(PlainTextUtils.anchorToPlainOffset(html, 'ch1'), 0);
  });

  test('returns plain-text char count before the anchor element', () {
    // Plain text of "<p>前言</p><p id='ch1'>第一章</p>" is "前言第一章".
    // Anchor 'ch1' is at the start of "第一章" → plain offset = 2 (length of "前言").
    const html = '<p>前言</p><p id="ch1">第一章</p>';
    expect(PlainTextUtils.anchorToPlainOffset(html, 'ch1'), 2);
  });

  test('handles anchor with leading whitespace text before it', () {
    // Plain text: "前言\n\n第一章" → "ch1" anchor at "第一章" position.
    // \n counts as 1 char each in plain text, so offset = len("前言") + 2 newlines = 4.
    const html = '<p>前言</p>\n<p id="ch1">第一章</p>';
    final offset = PlainTextUtils.anchorToPlainOffset(html, 'ch1');
    expect(offset, isNotNull);
    expect(offset! >= 2, isTrue, reason: 'offset must include chars before anchor');
  });

  test('matches Calibre-style filepos anchor id', () {
    // Real-world Calibre pattern: <p id="filepos16764">第一章 众妙之门</p>
    const html = '<p id="filepos10737">前言</p>'
        '<p id="filepos16682">道经</p>'
        '<p id="filepos16764">第一章 众妙之门</p>';
    final first = PlainTextUtils.anchorToPlainOffset(html, 'filepos16764');
    expect(first, isNotNull);
    expect(first!, greaterThan(0),
        reason: 'filepos16764 is after filepos10737 and filepos16682');
  });

  test('matches single-quoted id="...anchor..." attribute', () {
    const html = "<p>intro</p><p id='ch2'>chapter two</p>";
    expect(PlainTextUtils.anchorToPlainOffset(html, 'ch2'), 5);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run from `reader_engine_epub_view/`:
```bash
cd C:\zhiyue_build_s3\reader_engine_epub_view && /c/flutter/bin/flutter.bat test test/plain_text_utils_test.dart
```
Expected: FAIL with `anchorToPlainOffset` not defined / method not found.

- [ ] **Step 3: Implement `anchorToPlainOffset` in PlainTextUtils**

Add this method to the `PlainTextUtils` class in `reader_engine_epub_view/lib/plain_text_utils.dart` (after `htmlToPlainWithOffsets`, before `_decodeEntity`):

```dart
/// Locates an HTML anchor id (e.g., `<p id="ch1">` or `<a name="ch1">`)
/// and returns the corresponding plain-text character offset within the
/// same coordinate system as [htmlToPlainWithOffsets].
///
/// Used to resolve NCX TOC fragment anchors (e.g., Calibre's
/// `#filepos16764`) to a charOffset for `EpubCfiLocator`.
///
/// Returns `null` when the anchor id is not present in `html`. Returns `0`
/// when the anchor is at the very start of plain text.
///
/// Matching rules:
/// - Recognizes `id="X"`, `id='X'`, `name="X"`, `name='X'` (any case for
///   the attribute name; X must be quoted and exactly equal to `anchor`).
/// - Uses the position of the **opening `<` of the element containing the
///   attribute** as the html offset, then maps it to plain coordinates.
/// - When multiple matches exist, uses the first occurrence.
static int? anchorToPlainOffset(String html, String anchor) {
  // Find the first attribute occurrence whose value equals `anchor`.
  // Patterns: id="anchor" / id='anchor' / name="anchor" / name='anchor'.
  final patterns = [
    RegExp("id=[\"']${RegExp.escape(anchor)}[\"']"),
    RegExp("name=[\"']${RegExp.escape(anchor)}[\"']"),
  ];
  int? attrStart;
  for (final p in patterns) {
    final m = p.firstMatch(html);
    if (m != null) {
      attrStart = m.start;
      break;
    }
  }
  if (attrStart == null) return null;

  // Walk back to the '<' that opens the element containing this attribute.
  final lt = html.lastIndexOf('<', attrStart);
  final htmlOffset = lt < 0 ? 0 : lt;

  // Map htmlOffset → plain offset via the same coordinate system.
  final (_, offsets) = htmlToPlainWithOffsets(html);
  // If offsets is empty (no plain text in html), return 0.
  if (offsets.isEmpty) return 0;
  // Binary-search the largest plain index i where offsets[i] <= htmlOffset.
  // ans starts at -1 so the "no plain char before htmlOffset" case (anchor
  // at the very start of html) correctly returns ans + 1 = 0.
  var lo = 0, hi = offsets.length - 1, ans = -1;
  while (lo <= hi) {
    final mid = lo + (hi - lo) ~/ 2;
    if (offsets[mid] <= htmlOffset) {
      ans = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  // ans = index of the last plain char BEFORE the target element.
  // ans + 1 = count of plain chars before the target = plain offset where
  // the target element's first char will appear.
  return ans + 1;
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd C:\zhiyue_build_s3\reader_engine_epub_view && /c/flutter/bin/flutter.bat test test/plain_text_utils_test.dart
```
Expected: PASS (all `anchorToPlainOffset` tests + existing tests).

- [ ] **Step 5: Commit**

```bash
cd C:\zhiyue_build_s3 && git add reader_engine_epub_view/lib/plain_text_utils.dart reader_engine_epub_view/test/plain_text_utils_test.dart && git commit -m "$(cat <<'EOF'
feat(reader-engine): anchor→plain-text offset utility for EPUB TOC

PlainTextUtils.anchorToPlainOffset maps an HTML id/name anchor to its
plain-text charOffset (same coordinate system as htmlToPlainWithOffsets
and cfi_codec). Recognizes double/single-quoted id= and name=, returns
null when anchor absent.

Prerequisite for fixing Calibre-style EPUBs whose NCX TOC points to
#fileposNNNNN fragment anchors within a single HTML file.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Add chapter dedup helper + dedup state to EpubxRenderer

**Files:**
- Modify: `reader_engine_epub_view/lib/epubx_renderer.dart`
- Test: `reader_engine_epub_view/test/epubx_renderer_test.dart`

- [ ] **Step 1: Write failing test for dedup behavior**

Append to `reader_engine_epub_view/test/epubx_renderer_test.dart` (inside `main()`, after existing tests):

```dart
group('dedupe chapters by ContentFileName (anchor TOC fix)', () {
  test('collapses 3 navPoints sharing one html file into 1 _chapters entry',
      () async {
    // Real-world Calibre pattern: 前言 / 道经 / 第一章 all point to
    // index_split_001.html with different #filepos anchors.
    const sharedHtml =
        '<p id="filepos10737">前言内容</p>'
        '<p id="filepos16682">道经</p>'
        '<p id="filepos16764">第一章 众妙之门</p>'
        '<p>正文</p>';
    final book = EpubBook()
      ..Title = 'TestDedup'
      ..Chapters = [
        EpubChapter()
          ..Title = '前言'
          ..ContentFileName = 'index_split_001.html'
          ..Anchor = null
          ..HtmlContent = sharedHtml,
        EpubChapter()
          ..Title = '道经'
          ..ContentFileName = 'index_split_001.html'
          ..Anchor = 'filepos16682'
          ..HtmlContent = sharedHtml,
        EpubChapter()
          ..Title = '第一章 众妙之门'
          ..ContentFileName = 'index_split_001.html'
          ..Anchor = 'filepos16764'
          ..HtmlContent = sharedHtml,
      ];

    final r = EpubxRenderer();
    r.bookForTesting = book;

    // Deduped: only 1 chapter (one per unique ContentFileName).
    expect(r.chapterCount, 1,
        reason: '3 navPoints sharing one html file must dedupe to 1 chapter');
    await r.dispose();
  });

  test('keeps separate chapters when ContentFileName differs', () async {
    final book = EpubBook()
      ..Title = 'TestNoDedup'
      ..Chapters = [
        EpubChapter()
          ..Title = 'Ch1'
          ..ContentFileName = 'a.html'
          ..HtmlContent = '<p>a</p>',
        EpubChapter()
          ..Title = 'Ch2'
          ..ContentFileName = 'b.html'
          ..HtmlContent = '<p>b</p>',
      ];
    final r = EpubxRenderer();
    r.bookForTesting = book;
    expect(r.chapterCount, 2,
        reason: 'Different ContentFileName must NOT dedupe');
    await r.dispose();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd C:\zhiyue_build_s3\reader_engine_epub_view && /c/flutter/bin/flutter.bat test test/epubx_renderer_test.dart --plain-name "dedupe"
```
Expected: FAIL — `chapterCount` is 3, not 1 (current code doesn't dedupe).

- [ ] **Step 3: Add `_buildDedupedChapters` helper + dedup-aware `_chapters` build**

In `reader_engine_epub_view/lib/epubx_renderer.dart`:

(a) Add a private field next to existing `_chapters` declaration (line ~97):
```dart
List<HtmlChapterSource> _chapters = const [];
```
Add directly below it:
```dart
/// Map from `EpubChapter.ContentFileName` to its deduped index in
/// [_chapters]. Populated by [_buildDedupedChaptersAndMap]. Empty for
/// MD/TXT path (openChapters) — those sources have no ContentFileName.
Map<String, int> _contentFileToChapterIndex = const {};
```

(b) Add the helper method immediately after `_flattenChapters` (around line 570):
```dart
/// Builds the deduped [_chapters] list — one entry per unique
/// `ContentFileName` — plus the reverse lookup map.
///
/// **Why dedupe:** epubx's `EpubChapterRef.readHtmlContent` returns the
/// entire HTML file regardless of NCX anchor fragment. When multiple
/// navPoints share a `ContentFileName` (Calibre-generated EPUBs often
/// put 80+ chapters as `#fileposNNNNN` anchors inside one html file),
/// each EpubChapter ends up with a full duplicate of the same HTML.
/// Without dedupe, [_chapters] would contain 80 entries with identical
/// content — clicking TOC visually stays on the same content.
///
/// First occurrence wins (navPoints typically appear in reading order).
/// Subsequent duplicates are dropped from [_chapters] but still get a
/// TOC entry via the reverse map.
List<HtmlChapterSource> _buildDedupedChaptersAndMap(
  List<EpubChapter> flat,
  EpubImageInliner? inliner,
) {
  final result = <HtmlChapterSource>[];
  final map = <String, int>{};
  for (final c in flat) {
    final key = c.ContentFileName ?? '';
    if (map.containsKey(key)) continue;
    map[key] = result.length;
    result.add(HtmlChapterSource(
      title: c.Title ?? '',
      html: inliner?.inline(
            c.HtmlContent ?? '',
            chapterContentFileName: c.ContentFileName,
          ) ??
          c.HtmlContent ??
          '',
    ));
  }
  _contentFileToChapterIndex = Map.unmodifiable(map);
  return List.unmodifiable(result);
}
```

(c) Replace the `_chapters =` assignment inside `openFile` (around line 595). Find this block:
```dart
_chapters = _flattenChapters(book.Chapters ?? const [])
    .map((c) => HtmlChapterSource(
          title: c.Title ?? '',
          html: _imageInliner!.inline(
            c.HtmlContent ?? '',
            chapterContentFileName: c.ContentFileName,
          ),
        ))
    .toList();
```
Replace with:
```dart
_chapters = _buildDedupedChaptersAndMap(
  _flattenChapters(book.Chapters ?? const []),
  _imageInliner,
);
```

(d) Replace the `_chapters =` assignment inside `bookForTesting` setter (around line 534). Find this block:
```dart
_chapters = book == null
    ? const []
    : _flattenChapters(book.Chapters ?? const [])
        .map((c) => HtmlChapterSource(
              title: c.Title ?? '',
              html: _imageInliner!.inline(
                c.HtmlContent ?? '',
                chapterContentFileName: c.ContentFileName,
              ),
            ))
        .toList();
```
Replace with:
```dart
_contentFileToChapterIndex = const {};
_chapters = book == null
    ? const []
    : _buildDedupedChaptersAndMap(
        _flattenChapters(book.Chapters ?? const []),
        _imageInliner,
      );
```

(e) Also reset the map at the top of `openChapters` (MD/TXT path). Find the `openChapters` method body's `_chapters = List<HtmlChapterSource>.unmodifiable(chapters);` line and add directly above it:
```dart
_contentFileToChapterIndex = const {};
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd C:\zhiyue_build_s3\reader_engine_epub_view && /c/flutter/bin/flutter.bat test test/epubx_renderer_test.dart --plain-name "dedupe"
```
Expected: PASS — both dedupe tests pass.

Then run the full renderer test suite to catch regressions:
```bash
cd C:\zhiyue_build_s3\reader_engine_epub_view && /c/flutter/bin/flutter.bat test
```
Expected: PASS — no regressions in gotoLocator / setters / chapter_end / pagination tests.

- [ ] **Step 5: Commit**

```bash
cd C:\zhiyue_build_s3 && git add reader_engine_epub_view/lib/epubx_renderer.dart reader_engine_epub_view/test/epubx_renderer_test.dart && git commit -m "$(cat <<'EOF'
feat(reader-engine): dedupe EPUB chapters by ContentFileName

EpubxRenderer now keeps one _chapters entry per unique ContentFileName.
Calibre-generated EPUBs put many chapters as #filepos anchors inside a
single html file; epubx returns the full file content per navPoint, so
without dedupe _chapters contained N duplicate entries.

Adds _buildDedupedChaptersAndMap helper + _contentFileToChapterIndex
reverse lookup (populated for EPUB path, empty for MD/TXT path).

Prerequisite for Task 3 (TOC builder uses deduped index + anchor offset).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Rewrite `_chaptersToToc` to use deduped index + anchor charOffset

**Files:**
- Modify: `reader_engine_epub_view/lib/epubx_renderer.dart`
- Test: `reader_engine_epub_view/test/epubx_renderer_anchor_toc_test.dart` (new)

- [ ] **Step 1: Write failing test for the new TOC behavior**

Create `reader_engine_epub_view/test/epubx_renderer_anchor_toc_test.dart`:

```dart
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
      // Anchor references an id that does NOT exist in html.
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
      // Jump to "第一章" — should not crash, should set currentChapterIndex 0.
      await r.gotoLocator(toc.entries[2].locator);
      expect(r.currentChapterIndex, 0);
      await r.dispose();
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd C:\zhiyue_build_s3\reader_engine_epub_view && /c/flutter/bin/flutter.bat test test/epubx_renderer_anchor_toc_test.dart
```
Expected: FAIL — current `_chaptersToToc` produces `cfi: '0:0'` for every entry (charOffset ignored), and TOC has 3 entries pointing to chapterIndex 0/1/2 (flat index, not deduped).

- [ ] **Step 3: Rewrite `_chaptersToToc` and `_chaptersToSubEntries` to use deduped index + anchor offset**

In `reader_engine_epub_view/lib/epubx_renderer.dart`, find the existing `_chaptersToToc` and `_chaptersToSubEntries` methods (around lines 768-802) and replace them entirely with:

```dart
/// 把 epubx 的 EpubChapter 树转 TocEntry 树。
///
/// 每个 navPoint 的 locator 用：
/// - chapterIndex：按 ContentFileName 在 [_chapters] 中的去重索引
///   （[_contentFileToChapterIndex] 查表）
/// - charOffset：anchor 在该章 HTML 中对应的 plain-text 偏移
///   （[PlainTextUtils.anchorToPlainOffset]）。
///
/// 这样多个 navPoint 共享同一 html 文件时，TOC 仍保留每个 navPoint
/// 的层级与标题，但 locator 都指向唯一去重章节内的不同字符偏移——
/// 点击 TOC 跳转到正确的位置而非章节开头。
///
/// anchor 为 null 或在 html 中找不到时，charOffset 回退到 0。
List<TocEntry> _chaptersToToc(List<EpubChapter> chapters) {
  final result = <TocEntry>[];
  for (final ch in chapters) {
    final locator = _locatorForChapter(ch);
    result.add(TocEntry(
      title: ch.Title ?? '(无标题)',
      locator: locator,
      children: _chaptersToSubEntries(ch.SubChapters ?? const []),
    ));
  }
  return result;
}

List<TocEntry> _chaptersToSubEntries(List<EpubChapter> subChapters) {
  final result = <TocEntry>[];
  for (final ch in subChapters) {
    final locator = _locatorForChapter(ch);
    result.add(TocEntry(
      title: ch.Title ?? '(无标题)',
      locator: locator,
      children: _chaptersToSubEntries(ch.SubChapters ?? const []),
    ));
  }
  return result;
}

/// 为单个 EpubChapter（可能共享 ContentFileName）构造 deduped locator。
EpubCfiLocator _locatorForChapter(EpubChapter ch) {
  final contentFile = ch.ContentFileName ?? '';
  final dedupedIdx = _contentFileToChapterIndex[contentFile] ?? 0;
  final anchor = ch.Anchor;
  var charOffset = 0;
  if (anchor != null && anchor.isNotEmpty) {
    final html = flatChapterHtmlAt(dedupedIdx);
    final resolved = PlainTextUtils.anchorToPlainOffset(html, anchor);
    if (resolved != null) charOffset = resolved;
  }
  return EpubCfiLocator(
    cfi: encode(dedupedIdx, charOffset),
    chapterIndex: dedupedIdx,
  );
}
```

Also update the caller in the `toc` getter (around line 744). Find this line:
```dart
return TableOfContents(entries: _chaptersToToc(book.Chapters ?? const [], 0));
```
Replace with:
```dart
return TableOfContents(entries: _chaptersToToc(book.Chapters ?? const []));
```

Add the `PlainTextUtils` import at the top of the file if not already imported. Check existing imports — if `plain_text_utils.dart` is not imported, add:
```dart
import 'plain_text_utils.dart';
```
(after the existing relative imports like `cfi_codec.dart`).

Note: `_countFlat` is no longer referenced after the rewrite. Leave it as-is (it may still be referenced by tests; deleting risks breaking them). If `dart analyze` flags it as unused, leave the warning — it's a defensive helper for future flat-index callers.

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd C:\zhiyue_build_s3\reader_engine_epub_view && /c/flutter/bin/flutter.bat test test/epubx_renderer_anchor_toc_test.dart
```
Expected: PASS — all 6 anchor TOC tests pass.

Then run the full renderer suite to catch regressions:
```bash
cd C:\zhiyue_build_s3\reader_engine_epub_view && /c/flutter/bin/flutter.bat test
```
Expected: PASS — no regressions. If `epubx_renderer_test.dart` had a test that checked TOC entries' chapterIndex using the old flat-index assumption, that test needs updating (it would be flagged in this run).

- [ ] **Step 5: Commit**

```bash
cd C:\zhiyue_build_s3 && git add reader_engine_epub_view/lib/epubx_renderer.dart reader_engine_epub_view/test/epubx_renderer_anchor_toc_test.dart && git commit -m "$(cat <<'EOF'
fix(reader-engine): TOC entries use deduped index + anchor charOffset

Rewrites _chaptersToToc to build each TocEntry's EpubCfiLocator from:
- chapterIndex via _contentFileToChapterIndex lookup (deduped)
- charOffset via PlainTextUtils.anchorToPlainOffset(html, anchor)

Fixes the user-reported bug on 道德经 (Calibre-generated EPUB): all 80+
navPoints pointed to index_split_001.html#fileposNNNNN — clicking any
TOC entry previously stayed at chapter-offset 0 because every chapter
shared the same html and the anchor was ignored.

Now: navPoint '第一章 众妙之门' (#filepos16764) resolves to deduped
chapter 0 with the plain-text char offset of <p id="filepos16764">,
so gotoLocator scrolls to the right position.

Tests: 6 new anchor TOC cases covering shared-file dedup, anchor→offset,
missing-anchor fallback, gotoLocator no-crash.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Manual verification with real 道德经 EPUB

**Files:** (no code changes — verification only)

- [ ] **Step 1: Run full test suite from ASCII worktree**

```bash
cd C:\zhiyue_build_s3\app && /c/flutter/bin/flutter.bat test --reporter=compact
```
Expected: 1483+ tests pass (1473 baseline + ~10 new tests added in this fix). The 10 baseline failures (router_test, reader_page_test x5, 3 reader widget compile errors, book_import_service_test) remain unchanged — all pre-existing, unrelated.

- [ ] **Step 2: Run analyzer on changed files**

```bash
cd C:\zhiyue_build_s3\reader_engine_epub_view && /c/flutter/bin/flutter.bat analyze lib/plain_text_utils.dart lib/epubx_renderer.dart
```
Expected: No new warnings. (`_countFlat` may be reported as unused — that's an acceptable known-warning, do not delete.)

- [ ] **Step 3: Build Windows debug to verify compilation**

```bash
cd C:\zhiyue_build_s3\app && /c/flutter/bin/flutter.bat build windows --debug
```
Expected: build succeeds, output at `build\windows\x64\runner\Debug\`.

- [ ] **Step 4: Manual test with the actual book**

Copy the freshly built exe to a test location or run from build dir. Open `H:\projiect\电子书阅读平台\老子道德经 - 老子.epub` in the app:

1. Open TOC drawer — verify the entries include 前言 / 道经 / 第一章 众妙之门 / 第二章 功成弗居 / ... (all chapters visible, not collapsed to 1).
2. Click "第一章 众妙之门" — verify the reader scrolls to the position where 第一章 begins (not stays at 道经/前言).
3. Click "第二章 功成弗居" — verify scroll advances to 第二章.
4. Click "前言" — verify scroll returns to top.
5. Repeat with 与天为敌 — verify the previously-working book still works (translator preface, 第1章, 第2章 all navigate correctly; the book wasn't broken before but verify no regression).
6. Open a PDF book — verify PDF TOC still works (no locator type confusion).

- [ ] **Step 5: Record verification outcome**

If any step fails, file a follow-up task. Do NOT proceed to Task 5 (release) until manual verification passes.

---

### Task 5: Version bump + CHANGELOG + release notes

**Files:**
- Modify: `app/pubspec.yaml`
- Modify: `CHANGELOG.md`
- Create: `docs/releases/release-notes-v1.11.5-alpha.md`

- [ ] **Step 1: Bump version in pubspec.yaml**

In `app/pubspec.yaml`, change `version:` line from `1.11.4-alpha` to `1.11.5-alpha`.

- [ ] **Step 2: Add CHANGELOG entry**

At the top of `CHANGELOG.md` (immediately after the `# Changelog` header), insert:

```markdown
## v1.11.5-alpha — 2026-07-13

### Fixed

- **EPUB TOC anchor navigation**: Calibre-generated EPUBs (e.g., 《老子道德经》)
  whose NCX TOC uses `#fileposNNNNN` fragment anchors within a single HTML
  file now navigate correctly. Previously, all TOC entries shared the same
  full-file chapter and clicking them did nothing visible.

### Known limits

- Anchor ids not present in HTML silently fall back to chapter start
  (offset 0). No user-visible error.
- Anchor matching uses simple `id=`/`name=` attribute scan — does not
  resolve HTML-entity-encoded ids. EPUB generators don't produce these
  in practice.
```

- [ ] **Step 3: Create release notes**

Create `docs/releases/release-notes-v1.11.5-alpha.md`:

```markdown
# v1.11.5-alpha

**发布日期**：2026-07-13
**类型**：hotfix
**上一版本**：v1.11.4-alpha

## 摘要

修复用户报告：道德经 (Calibre 生成的 EPUB) 点击目录无反应。

## 根因

Calibre 生成的 EPUB 把多个章节放在同一个 HTML 文件里，用
`#fileposNNNNN` 锚点区分位置。epubx 库为每个 navPoint 生成一个
EpubChapter 但不按锚点切片，所有 EpubChapter 的 HtmlContent 都是同一份
完整 HTML。我们的渲染器把每个 EpubChapter 当作独立章节，TOC locator
全部 charOffset=0——点击目录在视觉上"没反应、没分章节"。

## 修复

三层修复（全部在 `reader_engine_epub_view`，不动 epubx 库）：

1. `PlainTextUtils.anchorToPlainOffset(html, anchor)`：HTML 锚点 →
   plain-text 字符偏移，与 cfi_codec 同坐标系。
2. `EpubxRenderer._buildDedupedChaptersAndMap`：按 ContentFileName
   去重，同一 HTML 文件只保留一个 _chapters 条目。
3. `_chaptersToToc` 重写：每个 navPoint 的 locator 用 (dedupedIdx,
   anchorOffset) ——多个 TOC 条目指向同一章节内的不同位置。

## 升级指引

直接覆盖安装即可。schema 无变更（仍 v14），无需迁移。

打开 v1.11.5-alpha 后：

- **Calibre 风格 EPUB 目录可跳**：道德经 / 论语 / 任何"单文件 + 锚点"
  结构的 EPUB，点击目录条目跳到对应章节位置。
- **不影响标准 EPUB**：每章独立 HTML 文件的书（如与天为敌）行为不变。

## 测试

新增 8 个测试：

- `plain_text_utils_test.dart`：6 个 `anchorToPlainOffset` 用例
  （null/0/middle/single-quote/Calibre filepos 模式）
- `epubx_renderer_test.dart`：2 个 dedup 用例
  （3 navPoint 同文件 → 1 chapter / 不同文件不 dedup）
- `epubx_renderer_anchor_toc_test.dart`（新）：6 个 TOC locator 用例
  （同章节/deduped idx/anchor→offset/missing fallback/gotoLocator）

总测试：~1483（1473 baseline + ~10 新增）。10 个 pre-existing baseline
失败保持不变。
```

- [ ] **Step 4: Commit + tag**

```bash
cd C:\zhiyue_build_s3 && git add app/pubspec.yaml CHANGELOG.md docs/releases/release-notes-v1.11.5-alpha.md && git commit -m "$(cat <<'EOF'
chore(release): v1.11.5-alpha — EPUB anchor TOC fix

Bumps version, adds CHANGELOG entry + release notes for the Calibre-style
EPUB TOC anchor navigation fix.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)" && git tag v1.11.5-alpha && git tag m2.9.1-anchor-toc
```

- [ ] **Step 5: Merge s3-build → master and push**

```bash
cd C:\zhiyue_build_s3 && git fetch origin && git checkout master && git merge --ff-only s3-build && git push origin master && git push origin v1.11.5-alpha && git push origin m2.9.1-anchor-toc && git checkout s3-build
```

---

### Task 6: Build release artifacts

**Files:** (build outputs only)

- [ ] **Step 1: Build Windows installer + portable**

```bash
cd C:\zhiyue_build_s3\app && /c/flutter/bin/flutter.bat build windows --release
```
Then run Inno Setup:
```bash
/c/Users/1/InnoSetup/ISCC.exe "C:\zhiyue_build_s3\app\windows\installer\zhiyue.iss"
```
Expected: `zhiyue-setup-1.11.5-alpha.exe` produced in `app\windows\installer\Output\`.

- [ ] **Step 2: Build Android APK**

```bash
cd C:\zhiyue_build_s3\app && /c/flutter/bin/flutter.bat build apk --release
```
Expected: `app-release.apk` at `build\app\outputs\flutter-apk\`.

- [ ] **Step 3: Copy artifacts to release locations**

Copy the three artifacts (Windows installer, portable zip, APK) to:
- Desktop (for user pickup)
- `H:\华为同步盘\华为云盘\新版本发布\v1.11.5-alpha\`

Filenames:
- `zhiyue-setup-1.11.5-alpha.exe`
- `zhiyue-portable-1.11.5-alpha.zip`
- `zhiyue-1.11.5-alpha.apk`

- [ ] **Step 4: Notify user**

Report:
- Tag `v1.11.5-alpha` + `m2.9.1-anchor-toc` pushed to Gitee.
- 3 artifacts at Desktop + 华为云盘.
- Manual verification (Task 4 Step 4) passed: 道德经 TOC jumps to correct positions for 前言 / 道经 / 第一章 / 第二章 etc.

---

## Risks

1. **Anchor pattern mismatch**: Some EPUB generators use `<a name="...">` instead of `<p id="...">`, or HTML-entity-encode the id. The implementation matches `id=` and `name=` with both single and double quotes; entity-encoded ids are not handled. **Mitigation**: fall back to charOffset 0 silently; user sees TOC jump to chapter start (graceful degradation, not a crash).

2. **Anchor offset drift after image inlining**: `_buildDedupedChaptersAndMap` runs `_imageInliner.inline(html)` which may modify the HTML (data URIs change byte length). `PlainTextUtils.anchorToPlainOffset` is called against the inlined HTML stored in `_chapters` (via `flatChapterHtmlAt`), so the coordinate system stays consistent — but if image inlining happens after the deduped chapter is built and the id attribute moves, the offset could be wrong. **Mitigation**: inlining only rewrites `<img src>` attribute values, doesn't add/remove text characters; `htmlToPlainWithOffsets` is run on the same inlined html, so the lookup is self-consistent.

3. **Existing flat-index tests in `epubx_renderer_test.dart`**: If any existing test asserts `TocEntry.locator.chapterIndex == flatIndex` (i.e., expects 3 navPoints → chapterIndex 0/1/2), it will break after dedup. Task 3 Step 4's full-suite run will catch this; the fix is to update the test expectation to deduped indices (or change the fixture so each chapter has a unique ContentFileName).

4. **MD/TXT path regression**: `_contentFileToChapterIndex` stays empty for `openChapters` path (no ContentFileName). `_locatorForChapter` falls back to `dedupedIdx = 0` and `charOffset = 0` — but MD/TXT path uses `_flatChaptersToToc` (line 752) instead of `_chaptersToToc`, so `_locatorForChapter` is never called. **Mitigation**: verify in Task 4 Step 1's full-suite run that MD/TXT renderer tests still pass.

5. **`_countFlat` unused warning**: The rewritten `_chaptersToToc` no longer uses `_countFlat`. Leaving it produces an analyzer warning. **Decision**: keep it as defensive helper (future callers may need flat-index count); accept the warning rather than delete + risk breaking tests that reference it.

## Verification summary

| Check | Command | Expected |
|---|---|---|
| New utility tests | `flutter test test/plain_text_utils_test.dart` | All pass |
| Dedup tests | `flutter test test/epubx_renderer_test.dart --plain-name dedupe` | 2 pass |
| Anchor TOC tests | `flutter test test/epubx_renderer_anchor_toc_test.dart` | 6 pass |
| Renderer regression | `flutter test` (from `reader_engine_epub_view/`) | No regression |
| App full suite | `flutter test --reporter=compact` (from `app/`) | 1483+ pass, 10 baseline fail unchanged |
| Manual: 道德经 | Open book + click TOC entries | Scrolls to correct positions |
| Manual: 与天为敌 | Open book + click TOC entries | No regression |
| Manual: PDF book | Open book + click TOC | No regression |
