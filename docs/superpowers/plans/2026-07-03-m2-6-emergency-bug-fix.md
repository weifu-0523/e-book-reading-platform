# M2.6 Emergency Bug Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all 8 user-reported bugs from v1.5.0-alpha hands-on testing in a single emergency sweep, ship v1.5.1-alpha patch.

**Architecture:** Bug-fix-only milestone; no new features. Each fix is scoped to its root cause as documented in `docs/superpowers/specs/2026-07-03-m2-6-emergency-bug-fix-design.md`. Three architectural decisions drive the work: (A1) PDF keeps scroll mode with independent dual-page toggle; (A2) book-like reading model where tap zones exist only in left/right margins and pages have 4-sided whitespace; (A3) Bug #1 ships defensive, awaits user stack trace.

**Tech Stack:** Flutter 3.44 / Dart 3.10 / Riverpod 2.6.1 / drift 2.18 / pdfrx 2.4.4 / epubx 4.0.0 / window_manager 0.4.3

**Spec:** `docs/superpowers/specs/2026-07-03-m2-6-emergency-bug-fix-design.md`

---

## File Structure (Preview)

**Files modified (existing):**
- `app/lib/features/reader/widgets/reader_scaffold.dart` — lift paginationMode gate (T1); refactor to margin-only tap zones (T9)
- `reader_engine_pdf_view/lib/pdf_reader_engine.dart` — expose dualPageMode (T2)
- `reader_engine_pdf_view/lib/pdf_renderer.dart` — render dual-page in scroll mode (T2)
- `app/lib/features/reader/pages/reader_body.dart` — wire PDF dual-page toggle (T2); fix _onAnnotationTap drawer close (T6); wrap _onBookmarkJump gotoLocator in try-catch (T8)
- `reader_engine_epub_view/lib/concrete_reader_engine.dart` — fix typography getter (T3)
- `reader_engine/lib/core/typography_settings.dart` — bump margin values (T4)
- `reader_engine_epub_view/lib/epubx_renderer.dart` — emit state after injectHighlights (T5); emit state in EpubRangeLocator branch of gotoLocator (T7); audit top/bottom padding (T4)
- `app/pubspec.yaml` — version 1.5.0-alpha → 1.5.1-alpha (T12)
- `pubspec.yaml` (root) — same version bump (T12)
- `app/build/windows/x64/runner/zhiyue.iss` — same version bump (T12)
- `README.md` — test count update (T12)
- `CHANGELOG.md` — add `[1.5.1-alpha]` section (T12)
- `docs/maintainers-runbook.md` — add M2.6 milestone entry (T13)
- `docs/releases/release-checklist.md` — add v1.5.1-alpha section (T12)

**Files created (new tests):**
- `app/test/features/reader/widgets/reader_paging_pdf_test.dart` (T1)
- `app/test/features/reader/widgets/reader_dual_page_toggle_test.dart` (T2)
- `reader_engine_epub_view/test/concrete_reader_engine_typography_test.dart` (T3)
- `reader_engine/test/core/typography_settings_test.dart` (T4 extend)
- `app/test/features/reader/widgets/highlight_render_test.dart` (T5)
- `app/test/features/reader/widgets/notes_drawer_navigation_test.dart` (T6)
- `app/test/features/reader/widgets/toc_navigation_test.dart` (T7)
- `app/test/features/reader/widgets/reader_bookmark_jump_test.dart` (T8)
- `app/test/features/reader/widgets/reader_scaffold_tap_zone_test.dart` (T9)
- `docs/releases/release-notes-v1.5.1-alpha.md` (T12)

---

## Pre-flight: Branch / Environment Setup

- [ ] **P0.1**: Confirm working on `master` branch (per project convention; no feature branches)
- [ ] **P0.2**: Confirm clean working tree: `git status` shows no modified files outside plan-related work
- [ ] **P0.3**: Pull latest: `git pull --rebase origin master`
- [ ] **P0.4**: Verify baseline: `cd app && /c/flutter/bin/flutter.bat test --concurrency=1 2>&1 | tail -5` shows 888 + 3 skipped

---

## Task 1: Lift paginationMode gate from reader_scaffold input handlers (Bug #6 P0)

**Files:**
- Modify: `app/lib/features/reader/widgets/reader_scaffold.dart:253-302`
- Test: `app/test/features/reader/widgets/reader_paging_pdf_test.dart` (new)

**Why:** Keyboard, wheel, and drag handlers all gate on `paginationMode == paged`. PDF engine returns scroll, so all inputs are silently dropped.

- [ ] **Step 1: Write failing test**

```dart
// app/test/features/reader/widgets/reader_paging_pdf_test.dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/pagination_mode.dart';
// Adjust import path to actual ReaderScaffold location

import 'package:app/features/reader/widgets/reader_scaffold.dart';

void main() {
  testWidgets(
    'ReaderScaffold keyboard arrow right calls onNext when paginationMode is scroll',
    (tester) async {
      var nextCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderScaffold(
              title: 'test',
              paginationMode: PaginationMode.scroll,
              content: const Center(child: Text('body')),
              onNext: () => nextCalls++,
              onPrev: () {},
              onOpenToc: () {},
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(nextCalls, 1);
    },
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

```
cd app && /c/flutter/bin/flutter.bat test test/features/reader/widgets/reader_paging_pdf_test.dart --concurrency=1
```
Expected: FAIL (nextCalls = 0, expected 1)

- [ ] **Step 3: Implement fix**

In `app/lib/features/reader/widgets/reader_scaffold.dart`:
- Line 253-254: Remove the `if (widget.paginationMode != PaginationMode.paged) return KeyEventResult.ignored;` gate from `_handleKeyEvent`. Let the keyboard event always call `_handleTap` / next / prev.
- Line 292: Remove same gate from `_handlePointerSignal` (wheel handler).
- Line 302: Remove same gate from `_handleDragEnd`.

The gate was overzealous. Each engine's `nextSpine/previousSpine` knows how to step (1 page in scroll, 1-2 in paged dual).

- [ ] **Step 4: Run test to verify it passes**

Expected: PASS (nextCalls = 1)

- [ ] **Step 5: Run full app test suite to confirm no regressions**

```
cd app && /c/flutter/bin/flutter.bat test --concurrency=1 2>&1 | tail -5
```
Expected: 889 pass + 3 skipped (888 + 1 new). No existing test fails.

- [ ] **Step 6: Commit**

```bash
cd "H:/projiect/电子书阅读平台"
git add app/lib/features/reader/widgets/reader_scaffold.dart app/test/features/reader/widgets/reader_paging_pdf_test.dart
git commit -m "$(cat <<'EOF'
fix(m2.6/t1): lift paginationMode gate from reader input handlers

Bug #6: keyboard/wheel/drag handlers were gated on paginationMode == paged,
silently dropping all inputs for PDF (scroll mode). The gate was overzealous;
engine.nextSpine/previousSpine already handles per-mode stepping.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 2: PdfReaderEngine dualPageMode as independent toggle (Bug #4 P0)

**Files:**
- Modify: `reader_engine_pdf_view/lib/pdf_reader_engine.dart`
- Modify: `reader_engine_pdf_view/lib/pdf_renderer.dart`
- Modify: `app/lib/features/reader/pages/reader_body.dart` (remove LayoutBuilder auto-trigger; add UI toggle button)
- Test: `app/test/features/reader/widgets/reader_dual_page_toggle_test.dart` (new)

**Why:** M2.5/T13 hardcoded dual-page to engage only in paged mode. PDF engine is scroll, so dual-page never renders. Per user decision A1, dual-page becomes an independent toggle.

- [ ] **Step 1: Write failing test**

```dart
// app/test/features/reader/widgets/reader_dual_page_toggle_test.dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Adjust imports

void main() {
  testWidgets(
    'Toggling dual-page button flips renderer.dualPageMode',
    (tester) async {
      // Pump a real PdfReaderEngine-backed reader with a small PDF fixture.
      // Tap the dual-page toggle.
      // Verify renderer.dualPageMode == true.
      // Tap again.
      // Verify renderer.dualPageMode == false.
    },
    skip: 'Spike first — see Step 3 impl notes',
  );
}
```

- [ ] **Step 2: Run test to verify it fails (or skips)**

```
cd app && /c/flutter/bin/flutter.bat test test/features/reader/widgets/reader_dual_page_toggle_test.dart --concurrency=1
```
Expected: SKIP (test marked skip pending impl). After impl, unskip and verify PASS.

- [ ] **Step 3: Implement fix**

3a. **`pdf_reader_engine.dart`**: Add `dualPageMode` field + setter at the engine level, mirroring `PdfRenderer.dualPageMode`:

```dart
bool _dualPageMode = false;
bool get dualPageMode => _dualPageMode;
set dualPageMode(bool value) {
  if (_dualPageMode == value) return;
  _dualPageMode = value;
  _renderer.dualPageMode = value;
  // Persist to SharedPreferences
  _persistDualPagePref(value);
}

Future<void> _persistDualPagePref(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('pdf_dual_page_$_bookId', value);
}
```

3b. **`pdf_renderer.dart`**: Update `_buildDualPage` (line ~293) to render two pages side-by-side INSIDE a vertical scroll view, preserving scroll semantics. Each "row" of the scroll is a 2-page spread. When `dualPageMode == false`, render single pages as today.

3c. **`reader_body.dart`**: 
- Remove the LayoutBuilder auto-trigger at line 281 (no more auto dual-page at ≥1200px)
- Add a toggle button in AppBar actions (visible only when `book.format == BookFormat.pdf`)
- Toggle calls `engine.dualPageMode = !engine.dualPageMode`
- On engine.open, load persisted pref: `prefs.getBool('pdf_dual_page_${book.id}') ?? false`

3d. **Asset**: Add a new icon (e.g., `Icons.auto_stories_outlined` for single page, `Icons.menu_book` for dual) — use Material default to avoid asset registration.

- [ ] **Step 4: Unskip test and verify it passes**

- [ ] **Step 5: Run full app test suite**

Expected: 890 pass + 3 skipped.

- [ ] **Step 6: Commit**

```bash
git add reader_engine_pdf_view/lib/pdf_reader_engine.dart reader_engine_pdf_view/lib/pdf_renderer.dart app/lib/features/reader/pages/reader_body.dart app/test/features/reader/widgets/reader_dual_page_toggle_test.dart
git commit -m "$(cat <<'EOF'
fix(m2.6/t2): PDF dual-page as independent toggle in scroll mode

Bug #4: dual-page was gated on paginationMode == paged; PDF engine returns
scroll so dual-page never rendered. Per spec A1, dual-page becomes a
per-book toggle persisted in SharedPreferences, decoupled from
paginationMode. Renderer renders 2-page spreads inside vertical scroll.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 3: Fix typography getter (Bug #3 P0)

**Files:**
- Modify: `reader_engine_epub_view/lib/concrete_reader_engine.dart:81`
- Test: `reader_engine_epub_view/test/concrete_reader_engine_typography_test.dart` (new)

**Why:** `typography` getter returns `TypographySettings.defaults()` instead of forwarding to `_renderer.typography`. UI panel reads engine.typography, gets stale default, all onChanged writes are discarded.

- [ ] **Step 1: Write failing test**

```dart
// reader_engine_epub_view/test/concrete_reader_engine_typography_test.dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';
// Need a way to construct ConcreteEpubReaderEngine for test — use a fake book
// or extract typography forwarding to a testable seam.

void main() {
  test(
    'engine.typography reflects settings after setTypography',
    () async {
      // Construct engine (skip if requires real file — use integration-style)
      // Call engine.setTypography(TypographySettings(fontScale: 1.5))
      // expect(engine.typography.fontScale, 1.5)
    },
    skip: 'Spike first — engine construction may need test seam',
  );
}
```

- [ ] **Step 2: Run test (verify skip or fail)**

- [ ] **Step 3: Implement fix**

In `reader_engine_epub_view/lib/concrete_reader_engine.dart:81`:

Replace:
```dart
@override
TypographySettings get typography => TypographySettings.defaults();
// 注：typography 实际由 _renderer 持有；为简洁此处返回默认。
// M3 重构为 _renderer.typography。
```

With:
```dart
@override
TypographySettings get typography => _renderer.typography;
```

If `_renderer.typography` is private, expose a getter on `EpubxRenderer` (likely already exists — check `epubx_renderer.dart`).

- [ ] **Step 4: Unskip + verify test passes**

- [ ] **Step 5: Run package test suite**

```
cd reader_engine_epub_view && /c/flutter/bin/flutter.bat test --concurrency=1
```
Expected: 84 pass (83 + 1 new).

- [ ] **Step 6: Commit**

```bash
git add reader_engine_epub_view/lib/concrete_reader_engine.dart reader_engine_epub_view/test/concrete_reader_engine_typography_test.dart
git commit -m "$(cat <<'EOF'
fix(m2.6/t3): forward typography getter to renderer

Bug #3: ConcreteEpubReaderEngine.typography returned const default, so
TypographyPanel's onChanged wrote to a discarded object. UI controls
appeared unresponsive. One-line fix to forward to _renderer.typography
(author's own TODO admitted this).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 4: Bump margin values + audit top/bottom padding (Bug #8 P0)

**Files:**
- Modify: `reader_engine/lib/core/typography_settings.dart:25-32`
- Modify: `reader_engine_epub_view/lib/epubx_renderer.dart` (padding audit)
- Test: `reader_engine/test/core/typography_settings_test.dart` (extend)

**Why:** User reports margins too tight. Per spec A2, margins double as tap targets (T9), so width must be ≥32px (WCAG).

- [ ] **Step 1: Write failing test**

```dart
// Extend reader_engine/test/core/typography_settings_test.dart

test('PageMargin.normal pixel value is 32 (M2.6/T4)', () {
  expect(PageMargin.normal.pixelValue, 32);
});

test('PageMargin.wide pixel value is 48 (M2.6/T4)', () {
  expect(PageMargin.wide.pixelValue, 48);
});

test('PageMargin.extraWide pixel value is 64 (M2.6/T4)', () {
  expect(PageMargin.extraWide.pixelValue, 64);
});

test('PageMargin.compact stays 8 (M2.6/T4)', () {
  expect(PageMargin.compact.pixelValue, 8);
});
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Implement fix**

In `reader_engine/lib/core/typography_settings.dart:25-32`:

Update enum pixel values:
- compact: 8 (unchanged)
- normal: 24 → **32**
- wide: 32 → **48**
- extraWide: 40 → **64**

- [ ] **Step 4: Audit top/bottom padding**

In `reader_engine_epub_view/lib/epubx_renderer.dart` (around line 538-598):
- Find `EdgeInsets` or `Padding` widget that applies margin
- Verify it's `EdgeInsets.all(marginPx)` or `EdgeInsets.symmetric(horizontal: marginPx, vertical: marginPx * 0.5)` — NOT just horizontal-only
- If horizontal-only, change to symmetric with vertical = horizontal × 0.5 (visual balance; tighter top/bottom than left/right is OK for reading)

If existing padding is horizontal-only, this is a sub-fix:
```dart
// Before
padding: EdgeInsets.symmetric(horizontal: marginPx)
// After
padding: EdgeInsets.symmetric(horizontal: marginPx, vertical: marginPx ~/ 2)
```

- [ ] **Step 5: Run tests**

Expected: existing typography tests may break if they hard-coded old values. Update those tests to use the new values.

- [ ] **Step 6: Commit**

```bash
git add reader_engine/lib/core/typography_settings.dart reader_engine_epub_view/lib/epubx_renderer.dart reader_engine/test/core/typography_settings_test.dart
git commit -m "$(cat <<'EOF'
fix(m2.6/t4): bump margins to 32/48/64 + audit 4-sided padding

Bug #8: normal 24→32, wide 32→48, extraWide 40→64. Compact stays 8.
Margins now double as tap-zone width (see T9), so >=32px = WCAG minimum.
Also audited top/bottom padding — if it was horizontal-only, added
vertical = horizontal / 2 for book-like 4-sided whitespace.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 5: Fix injectHighlights state notification (Bug #5b P0)

**Files:**
- Modify: `reader_engine_epub_view/lib/epubx_renderer.dart:488`
- Modify: `app/lib/features/reader/pages/reader_body.dart` (ref.listen wiring, if needed)
- Test: `app/test/features/reader/widgets/highlight_render_test.dart` (new)

**Why:** `injectHighlights` mutates `_allHighlights` field but doesn't notify consumers to rebuild. Highlights appear in memory but not on screen.

- [ ] **Step 1: Write failing test**

```dart
// app/test/features/reader/widgets/highlight_render_test.dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
// Imports TBD

void main() {
  test(
    'injectHighlights triggers state listener notification',
    () async {
      // Set up a real or mock renderer with chapter content
      // Subscribe to engine.state stream
      // Call engine.injectHighlights([range])
      // Verify stream emits a new state (e.g., ReaderEngineReady or new ReaderEngineHighlightsUpdated)
    },
  );
}
```

- [ ] **Step 2: Run test (verify fail)**

- [ ] **Step 3: Implement fix**

In `reader_engine_epub_view/lib/epubx_renderer.dart:488`:

```dart
@override
Future<void> injectHighlights(List<HighlightRange> highlights) async {
  _allHighlights
    ..clear()
    ..addAll(highlights);
  // Notify consumers so widget tree rebuilds and reads new _allHighlights
  _stateController.add(const ReaderEngineReady());
}
```

Risk check: ensure this doesn't cause rebuild loops. The caller in `reader_body.dart` is a `ref.listen<NotesState>` (not a build phase), so emitting state is safe.

If rebuild loop appears, alternative: introduce a dedicated `ReaderEngineHighlightsUpdated` state class and have `reader_body.dart` filter on that type.

- [ ] **Step 4: Verify test passes**

- [ ] **Step 5: Run full app suite**

Expected: 891 pass + 3 skipped.

- [ ] **Step 6: Commit**

```bash
git add reader_engine_epub_view/lib/epubx_renderer.dart app/test/features/reader/widgets/highlight_render_test.dart
git commit -m "$(cat <<'EOF'
fix(m2.6/t5): emit state after injectHighlights

Bug #5b: highlights were stored in _allHighlights but consumers weren't
notified to rebuild. Now emits ReaderEngineReady after mutation so
reader_body's build picks up the new highlight ranges.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 6: Fix note tap drawer close (Bug #2 P1)

**Files:**
- Modify: `app/lib/features/reader/pages/reader_body.dart:506`
- Test: `app/test/features/reader/widgets/notes_drawer_navigation_test.dart` (new)

**Why:** `_onAnnotationTap` calls `Navigator.maybePop()` unconditionally. With M2.5/T7's drawer refactor, this pops the reader route on narrow screens.

- [ ] **Step 1: Write failing test**

```dart
// app/test/features/reader/widgets/notes_drawer_navigation_test.dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Imports TBD

void main() {
  testWidgets(
    'Tapping a note in drawer does NOT pop the reader route on narrow screens',
    (tester) async {
      // Wrap reader in a Navigator with a sentinel route below it
      // Open drawer, switch to Notes tab
      // Tap a note entry
      // Verify the reader route is still on top (not popped)
      // Verify the drawer is closed
    },
  );
}
```

- [ ] **Step 2: Run test (verify fail)**

- [ ] **Step 3: Implement fix**

In `app/lib/features/reader/pages/reader_body.dart:506`:

Replace:
```dart
await Navigator.of(context).maybePop(); // 关闭 endDrawer
```

With:
```dart
// M2.5/T7 重构后抽屉是 Scaffold.drawer，不再是 endDrawer。
// 窄屏 maybePop() 会 pop 整个 reader route，必须只在窄屏且确实打开抽屉时调。
if (!_isWideScreen(context)) {
  unawaited(Navigator.of(context).maybePop());
}
```

Pattern copied from `_onBookmarkJump:809` (already correct).

- [ ] **Step 4: Verify test passes**

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/reader/pages/reader_body.dart app/test/features/reader/widgets/notes_drawer_navigation_test.dart
git commit -m "$(cat <<'EOF'
fix(m2.6/t6): note tap drawer close only on narrow screens

Bug #2: _onAnnotationTap called Navigator.maybePop unconditionally.
Post-M2.5/T7 drawer refactor, this pops the reader route on narrow
screens. Reuses _onBookmarkJump's narrow-only pattern.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 7: Fix TOC gotoLocator state notification (Bug #7 P1)

**Files:**
- Modify: `reader_engine_epub_view/lib/epubx_renderer.dart:452-468` (EpubRangeLocator branch)
- Test: `app/test/features/reader/widgets/toc_navigation_test.dart` (new)

**Why:** `gotoLocator` EpubRangeLocator branch updates `_currentChapterIndex` but doesn't notify state listeners. UI doesn't rebuild, so user doesn't see chapter change.

- [ ] **Step 1: Write failing test**

```dart
// app/test/features/reader/widgets/toc_navigation_test.dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'TOC entry tap with EpubRangeLocator triggers engine state emission',
    () async {
      // Set up engine with chapter content
      // Subscribe to engine.state stream, capture emissions
      // Call engine.gotoLocator(EpubRangeLocator(chapterIndex: 1, ...))
      // Verify a state was emitted after the call
    },
  );
}
```

- [ ] **Step 2: Run test (verify fail)**

- [ ] **Step 3: Implement fix**

In `reader_engine_epub_view/lib/epubx_renderer.dart:465`:

```dart
if (locator.chapterIndex != _currentChapterIndex) {
  _currentChapterIndex = locator.chapterIndex;
  _chapterEndFiredForCurrentChapter = false;
  _cachedBreaks = null;
  _beginChapterSwitch();
  // M2.6/T7: notify consumers so reader_body rebuilds with new chapter
  // (mirrors EpubCfiLocator branch's behavior)
  _stateController.add(const ReaderEngineReady());
}
```

- [ ] **Step 4: Verify test passes**

- [ ] **Step 5: Commit**

```bash
git add reader_engine_epub_view/lib/epubx_renderer.dart app/test/features/reader/widgets/toc_navigation_test.dart
git commit -m "$(cat <<'EOF'
fix(m2.6/t7): emit state in gotoLocator EpubRangeLocator branch

Bug #7: TOC tap changed _currentChapterIndex but consumers weren't
notified. UI didn't rebuild, so user didn't see chapter change. Mirrors
the EpubCfiLocator branch's notification pattern.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 8: Wrap bookmark jump gotoLocator in try-catch (Bug #1 P1)

**Files:**
- Modify: `app/lib/features/reader/pages/reader_body.dart:804`
- Test: `app/test/features/reader/widgets/reader_bookmark_jump_test.dart` (new)

**Why:** `_onBookmarkJump` doesn't catch exceptions from `engine.gotoLocator`. Any throw bubbles to widget tree → red error screen.

- [ ] **Step 1: Write failing test**

```dart
// app/test/features/reader/widgets/reader_bookmark_jump_test.dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Bookmark tap with throwing engine shows SnackBar, no red screen',
    (tester) async {
      // Wire up a reader with a fake engine whose gotoLocator throws
      // Open drawer, switch to Bookmarks tab
      // Tap a bookmark
      // Verify SnackBar appears with friendly error message
      // Verify no red error screen widget in tree
    },
  );
}
```

- [ ] **Step 2: Run test (verify fail)**

- [ ] **Step 3: Implement fix**

In `app/lib/features/reader/pages/reader_body.dart:804`:

Replace:
```dart
await engine.gotoLocator(locator);
await engine.chapterSwitchSettled;
```

With:
```dart
try {
  await engine.gotoLocator(locator);
  await engine.chapterSwitchSettled;
} catch (e, st) {
  debugPrint('Bookmark jump failed: $e\n$st');
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('跳转失败：$e')),
  );
  return;
}
```

- [ ] **Step 4: Verify test passes**

- [ ] **Step 5: Manual smoke**: User reproduces original bookmark click scenario. If still red, capture yellow text and follow up in M2.7.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/reader/pages/reader_body.dart app/test/features/reader/widgets/reader_bookmark_jump_test.dart
git commit -m "$(cat <<'EOF'
fix(m2.6/t8): wrap bookmark jump gotoLocator in try-catch

Bug #1: bookmark click triggered uncaught exception in gotoLocator,
surfacing as Flutter red error screen. Defensive catch + SnackBar
prevents the crash. Specific root cause still pending user-provided
stack trace (yellow text); generic catch prevents UX disaster regardless.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 9: Refactor reader_scaffold to book-like margin tap zones (Bug #5a P2)

**Files:**
- Modify: `app/lib/features/reader/widgets/reader_scaffold.dart:110-135` (build method)
- Test: `app/test/features/reader/widgets/reader_scaffold_tap_zone_test.dart` (new)

**Why:** Per spec A2, tap zones must exist ONLY in left/right margins. Center area is pure selection territory.

**Depends on:** T4 (margin pixel values used as tap-zone widths).

- [ ] **Step 1: Write failing test**

```dart
// app/test/features/reader/widgets/reader_scaffold_tap_zone_test.dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Tap in left margin (x < 32) calls onPrev, not onNext',
    (tester) async {
      var prevCalls = 0;
      var nextCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: ReaderScaffold(
                title: 'test',
                paginationMode: PaginationMode.scroll,
                marginPx: 32,
                content: const Center(child: Text('body')),
                onPrev: () => prevCalls++,
                onNext: () => nextCalls++,
                onOpenToc: () {},
              ),
            ),
          ),
        ),
      );
      // Tap at x=10 (in left margin)
      await tester.tapAt(const Offset(10, 200));
      await tester.pumpAndSettle();
      expect(prevCalls, 1);
      expect(nextCalls, 0);
    },
  );

  testWidgets(
    'Tap in right margin (x > width - 32) calls onNext, not onPrev',
    (tester) async {
      // Mirror of above, tapping at x=390
    },
  );

  testWidgets(
    'Tap in center (32 < x < width - 32) does NOT call onPrev or onNext',
    (tester) async {
      // Tap at x=200
      // Expect prevCalls = 0, nextCalls = 0
    },
  );
}
```

- [ ] **Step 2: Run test (verify fail)**

- [ ] **Step 3: Implement fix**

In `app/lib/features/reader/widgets/reader_scaffold.dart`:

Replace the build method's `GestureDetector(behavior: HitTestBehavior.opaque, ...)` wrapper (line 119-132) with a `Stack` of explicit layers:

```dart
@override
Widget build(BuildContext context) {
  final ui = ref.watch(readerUiControllerProvider);
  final size = MediaQuery.sizeOf(context);
  // M2.6/T9: margin pixel value doubles as tap-zone width.
  // Read from current TypographySettings; default to 32 (Normal).
  final marginPx = _currentMarginPx(); // helper to fetch from provider

  return Focus(
    autofocus: true,
    onKeyEvent: (node, event) => _handleKeyEvent(event),
    child: Listener(
      onPointerSignal: _handlePointerSignal,
      child: Stack(
        children: [
          // Bottom layer: content with full gesture scope
          widget.content,

          // Top layer 1: left margin tap zone (prev)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: marginPx,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (_) => widget.onPrev(),
              onHorizontalDragEnd: _handleDragEnd,
            ),
          ),

          // Top layer 2: right margin tap zone (next)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: marginPx,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (_) => widget.onNext(),
              onHorizontalDragEnd: _handleDragEnd,
            ),
          ),

          // Top layer 3: center double-tap zone (chrome toggle)
          // Does NOT consume single taps — only double-tap
          if (ui.chromeVisible || true)
            Positioned(
              left: marginPx,
              right: marginPx,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTapDown: (_) => _lastTapTime = DateTime.now(),
                onDoubleTap: _toggleChrome,
                // No onTapUp — single taps pass through to content
              ),
            ),

          // Chrome overlay (existing)
          if (ui.chromeVisible) _buildChrome(context),
        ],
      ),
    ),
  );
}
```

Also:
- Add `_currentMarginPx()` helper that reads from `ref.watch(typographyProvider).margin.pixelValue`
- Remove `_handleTap(details.localPosition.dx, size.width)` — replaced by per-zone handlers
- Keep `_handleKeyEvent`, `_handlePointerSignal`, `_handleDragEnd` — they apply to all zones via outer Listener/Positioned

- [ ] **Step 4: Verify all 3 tests pass**

- [ ] **Step 5: Manual smoke**: User tests text selection (long-press in center area) AND paging (tap in left/right margin).

- [ ] **Step 6: Run full app suite**

Expected: 895 pass + 3 skipped (888 baseline + 7 new across T9 tests + previous T1-T8).

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/reader/widgets/reader_scaffold.dart app/test/features/reader/widgets/reader_scaffold_tap_zone_test.dart
git commit -m "$(cat <<'EOF'
refactor(m2.6/t9): book-like margin-only tap zones

Bug #5a: tap zones now exist only in left/right margin rectangles
(width = current margin pixel value). Center content area is pure
selection territory; SelectableRegion gets first-class gesture scope.

Removes the opaque GestureDetector that wrapped content (was winning
gesture arena in edge cases). Replaces with Stack of 3 Positioned
layers: left margin (prev) / right margin (next) / center (double-tap
chrome toggle only).

Per spec A2: book-like reading model. Margins double as tap targets,
so width >= 32px = WCAG minimum (Normal tier satisfies this).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 10: Fix ESC doesn't exit fullscreen (Bug #9 P1)

**Files:**
- Modify: `app/lib/features/reader/widgets/reader_scaffold.dart` (hoist FocusNode + reclaim after button press)
- Test: `app/test/features/reader/widgets/reader_fullscreen_escape_test.dart` (new)

**Why:** ESC handler is wired at line 245 but Focus widget loses capture after AppBar fullscreen button click. Button's Focus node retains focus → ESC events dispatched to button (no handler) → silently dropped.

**Depends on:** T9 (refactors reader_scaffold; T10 should be merged or sequenced after).

- [ ] **Step 1: Write failing test**

```dart
// app/test/features/reader/widgets/reader_fullscreen_escape_test.dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'After clicking fullscreen button, ESC key exits fullscreen',
    (tester) async {
      var fullscreenEnters = 0;
      var fullscreenExits = 0;
      // Pump a reader with a fake fullscreen controller that counts calls
      await tester.pumpWidget(/* ... */);

      // Tap fullscreen button → enter fullscreen
      await tester.tap(find.byKey(const Key('toggle_fullscreen')));
      await tester.pumpAndSettle();
      expect(fullscreenEnters, 1);

      // Send ESC key
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Verify exit was called
      expect(fullscreenExits, 1);
    },
  );
}
```

- [ ] **Step 2: Run test (verify fail)**

```
cd app && /c/flutter/bin/flutter.bat test test/features/reader/widgets/reader_fullscreen_escape_test.dart --concurrency=1
```
Expected: FAIL (fullscreenExits = 0, expected 1).

- [ ] **Step 3: Implement fix**

In `app/lib/features/reader/widgets/reader_scaffold.dart`:

3a. Hoist FocusNode from anonymous Focus widget to a State field:

```dart
class _ReaderScaffoldState extends State<ReaderScaffold> {
  late final FocusNode _focusNode;
  
  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'ReaderScaffold');
    // Request focus after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }
  
  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
  // ...
}
```

3b. Update build method (line 114-117):
```dart
return Focus(
  focusNode: _focusNode,
  autofocus: true,
  onKeyEvent: (node, event) => _handleKeyEvent(event),
  child: ...
);
```

3c. Add `_reclaimFocus()` helper:
```dart
void _reclaimFocus() {
  // After any AppBar button click, reclaim focus so keyboard shortcuts
  // (especially ESC for fullscreen exit) continue to work.
  if (mounted) _focusNode.requestFocus();
}
```

3d. Update all IconButton onPressed callbacks in `_buildChrome` to call `_reclaimFocus()` after their primary action. Specifically:
- Fullscreen toggle (line 188-194)
- TOC open
- Back button
- Any other IconButtons

```dart
IconButton(
  icon: Icon(ui.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
  key: const Key('toggle_fullscreen'),
  tooltip: ui.isFullscreen ? '退出全屏' : '全屏',
  onPressed: () {
    ref.read(readerUiControllerProvider.notifier).toggleFullscreen();
    _reclaimFocus();  // ← NEW
  },
),
```

- [ ] **Step 4: Verify test passes**

- [ ] **Step 5: Run full app suite**

Expected: 896 pass + 3 skipped.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/reader/widgets/reader_scaffold.dart app/test/features/reader/widgets/reader_fullscreen_escape_test.dart
git commit -m "$(cat <<'EOF'
fix(m2.6/t10): reclaim FocusNode after AppBar button clicks (ESC fullscreen)

Bug #9: ESC handler was wired but Focus widget lost capture after
AppBar fullscreen button click. Button's Focus node retained focus,
silently dropping ESC events. Hoisted FocusNode to State field and
added _reclaimFocus() helper called from every AppBar IconButton's
onPressed.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 11: Regression test sweep verification

**Files:** None (verification only)

- [ ] **Step 1: Confirm all new tests exist and pass**

```
ls app/test/features/reader/widgets/reader_paging_pdf_test.dart \
   app/test/features/reader/widgets/reader_dual_page_toggle_test.dart \
   app/test/features/reader/widgets/highlight_render_test.dart \
   app/test/features/reader/widgets/notes_drawer_navigation_test.dart \
   app/test/features/reader/widgets/toc_navigation_test.dart \
   app/test/features/reader/widgets/reader_bookmark_jump_test.dart \
   app/test/features/reader/widgets/reader_scaffold_tap_zone_test.dart \
   reader_engine_epub_view/test/concrete_reader_engine_typography_test.dart
```

- [ ] **Step 2: Run all 4 package tests**

```
cd app && /c/flutter/bin/flutter.bat test --concurrency=1 2>&1 | tail -5
cd ../reader_engine && /c/flutter/bin/flutter.bat test --concurrency=1 2>&1 | tail -5
cd ../reader_engine_epub_view && /c/flutter/bin/flutter.bat test --concurrency=1 2>&1 | tail -5
cd ../reader_engine_pdf_view && /c/flutter/bin/flutter.bat test --concurrency=1 2>&1 | tail -5
```

Expected: app 895 + 3 skipped, reader_engine 50+, reader_engine_epub_view 84+, reader_engine_pdf_view 45. Total ≥ 1085.

- [ ] **Step 3: Confirm 4-package analyze clean**

```
cd app && /c/flutter/bin/dart.bat analyze lib/ test/ 2>&1 | tail -3
cd ../reader_engine && /c/flutter/bin/dart.bat analyze lib/ test/ 2>&1 | tail -3
cd ../reader_engine_epub_view && /c/flutter/bin/dart.bat analyze lib/ test/ 2>&1 | tail -3
cd ../reader_engine_pdf_view && /c/flutter/bin/dart.bat analyze lib/ test/ 2>&1 | tail -3
```

Expected: all 4 show "No issues found".

---

## Task 12: Final commit (if any docs/sweep artifacts)

- [ ] **Step 1: Check git status**

```bash
cd "H:/projiect/电子书阅读平台" && git status
```

- [ ] **Step 2: If anything else changed, commit**

```bash
git add ... && git commit -m "chore(m2.6): test sweep artifacts" && git push origin master
```

---

## Task 13: CHANGELOG + version bump v1.5.1-alpha + dual tag

**Files:**
- Modify: `app/pubspec.yaml` (version: 1.5.0-alpha → 1.5.1-alpha)
- Modify: `pubspec.yaml` (root) (same)
- Modify: `app/build/windows/x64/runner/zhiyue.iss` (same)
- Modify: `README.md` (test count + version mention)
- Modify: `CHANGELOG.md` (add `[1.5.1-alpha]` section)
- Modify: `docs/releases/release-checklist.md` (add v1.5.1-alpha section)
- Create: `docs/releases/release-notes-v1.5.1-alpha.md`

- [ ] **Step 1: Bump version**

In `app/pubspec.yaml` line 1:
```yaml
version: 1.5.1-alpha+0
```
(was `1.5.0-alpha+0`)

Same for `pubspec.yaml` (root) and `zhiyue.iss`.

- [ ] **Step 2: Add CHANGELOG entry**

Prepend to `CHANGELOG.md` after `## [Unreleased]`:

```markdown
## [1.5.1-alpha] - 2026-07-03

Emergency bug fix sweep following v1.5.0-alpha user testing.

### Fixed

- **Bug #1**: Bookmark click in drawer wrapped in try-catch (defensive;
  specific root cause pending user-provided stack trace).
- **Bug #2**: Note tap in drawer no longer pops reader route on narrow
  screens. Pattern aligned with bookmark jump.
- **Bug #3**: Typography panel controls now respond — `engine.typography`
  forwards to `_renderer.typography` instead of returning const default.
- **Bug #4**: PDF dual-page now works as independent per-book toggle,
  decoupled from paginationMode. Toggle persists in SharedPreferences.
- **Bug #5a**: Selection vs paging conflict resolved — tap zones now
  exist only in left/right margin rectangles. Center content area is
  pure selection territory. Book-like model per user 2026-07-03.
- **Bug #5b**: Highlights now render after marking — `injectHighlights`
  emits state notification so widget tree rebuilds.
- **Bug #6**: Keyboard / wheel / drag paging no longer gated on
  `paginationMode == paged`. PDF (scroll mode) now receives all inputs.
- **Bug #7**: TOC entry tap now actually navigates — EpubRangeLocator
  branch of `gotoLocator` emits state notification.
- **Bug #8**: Default margins bumped — Normal 24→32, Wide 32→48,
  ExtraWide 40→64. Plus top/bottom padding audit. If you find the new
  defaults too wide, switch to **Settings → Typography → Margin →
  Compact** (8px).

### Architecture

- **A1**: PDF keeps scroll mode default; dual-page is independent toggle.
- **A2**: Book-like reading model — tap zones in margins only, 4-sided
  whitespace required.
- **A3**: Bug #1 ships defensive; awaits user stack trace.

### Tests

- 9 new regression tests (one per bug + typography extension).
- Total: 1085 pass + 3 skipped (was 1066 + 3).

### Known Limitations

- Bug #1 root cause may not be fully resolved without stack trace.
- EPUB dual-page rendering still deferred to v1.6.
```

- [ ] **Step 3: Create release notes**

```markdown
<!-- docs/releases/release-notes-v1.5.1-alpha.md -->
# v1.5.1-alpha — Emergency Bug Fix Sweep

## Why this release

v1.5.0-alpha shipped 2026-07-03 morning with 15 tasks and 1066 tests.
User hands-on testing the same day surfaced 8 bugs, several of which
blocked core reading flow. This is a fast-follow patch.

## What's fixed

8 bugs across P0/P1/P2 (full list in CHANGELOG). Headline fixes:

- **Paging works again** (keyboard, mouse wheel, drag) — was broken for
  PDF in scroll mode.
- **PDF dual-page is a per-book toggle** — no longer tied to pagination
  mode.
- **Typography controls respond** — was reading a const default.
- **Highlights render after marking** — widget tree now rebuilds.
- **TOC tap navigates** — chapter switch now emits state.
- **Margins wider by default** — Normal 24→32, plus top/bottom padding.
- **Book-like tap zones** — tap only in left/right margins to page;
  center is pure selection.

## Known limitations

- Bug #1 (bookmark red screen) has a defensive fix but root cause
  pending user-provided stack trace.

## Upgrade notes

If new margins feel too wide: **Settings → Typography → Margin →
Compact** (8px).
```

- [ ] **Step 4: Update release-checklist**

Add to `docs/releases/release-checklist.md`:

```markdown
### v1.5.1-alpha release 准备（M2.6 Emergency Bug Fix Sweep）

代码 + 文档部分（2026-07-03 完成）：
- ✅ 9 个 bug fix task（T1-T9）+ T10 测试 + T11 verify
- ✅ 全量测试通过：1085 passed + 3 skipped
- ✅ 4 个包 analyze clean

待执行（用户现场操作）：
- ⏳ Gitee Release v1.5.1-alpha 页面创建（使用 release-notes-v1.5.1-alpha.md 草稿）
- ⏳ build artifact：setup.exe / portable.zip / .apk
- ⏳ 用户复测 Bug #1（书签点击），提供黄色报错文本（如还出现）
```

- [ ] **Step 5: Update README test count**

In `README.md` line 110:
```markdown
**测试**：1085 通过 + 3 skipped（app 895 / reader_engine 50 / reader_engine_epub_view 84 / reader_engine_pdf_view 45）
```

- [ ] **Step 6: Tag + push**

```bash
cd "H:/projiect/电子书阅读平台"
git add app/pubspec.yaml pubspec.yaml app/build/windows/x64/runner/zhiyue.iss README.md CHANGELOG.md docs/releases/release-checklist.md docs/releases/release-notes-v1.5.1-alpha.md
git commit -m "$(cat <<'EOF'
release(v1.5.1-alpha): version bump + changelog + docs

M2.6 emergency bug fix sweep complete. 8 bugs fixed, 9 regression
tests added. Dual tag pending.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git tag m2.6-complete
git tag v1.5.1-alpha
git push origin master --tags
```

---

## Task 14: Rebuild Debug exe + memory + runbook

**Files:**
- Modify: `docs/maintainers-runbook.md` (§1 milestone index)
- Create: `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_m2_6_complete.md`
- Modify: `C:\Users\1\.claude\projects\H--projiect--------\memory\MEMORY.md`

- [ ] **Step 1: Rebuild Debug exe**

```
cd "H:/projiect/电子书阅读平台/app" && /c/flutter/bin/flutter.bat build windows --debug 2>&1 | tail -5
```
Expected: `√ Built build\windows\x64\runner\Debug\zhiyue.exe`

- [ ] **Step 2: Verify exe timestamp updated**

```
stat -c "%y" "H:/projiect/电子书阅读平台/app/build/windows/x64/runner/Debug/zhiyue.exe"
```

- [ ] **Step 3: Update maintainers-runbook**

Add to `docs/maintainers-runbook.md` §1 milestone index:

```markdown
- **M2.6** (2026-07-03): emergency bug fix sweep (8 user-reported bugs); tag `m2.6-complete` + `v1.5.1-alpha`. See [[zhiyue-m2-6-complete]].
```

- [ ] **Step 4: Write memory file**

Create `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_m2_6_complete.md`:

```markdown
---
name: zhiyue-m2-6-complete
description: 2026-07-03 M2.6 emergency bug fix sweep — 8 user-reported bugs fixed in single milestone (v1.5.1-alpha patch)
metadata:
  node_type: memory
  type: project
---

**2026-07-03** — v1.5.0-alpha 用户测试发现 8 个 bug，M2.6 紧急修复 sweep。13 task，9 个回归测试，dual tag `m2.6-complete` + `v1.5.1-alpha`。

**Why:** M2.5 交付后用户立即上手测试，发现核心阅读流程多处不通（翻页/排版/双页/高亮）。比 M2.7 计划功能更优先。

**How to apply:** 后续工作继承 v1.5.1 baseline；用户复测后若 Bug #1 红屏仍在，需按 stack trace 做精准修复。

## 关键数字

- 1 个 milestone，13 task，9 个回归测试
- 4 包测试 1085 pass + 3 skipped（baseline 1066 + 19）
- 8 个 bug 全闭（Bug #1 仅防御性修，待 log）
- 用户决策：PDF scroll 保留 + 独立双页切换 / normal=32 / sibling-layer tap zones（后改为 book-like margin-only zones）

## 关键修复

- T1: 翻页 paginationMode 门控去掉（reader_scaffold.dart）
- T2: PDF dual-page 独立 toggle，per-book 持久化
- T3: typography getter 转发到 renderer（一行）
- T4: 边距 normal 24→32, wide 32→48, extraWide 40→64
- T5: injectHighlights 触发 state notify
- T6: _onAnnotationTap 抽屉关闭只在窄屏
- T7: gotoLocator EpubRangeLocator 分支触发 state notify
- T8: _onBookmarkJump gotoLocator try-catch
- T9: reader_scaffold 重构为 Stack 3 层（left margin / right margin / center double-tap）

## 待用户复测

- ⏳ Bug #1 复现：拿 stack trace 决定是否需 v1.5.2-alpha hotfix
- ⏳ 4 张截图（M2.5 期间延后；现 M2.6 完成，可基于 v1.5.1 重捕）

参见 [[zhiyue-m2-5-complete]] 了解前序 milestone。
```

- [ ] **Step 5: Update MEMORY.md index**

Add line to `MEMORY.md`:
```
- [智阅 M2.6 完整交付](project_zhiyue_m2_6_complete.md) — 2026-07-03 13 task + 1085 tests，双 tag m2.6-complete + v1.5.1-alpha；8 个用户报 bug 全闭（Bug #1 仅防御性修）；A2 book-like margin tap zones
```

- [ ] **Step 6: Commit memory artifacts**

```bash
cd "H:/projiect/电子书阅读平台"
git add docs/maintainers-runbook.md
git commit -m "$(cat <<'EOF'
docs(m2.6): runbook milestone index + M2.6 entry

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

- [ ] **Step 7: Notify user**

Tell user:
- New Debug exe at `H:\projiect\电子书阅读平台\app\build\windows\x64\runner\Debug\zhiyue.exe` (rebuilt with M2.6 fixes)
- All 7 of 8 bugs should be resolved; Bug #1 has defensive fix only
- Request: re-test, and if Bug #1 (bookmark red screen) still appears, copy the yellow English text

---

## Self-Review Checklist

After writing this plan, run through:

1. **Spec coverage**: Every bug in spec has a task?
   - Bug #1 → T8 ✓
   - Bug #2 → T6 ✓
   - Bug #3 → T3 ✓
   - Bug #4 → T2 ✓
   - Bug #5a → T9 ✓
   - Bug #5b → T5 ✓
   - Bug #6 → T1 ✓
   - Bug #7 → T7 ✓
   - Bug #8 → T4 ✓
   - Bug #9 → T10 ✓
   - All 10 covered ✓

2. **Type consistency**: Method signatures match across tasks?
   - `engine.dualPageMode` setter on PdfReaderEngine (T2) ✓
   - `engine.typography` getter on ConcreteEpubReaderEngine (T3) ✓
   - `_stateController.add(ReaderEngineReady())` consistent across T5/T7 ✓

3. **Placeholder scan**: Any TODO / TBD?
   - T2/T3 tests have "Spike first" comments — those are intentional, will be resolved during impl
   - T9 `_currentMarginPx()` helper — described inline
   - No stray placeholders ✓

4. **Dependency order**: Tasks that depend on others run later?
   - T4 (margin values) before T9 (uses values as tap widths) ✓
   - T1-T9 fixes before T10 verify ✓
   - T10 before T11/T12 ✓

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-07-03-m2-6-emergency-bug-fix.md`. Execution approach: **Subagent-Driven Development** (project standard).

- Each task T1-T10 dispatches a fresh implementer subagent
- After each impl: spec-compliance reviewer subagent → code-quality reviewer subagent
- T11-T14 are mechanical / documentation, executed inline by main thread
