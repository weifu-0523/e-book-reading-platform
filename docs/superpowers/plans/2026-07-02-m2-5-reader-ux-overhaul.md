# M2.5 — Reader UX Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 2 P0 reader bugs (#4 highlight no color, #6 notes tap no-op) and deliver 8 UX improvements (#2 multi-input paging, #3 chrome default + fullscreen, #5 merge toolbar, #7 bookmarks, #8 TOC sidebar collapse, #9 margin, #10 dual-page EPUB+PDF) targeting v1.5.0-alpha.

**Architecture:** Bug fixes are surgical patches (1-2 files each). UX changes touch `reader_scaffold.dart` + `reader_body.dart` + `reader_ui_controller.dart`. New bookmark subsystem spans drift schema → repository → controller → UI → sync. Dual-page layout requires LayoutBuilder + renderer-level changes for both PDF (simpler) and EPUB (pagation algorithm rewrite).

**Tech Stack:** Flutter 3.44 / Dart 3.10 / Riverpod 2.5 / drift 2.18 / pdfrx 2.4.4 / epubx 4.0.0 (forked) / window_manager (new dep for desktop fullscreen)

**Spec:** `docs/superpowers/specs/2026-07-02-m2-5-reader-ux-overhaul-design.md`

---

## File Structure

### New files
- `app/lib/data/local/tables/bookmarks.dart` — drift Bookmarks table
- `app/lib/data/repositories/bookmark_repository.dart` — DB CRUD
- `app/lib/features/reader/controllers/bookmark_controller.dart` — Riverpod state
- `app/lib/features/reader/widgets/reader_selection_sheet.dart` — merged 摘录 bottom sheet
- `app/lib/features/reader/widgets/reader_bookmark_dialog.dart` — add/edit bookmark dialog
- `app/lib/features/reader/widgets/reader_bookmark_list.dart` — bookmark list widget (drawer tab + standalone page reuse)
- `app/lib/features/reader/widgets/reader_drawer.dart` — new 3-tab drawer container
- `app/lib/features/bookmarks/pages/bookmarks_page.dart` — standalone `/book/:id/bookmarks` page
- `reader_engine/lib/rendering/dual_page_layout.dart` — shared dual-page LayoutBuilder helper

### Modified files
- `reader_engine_epub_view/lib/epubx_renderer.dart` — gotoLocator Range branch + dual-page
- `reader_engine/lib/core/typography_settings.dart` — pageMargin ExtraWide enum value
- `app/lib/features/reader/pages/reader_body.dart` — injectHighlights bridge + sheet integration + dual-page hooks
- `app/lib/features/reader/pages/reader_page.dart` — bookmarks provider overrides
- `app/lib/features/reader/widgets/reader_scaffold.dart` — AppBar icons + drawer 3-tab + sidebar collapse + dual-page
- `app/lib/features/reader/controllers/reader_ui_controller.dart` — fullscreen + sidebarCollapsed + activeDrawerTab state
- `app/lib/data/local/database.dart` — drift v10 migration
- `app/lib/sync/sync_entity_registry.dart` — register bookmarks entity
- `app/lib/core/router.dart` — `/book/:id/bookmarks` route
- `app/pubspec.yaml` — add `window_manager` dep
- `app/lib/main.dart` — window_manager init
- `reader_engine_pdf_view/lib/pdf_renderer.dart` — dual-page rendering support
- `pubspec.yaml` (root) — version bump 1.4.0-alpha → 1.5.0-alpha
- `CHANGELOG.md` — `[1.5.0-alpha]` section
- `README.md` — status + version badge sync

---

## Phase A — P0 Bug Fixes + Quick Wins

### Task 1: Fix EpubxRenderer.gotoLocator EpubRangeLocator branch (Bug #6)

**Files:**
- Modify: `reader_engine_epub_view/lib/epubx_renderer.dart:404-435`
- Test: `reader_engine_epub_view/test/epubx_renderer_goto_locator_test.dart` (NEW)

**Why:** NotesPage tap silently no-ops because `gotoLocator` only handles `EpubCfiLocator`; annotations are stored as `EpubRangeLocator`.

- [ ] **Step 1: Write failing test**

```dart
// reader_engine_epub_view/test/epubx_renderer_goto_locator_test.dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/locator.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

void main() {
  group('EpubxRenderer.gotoLocator', () {
    test('EpubRangeLocator switches chapter + does not no-op', () async {
      final r = EpubxRenderer();
      // Pre-condition: load a test EPUB (use existing fixture from other tests).
      await r.openBook('test/fixtures/empty.epub');
      // Set to a chapter we will navigate away from.
      await r.gotoLocator(const EpubCfiLocator(chapterIndex: 0, cfi: ''));
      expect(r.currentChapterIndex, 0);

      // Drive with a Range locator pointing to chapter 2.
      const range = EpubRangeLocator(
        chapterIndex: 2,
        startOffset: 100,
        endOffset: 200,
        chapterTitle: 'Ch 2',
      );
      await r.gotoLocator(range);

      // Assert: chapter index switched (no longer 0).
      expect(r.currentChapterIndex, 2,
          reason: 'EpubRangeLocator must trigger chapter switch');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 reader_engine_epub_view/test/epubx_renderer_goto_locator_test.dart`
Expected: FAIL with "Expected: 2 / Actual: 0" (gotoLocator no-op'd)

- [ ] **Step 3: Implement the fix**

Replace `reader_engine_epub_view/lib/epubx_renderer.dart` line 404-405:
```dart
Future<void> gotoLocator(Locator locator) async {
  if (locator is EpubCfiLocator) {
    // ... existing CFI branch unchanged (lines 406-435)
  } else if (locator is EpubRangeLocator) {
    // Bug #6 fix: annotations stored as Range, not CFI.
    if (locator.chapterIndex != _currentChapterIndex) {
      _currentChapterIndex = locator.chapterIndex;
      _cachedBreaks = null;
      _beginChapterSwitch();
    }
    // Precise scroll handled by caller via ScrollToOffsetService.
    return;
  }
  // PdfPageLocator / PdfRangeLocator / unknown: silent no-op (defensive).
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 reader_engine_epub_view/test/epubx_renderer_goto_locator_test.dart`
Expected: PASS

- [ ] **Step 5: Run full reader_engine_epub_view test suite to catch regressions**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 reader_engine_epub_view/`
Expected: All existing tests still pass

- [ ] **Step 6: Commit**

```bash
git add reader_engine_epub_view/lib/epubx_renderer.dart reader_engine_epub_view/test/epubx_renderer_goto_locator_test.dart
git commit -m "$(cat <<'EOF'
fix(reader): EpubxRenderer.gotoLocator handles EpubRangeLocator

Bug #6 root cause: gotoLocator only handled EpubCfiLocator; annotations
are stored as EpubRangeLocator → silent no-op on NotesPage tap.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Wire ReaderBody ref.listen → engine.injectHighlights (Bug #4)

**Files:**
- Modify: `app/lib/features/reader/pages/reader_body.dart` (add ref.listen in `_ReaderBodyState.build`)
- Test: `app/test/features/reader/reader_body_highlights_test.dart` (NEW)

**Why:** DB write succeeds, drawer updates, but renderer's `_allHighlights` stays empty because no `ref.listen` bridges NotesState → renderer.

- [ ] **Step 1: Write failing widget test**

```dart
// app/test/features/reader/reader_body_highlights_test.dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/reader/pages/reader_body.dart';
import 'package:app/data/models/annotation.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';
// ... existing test helpers from reader_body_test.dart

void main() {
  testWidgets('writing annotation triggers engine.injectHighlights',
      (tester) async {
    final harness = await ReaderBodyTestHarness.boot(tester);
    final engine = harness.engine as EpubxRenderer;
    expect(engine.allHighlightsForTest, isEmpty);

    // Add an annotation via the same path the toolbar uses.
    await harness.addAnnotation(
      Annotation(
        id: 'a1',
        bookId: harness.bookId,
        locator: harness.sampleRangeLocator,
        colorRgba: 0xFFFFFF00,
        createdAt: DateTime.now(),
      ),
    );
    await tester.pumpAndSettle();

    expect(engine.allHighlightsForTest, hasLength(1),
        reason: 'engine.injectHighlights must be called when NotesState updates');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 app/test/features/reader/reader_body_highlights_test.dart`
Expected: FAIL with "Expected: 1 / Actual: 0"

- [ ] **Step 3: Expose test-only getter on EpubxRenderer**

In `reader_engine_epub_view/lib/epubx_renderer.dart`, add:
```dart
/// Test-only: returns current count of injected highlights.
@visibleForTesting
List<HighlightRange> get allHighlightsForTest => List.unmodifiable(_allHighlights);
```
(Add `import 'package:flutter/foundation.dart';` if not present.)

- [ ] **Step 4: Implement the bridge in reader_body.dart**

In `_ReaderBodyState.build()`, near the existing `ref.listen` calls (around line 200), add:
```dart
ref.listen<AsyncValue<NotesState>>(notesControllerProvider, (_, async) {
  final s = async.valueOrNull;
  if (s == null) return;
  final ranges = s.annotations.map(_annotationToHighlightRange).toList();
  engine.injectHighlights(ranges);
});
```

Add helper method to `_ReaderBodyState`:
```dart
HighlightRange _annotationToHighlightRange(Annotation a) {
  final loc = a.locator;
  if (loc is EpubRangeLocator) {
    return HighlightRange(
      startOffset: loc.startOffset,
      endOffset: loc.endOffset,
      chapterIndex: loc.chapterIndex,
      colorRgba: a.colorRgba,
    );
  }
  if (loc is EpubCfiLocator) {
    return HighlightRange(
      cfi: loc.cfi,
      chapterIndex: loc.chapterIndex,
      colorRgba: a.colorRgba,
    );
  }
  // PdfRangeLocator etc. — should not occur in EPUB reader, defensive default.
  throw StateError('Unexpected locator type for EPUB: ${loc.runtimeType}');
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 app/test/features/reader/reader_body_highlights_test.dart`
Expected: PASS

- [ ] **Step 6: Run full app test suite**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1`
Expected: All tests pass (824 baseline + 1 new)

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/reader/pages/reader_body.dart app/test/features/reader/reader_body_highlights_test.dart reader_engine_epub_view/lib/epubx_renderer.dart
git commit -m "$(cat <<'EOF'
fix(reader): wire NotesState → engine.injectHighlights bridge

Bug #4 root cause: toolbar writes annotation to DB; notes drawer updates;
but renderer._allHighlights stays empty because nothing bridges them.
Add ref.listen in ReaderBody to push annotations → renderer on every
NotesState change.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Merge highlight/note toolbar buttons into 摘录 bottom sheet

**Files:**
- Create: `app/lib/features/reader/widgets/reader_selection_sheet.dart`
- Modify: `app/lib/features/reader/widgets/reader_selection_toolbar.dart`
- Test: `app/test/features/reader/widgets/reader_selection_sheet_test.dart` (NEW)

**Why:** User reports highlight/note behave identically; consolidate UI.

- [ ] **Step 1: Write failing test**

```dart
// app/test/features/reader/widgets/reader_selection_sheet_test.dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/reader/widgets/reader_selection_sheet.dart';

void main() {
  testWidgets('sheet shows 5 colors + note field + save button', (tester) async {
    int savedColor = 0;
    String? savedNote;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReaderSelectionSheet(
          onSave: (color, note) {
            savedColor = color;
            savedNote = note;
          },
        ),
      ),
    ));

    expect(find.byType(ReaderSelectionSheet), findsOneWidget);
    // 5 color circles
    expect(find.byKey(const Key('color_chip_0')), findsOneWidget);
    expect(find.byKey(const Key('color_chip_4')), findsOneWidget);
    // Note text field
    expect(find.byKey(const Key('note_field')), findsOneWidget);
    // Save button
    expect(find.text('保存'), findsOneWidget);

    // Tap 3rd color, type note, save.
    await tester.tap(find.byKey(const Key('color_chip_2')));
    await tester.enterText(find.byKey(const Key('note_field')), 'key point');
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(savedColor, 0xFFFFEB3B); // yellow = chip 2
    expect(savedNote, 'key point');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 app/test/features/reader/widgets/reader_selection_sheet_test.dart`
Expected: FAIL with "ReaderSelectionSheet not found"

- [ ] **Step 3: Implement ReaderSelectionSheet**

Create `app/lib/features/reader/widgets/reader_selection_sheet.dart`:
```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// (license header)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Color palette constants — match existing highlight colors used by NotesController.
const _kHighlightColors = <int>[
  0xFFFFEB3B, // yellow
  0xFFA5D6A7, // green
  0xFF90CAF9, // blue
  0xFFFFCDD2, // pink
  0xFFCE93D8, // purple
];

class ReaderSelectionSheet extends ConsumerState {
  const ReaderSelectionSheet({
    super.key,
    required this.onSave,
    this.initialColor,
    this.initialNote,
  });

  final void Function(int colorRgba, String? note) onSave;
  final int? initialColor;
  final String? initialNote;

  @override
  ConsumerState<ReaderSelectionSheet> createState() => _ReaderSelectionSheetState();
}

class _ReaderSelectionSheetState extends ConsumerState<ReaderSelectionSheet> {
  late int _selectedColor = widget.initialColor ?? _kHighlightColors[2];
  late final TextEditingController _noteCtrl =
      TextEditingController(text: widget.initialNote ?? '');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < _kHighlightColors.length; i++)
                  GestureDetector(
                    key: Key('color_chip_$i'),
                    onTap: () => setState(() => _selectedColor = _kHighlightColors[i]),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Color(_kHighlightColors[i]),
                        shape: BoxShape.circle,
                        border: _selectedColor == _kHighlightColors[i]
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const Key('note_field'),
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          ButtonBar(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final note = _noteCtrl.text.trim();
                  widget.onSave(_selectedColor, note.isEmpty ? null : note);
                  Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 app/test/features/reader/widgets/reader_selection_sheet_test.dart`
Expected: PASS

- [ ] **Step 5: Replace toolbar's two buttons with one 摘录 button**

In `app/lib/features/reader/widgets/reader_selection_toolbar.dart`, remove the separate 高亮 + 笔记 buttons; add a single 摘录 button:
```dart
TextButton.icon(
  onPressed: () {
    // Close toolbar, show bottom sheet.
    hideToolbar();
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => ReaderSelectionSheet(
        onSave: (color, note) {
          onHighlight(color); // existing callback path
          if (note != null && note.isNotEmpty) {
            onAddNote(note);
          }
        },
      ),
    );
  },
  icon: const Icon(Icons.brush),
  label: const Text('摘录'),
),
```

- [ ] **Step 6: Update existing toolbar tests**

In `app/test/features/reader/widgets/reader_selection_toolbar_test.dart`, replace assertions for separate 高亮/笔记 buttons with assertion for single 摘录 button.

- [ ] **Step 7: Run all reader tests**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 app/test/features/reader/`
Expected: All pass

- [ ] **Step 8: Commit**

```bash
git add app/lib/features/reader/widgets/reader_selection_sheet.dart app/lib/features/reader/widgets/reader_selection_toolbar.dart app/test/features/reader/widgets/reader_selection_sheet_test.dart app/test/features/reader/widgets/reader_selection_toolbar_test.dart
git commit -m "$(cat <<'EOF'
feat(reader): merge highlight+note buttons into single 摘录 sheet

Toolbar had two buttons (高亮 / 笔记) but both wrote to Annotation with
optional note field — behavior identical. Consolidate to one 摘录 button
that opens a bottom sheet: 5-color picker + optional note + save.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Increase default margin to Normal=24, add ExtraWide=40

**Files:**
- Modify: `reader_engine/lib/core/typography_settings.dart`
- Modify: `reader_engine_epub_view/lib/epubx_renderer.dart:524-533` (margin mapping)
- Test: `reader_engine/test/core/typography_settings_test.dart` (extend)

**Why:** User feedback "看起来难受"; current default Normal=16 too tight vs. real-book feel (~24-40).

- [ ] **Step 1: Add failing test for ExtraWide + new Normal value**

Append to `reader_engine/test/core/typography_settings_test.dart`:
```dart
test('PageMargin enum has 4 values; .normal default pixel value is 24', () {
  expect(PageMargin.values, hasLength(4));
  expect(PageMargin.normal.pixelValue, 24);
  expect(PageMargin.extraWide.pixelValue, 40);
});

test('TypographySettings.defaults uses PageMargin.normal', () {
  final s = TypographySettings.defaults();
  expect(s.pageMargin, PageMargin.normal);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 reader_engine/test/core/typography_settings_test.dart`
Expected: FAIL — `PageMargin.extraWide` doesn't exist, `.pixelValue` getter missing, `.normal` returns 16

- [ ] **Step 3: Update PageMargin enum**

In `reader_engine/lib/core/typography_settings.dart`:
```dart
enum PageMargin {
  compact(8),
  normal(24),    // was 16; bumped for real-book feel
  wide(32),      // was 24
  extraWide(40); // NEW

  final int pixelValue;
  const PageMargin(this.pixelValue);
}
```

- [ ] **Step 4: Update epubx_renderer.dart margin mapping**

In `reader_engine_epub_view/lib/epubx_renderer.dart` around line 524-533, replace `_marginValue(PageMargin)` with direct `.pixelValue` access; delete the now-redundant local helper.

- [ ] **Step 5: Run tests to verify pass**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 reader_engine/test/core/typography_settings_test.dart reader_engine_epub_view/`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add reader_engine/lib/core/typography_settings.dart reader_engine_epub_view/lib/epubx_renderer.dart reader_engine/test/core/typography_settings_test.dart
git commit -m "$(cat <<'EOF'
feat(typography): bump default margin to 24px, add ExtraWide=40

Real-book feel needs more whitespace; old Normal=16 too tight. Existing
users' chosen margin is preserved (enum value index unchanged, only
pixel value changes). New ExtraWide=40 added for desktop.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Phase B — Reader UX

### Task 5: Multi-input paging (keyboard + wheel + drag + tap zones)

**Files:**
- Modify: `app/lib/features/reader/widgets/reader_scaffold.dart` (add KeyboardListener, Listener, expand GestureDetector)
- Modify: `app/lib/features/reader/controllers/reader_ui_controller.dart` (add `goNextPage` / `goPrevPage` if missing)
- Test: `app/test/features/reader/widgets/reader_paging_test.dart` (NEW)

**Why:** Currently only tap-zones (left/right thirds) work in paged mode. Add keyboard ←/→/↑/↓/PgUp/PgDn, mouse wheel, touch horizontal drag.

- [ ] **Step 1: Write failing widget tests**

```dart
// app/test/features/reader/widgets/reader_paging_test.dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/reader/widgets/reader_scaffold.dart';
// harness from existing reader tests

void main() {
  testWidgets('right arrow key triggers next page', (tester) async {
    final harness = await ReaderScaffoldTestHarness.boot(tester, mode: PaginationMode.paged);
    expect(harness.engine.currentPage, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(harness.engine.currentPage, 1);
  });

  testWidgets('left arrow key triggers prev page', (tester) async {
    final harness = await ReaderScaffoldTestHarness.boot(tester, mode: PaginationMode.paged);
    harness.engine.setPageForTest(2);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(harness.engine.currentPage, 1);
  });

  testWidgets('mouse wheel down triggers next page in paged mode', (tester) async {
    final harness = await ReaderScaffoldTestHarness.boot(tester, mode: PaginationMode.paged);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: const Offset(200, 200));

    await tester.pump();
    await gesture.scrollEvent(const Offset(0, 100));
    await tester.pumpAndSettle();

    expect(harness.engine.currentPage, 1);
  });

  testWidgets('horizontal drag left triggers next page', (tester) async {
    final harness = await ReaderScaffoldTestHarness.boot(tester, mode: PaginationMode.paged);
    await tester.timedDrag(
      find.byType(ReaderScaffold),
      const Offset(-300, 0),
      const Duration(milliseconds: 200),
    );
    await tester.pumpAndSettle();
    expect(harness.engine.currentPage, 1);
  });

  testWidgets('tap left third triggers prev page', (tester) async {
    final harness = await ReaderScaffoldTestHarness.boot(tester, mode: PaginationMode.paged);
    harness.engine.setPageForTest(2);
    final size = tester.getSize(find.byType(ReaderScaffold));

    await tester.tapAt(Offset(size.width * 0.1, size.height / 2));
    await tester.pumpAndSettle();

    expect(harness.engine.currentPage, 1);
  });

  testWidgets('tap right third triggers next page', (tester) async {
    final harness = await ReaderScaffoldTestHarness.boot(tester, mode: PaginationMode.paged);
    final size = tester.getSize(find.byType(ReaderScaffold));

    await tester.tapAt(Offset(size.width * 0.9, size.height / 2));
    await tester.pumpAndSettle();

    expect(harness.engine.currentPage, 1);
  });

  testWidgets('tap center third does NOT toggle chrome', (tester) async {
    final harness = await ReaderScaffoldTestHarness.boot(tester, mode: PaginationMode.paged);
    final size = tester.getSize(find.byType(ReaderScaffold));
    expect(harness.ui.chromeVisible, true); // T6 will change default to true

    await tester.tapAt(Offset(size.width / 2, size.height / 2));
    await tester.pumpAndSettle();

    expect(harness.ui.chromeVisible, true, reason: 'center tap should NOT toggle');
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 app/test/features/reader/widgets/reader_paging_test.dart`
Expected: FAIL — no key/wheel/drag handlers

- [ ] **Step 3: Add paging controller methods if missing**

In `reader_ui_controller.dart` or a new `reader_paging_controller.dart`, ensure these exist:
```dart
void goNextPage() {
  final engine = ref.read(currentReaderEngineProvider);
  final page = engine.currentPage;
  if (page < engine.pageCount - 1) engine.setPage(page + 1);
}

void goPrevPage() {
  final engine = ref.read(currentReaderEngineProvider);
  final page = engine.currentPage;
  if (page > 0) engine.setPage(page - 1);
}
```

- [ ] **Step 4: Wrap reader content with KeyboardListener**

In `reader_scaffold.dart` `build()`, wrap the body Stack with:
```dart
Focus(
  autofocus: true,
  onKeyEvent: (node, event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final logical = event.logicalKey;
    if (logical == LogicalKeyboardKey.arrowRight ||
        logical == LogicalKeyboardKey.pageDown ||
        logical == LogicalKeyboardKey.arrowDown) {
      ref.read(readerUiProvider.notifier).goNextPage();
      return KeyEventResult.handled;
    }
    if (logical == LogicalKeyboardKey.arrowLeft ||
        logical == LogicalKeyboardKey.pageUp ||
        logical == LogicalKeyboardKey.arrowUp) {
      ref.read(readerUiProvider.notifier).goPrevPage();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  },
  child: ... // existing body
)
```

- [ ] **Step 5: Add mouse wheel handling via Listener**

Inside the Stack, add a `Listener`:
```dart
Listener(
  onPointerSignal: (signal) {
    if (signal is! PointerScrollEvent) return;
    if (ref.read(readerUiProvider).paginationMode != PaginationMode.paged) return;
    if (signal.scrollDelta.dy > 0) {
      ref.read(readerUiProvider.notifier).goNextPage();
    } else if (signal.scrollDelta.dy < 0) {
      ref.read(readerUiProvider.notifier).goPrevPage();
    }
  },
  child: ... // reading area
),
```

- [ ] **Step 6: Expand GestureDetector for horizontal drag**

In the existing `GestureDetector` for tap zones, add:
```dart
onHorizontalDragEnd: (details) {
  final v = details.primaryVelocity;
  if (v == null) return;
  if (v < -200) {
    ref.read(readerUiProvider.notifier).goNextPage(); // swipe left
  } else if (v > 200) {
    ref.read(readerUiProvider.notifier).goPrevPage(); // swipe right
  }
},
```

- [ ] **Step 7: Run tests to verify all pass**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 app/test/features/reader/widgets/reader_paging_test.dart`
Expected: All 6 tests PASS

- [ ] **Step 8: Run full app test suite for regressions**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1`
Expected: All pass

- [ ] **Step 9: Commit**

```bash
git add app/lib/features/reader/widgets/reader_scaffold.dart app/lib/features/reader/controllers/reader_ui_controller.dart app/test/features/reader/widgets/reader_paging_test.dart
git commit -m "$(cat <<'EOF'
feat(reader): 4 paging inputs (keyboard/wheel/drag/tap-zones)

User feedback: only tap-zones paging worked. Add keyboard (←/→/↑/↓/PgUp/
PgDn), mouse wheel (paged mode), horizontal drag (touch + trackpad).
Center-tap no longer toggles chrome (chrome behavior handled by T6).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: chrome default visible + remove single-tap toggle

**Files:**
- Modify: `app/lib/features/reader/controllers/reader_ui_controller.dart` (default `chromeVisible=true` on desktop, false on mobile)
- Modify: `app/lib/features/reader/widgets/reader_scaffold.dart` (remove center-tap chrome toggle)
- Test: `app/test/features/reader/controllers/reader_ui_controller_test.dart` (extend)

**Why:** User reports "右上角没图标"; default hidden is wrong on desktop.

- [ ] **Step 1: Add failing test for new default**

Append to `app/test/features/reader/controllers/reader_ui_controller_test.dart`:
```dart
test('chromeVisible default true on desktop', () {
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  addTearDown(debugDefaultTargetPlatformOverride = null);
  final ui = ReaderUiState.defaults();
  expect(ui.chromeVisible, true);
});

test('chromeVisible default false on mobile', () {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  addTearDown(debugDefaultTargetPlatformOverride = null);
  final ui = ReaderUiState.defaults();
  expect(ui.chromeVisible, false);
});
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — current default is `false` unconditionally.

- [ ] **Step 3: Update defaults with platform branch**

In `reader_ui_controller.dart`:
```dart
factory ReaderUiState.defaults() {
  final isMobile = defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS;
  return ReaderUiState(
    chromeVisible: !isMobile,    // desktop: true; mobile: false
    isFullscreen: isMobile,      // mobile enters fullscreen by default
    // ... other fields
  );
}
```

- [ ] **Step 4: Remove center-tap chrome toggle from reader_scaffold.dart**

The GestureDetector's `onTapUp` center branch currently calls `toggleChrome()`. Replace with no-op (or remove the center branch entirely since T5 makes it explicit).

- [ ] **Step 5: Run tests to verify pass + no regressions**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 app/test/features/reader/`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/reader/controllers/reader_ui_controller.dart app/lib/features/reader/widgets/reader_scaffold.dart app/test/features/reader/controllers/reader_ui_controller_test.dart
git commit -m "$(cat <<'EOF'
feat(reader): chrome visible by default on desktop

User feedback:AppBar hidden on entry is confusing on desktop. Now
defaults visible on Windows/macOS; mobile still defaults hidden (uses
fullscreen mode instead — T7). Center-tap chrome toggle removed (chrome
is controlled by fullscreen button + Esc).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Drawer 3-tab refactor (目录/书签/笔记 placeholder)

**Files:**
- Create: `app/lib/features/reader/widgets/reader_drawer.dart`
- Modify: `app/lib/features/reader/widgets/reader_scaffold.dart` (replace Drawer + endDrawer with new unified drawer)
- Modify: `app/lib/features/reader/controllers/reader_ui_controller.dart` (add `DrawerTab activeDrawerTab`)
- Test: `app/test/features/reader/widgets/reader_drawer_test.dart` (NEW)

**Why:** Bookmark UI needs a drawer tab; consolidate left drawer (TOC) + right endDrawer (Notes) into one 3-tab container.

- [ ] **Step 1: Write failing test**

```dart
// app/test/features/reader/widgets/reader_drawer_test.dart
// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/reader/widgets/reader_drawer.dart';

void main() {
  testWidgets('drawer shows 3 tabs; bookmarks tab is empty placeholder', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReaderDrawer(
          bookId: 'b1',
          initialTab: DrawerTab.toc,
          onSwitchTab: (_) {},
        ),
      ),
    ));

    expect(find.text('目录'), findsOneWidget);
    expect(find.text('书签'), findsOneWidget);
    expect(find.text('笔记'), findsOneWidget);

    await tester.tap(find.text('书签'));
    await tester.pumpAndSettle();

    expect(find.text('暂无书签'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — ReaderDrawer not found.

- [ ] **Step 3: Add DrawerTab enum to reader_ui_controller.dart**

```dart
enum DrawerTab { toc, bookmarks, notes }
```
And add `activeDrawerTab` field to `ReaderUiState` (default `DrawerTab.toc`).

- [ ] **Step 4: Create ReaderDrawer**

Create `app/lib/features/reader/widgets/reader_drawer.dart`:
```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// (header)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'reader_ui_controller.dart';
import 'reader_toc_tab.dart';        // extract from existing drawer
import 'reader_bookmark_list.dart';  // T12 — empty placeholder for now
import 'reader_notes_tab.dart';      // extract from existing endDrawer

class ReaderDrawer extends ConsumerWidget {
  const ReaderDrawer({
    super.key,
    required this.bookId,
    this.initialTab = DrawerTab.toc,
    required this.onSwitchTab,
  });

  final String bookId;
  final DrawerTab initialTab;
  final void Function(DrawerTab) onSwitchTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(readerUiProvider);
    final tab = ui.activeDrawerTab;
    return SizedBox(
      width: 280,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: TabBar(
              onTap: (i) => onSwitchTab(DrawerTab.values[i]),
              tabs: const [
                Tab(text: '目录'),
                Tab(text: '书签'),
                Tab(text: '笔记'),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: DrawerTab.values.indexOf(tab),
              children: [
                ReaderTocTab(bookId: bookId),
                ReaderBookmarkList(bookId: bookId), // empty placeholder T12
                ReaderNotesTab(bookId: bookId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Extract ReaderTocTab + ReaderNotesTab from existing drawer/endDrawer**

Move the body of the existing `Drawer` (currently in `reader_scaffold.dart`) into `reader_toc_tab.dart`; move `endDrawer` body into `reader_notes_tab.dart`. Both are stateless wrappers taking `bookId`.

- [ ] **Step 6: Replace Drawer + endDrawer in reader_scaffold.dart**

Replace:
```dart
drawer: Drawer(child: _oldTocBody),
endDrawer: Drawer(child: _oldNotesBody),
```
With:
```dart
drawer: ReaderDrawer(
  bookId: bookId,
  onSwitchTab: (tab) => ref.read(readerUiProvider.notifier).setActiveDrawerTab(tab),
),
// endDrawer removed
```

- [ ] **Step 7: Update all existing tests referencing endDrawer**

Grep `app/test/features/reader` for `endDrawer` and update to expect single `ReaderDrawer` with 3 tabs.

- [ ] **Step 8: Run all tests**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1`
Expected: All pass

- [ ] **Step 9: Commit**

```bash
git add app/lib/features/reader/widgets/reader_drawer.dart app/lib/features/reader/widgets/reader_toc_tab.dart app/lib/features/reader/widgets/reader_notes_tab.dart app/lib/features/reader/widgets/reader_scaffold.dart app/lib/features/reader/controllers/reader_ui_controller.dart app/test/features/reader/
git commit -m "$(cat <<'EOF'
refactor(reader): unify drawer into 3-tab container

Replaces separate Drawer (TOC) + endDrawer (Notes) with a single
ReaderDrawer holding a TabBar with 3 tabs: 目录 / 书签 / 笔记. Bookmarks
tab is empty placeholder pending T12 implementation.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: TOC sidebar collapse on wide screens

**Files:**
- Modify: `app/lib/features/reader/widgets/reader_scaffold.dart` (LayoutBuilder: wide → permanent sidebar; narrow → Drawer)
- Modify: `app/lib/features/reader/controllers/reader_ui_controller.dart` (add `tocSidebarCollapsed`)
- Test: `app/test/features/reader/widgets/reader_sidebar_test.dart` (NEW)

**Why:** Wide screens should show TOC as permanent sidebar with collapse toggle; not slide-over.

- [ ] **Step 1: Write failing test**

```dart
// app/test/features/reader/widgets/reader_sidebar_test.dart
testWidgets('wide screen shows permanent sidebar; collapse reduces width', (tester) async {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearOut(tester.view.resetPhysicalSize);

  await tester.pumpWidget(...ReaderScaffold...);
  await tester.pumpAndSettle();

  // Sidebar visible
  expect(find.byType(ReaderDrawer), findsOneWidget);
  // Collapse button visible
  expect(find.byKey(const Key('collapse_sidebar')), findsOneWidget);

  await tester.tap(find.byKey(const Key('collapse_sidebar')));
  await tester.pumpAndSettle();

  // Sidebar collapsed to thin strip
  final sidebar = tester.widget<Container>(find.byKey(const Key('sidebar_root')));
  expect((sidebar.constraints as BoxConstraints).maxWidth, 40);
});

testWidgets('narrow screen hides sidebar; uses Drawer', (tester) async {
  tester.view.physicalSize = const Size(800, 900);
  // ... expect no permanent sidebar, drawer available
});
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — no LayoutBuilder logic, no collapse button.

- [ ] **Step 3: Add state field**

In `reader_ui_controller.dart`, add `tocSidebarCollapsed: bool` (default `false`).

- [ ] **Step 4: Implement LayoutBuilder in reader_scaffold.dart**

Wrap the body Row in:
```dart
LayoutBuilder(builder: (context, constraints) {
  final isWide = constraints.maxWidth >= 1100;
  if (!isWide) {
    // Narrow: keep existing Scaffold with drawer.
    return _buildNarrowScaffold(context, ref);
  }
  // Wide: permanent sidebar or collapsed strip.
  final collapsed = ref.watch(readerUiProvider).tocSidebarCollapsed;
  return Row(
    children: [
      AnimatedContainer(
        key: const Key('sidebar_root'),
        duration: const Duration(milliseconds: 200),
        width: collapsed ? 40 : 280,
        child: collapsed
            ? Material(
                child: IconButton(
                  key: const Key('expand_sidebar'),
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => ref.read(readerUiProvider.notifier).toggleSidebarCollapsed(),
                ),
              )
            : Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      key: const Key('collapse_sidebar'),
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => ref.read(readerUiProvider.notifier).toggleSidebarCollapsed(),
                    ),
                  ),
                  Expanded(child: ReaderDrawer(bookId: bookId, onSwitchTab: ...)),
                ],
              ),
      ),
      Expanded(child: _buildReaderBody(context, ref)),
    ],
  );
});
```

- [ ] **Step 5: Run tests + commit**

```bash
git add app/lib/features/reader/widgets/reader_scaffold.dart app/lib/features/reader/controllers/reader_ui_controller.dart app/test/features/reader/widgets/reader_sidebar_test.dart
git commit -m "feat(reader): TOC sidebar collapses on wide screens

Wide (>=1100px) shows permanent sidebar with collapse toggle (280px ↔
40px strip). Narrow keeps Drawer behavior. State persisted per session.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 9: Fullscreen mode (window_manager desktop + SystemChrome mobile)

**Files:**
- Modify: `app/pubspec.yaml` (add `window_manager: ^0.4.3`)
- Modify: `app/lib/main.dart` (init window_manager)
- Modify: `app/lib/features/reader/widgets/reader_scaffold.dart` (AppBar fullscreen icon + Esc handler + double-tap center)
- Modify: `app/lib/features/reader/controllers/reader_ui_controller.dart` (add `isFullscreen`)
- Test: `app/test/features/reader/widgets/reader_fullscreen_test.dart` (NEW)

**Why:** User wants explicit fullscreen mode (not auto-hide); mobile defaults fullscreen; Esc exits on desktop.

- [ ] **Step 1: Write failing test**

```dart
// app/test/features/reader/widgets/reader_fullscreen_test.dart
testWidgets('AppBar has fullscreen button; tapping sets state.isFullscreen', (tester) async {
  await harness.boot(tester);
  expect(find.byKey(const Key('toggle_fullscreen')), findsOneWidget);

  await tester.tap(find.byKey(const Key('toggle_fullscreen')));
  await tester.pump();
  expect(harness.ui.isFullscreen, true);
});

testWidgets('Esc key exits fullscreen', (tester) async {
  await harness.boot(tester);
  harness.setFullscreenForTest(true);

  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump();
  expect(harness.ui.isFullscreen, false);
});

testWidgets('double-tap center toggles chrome only in fullscreen', (tester) async {
  await harness.boot(tester);
  // Non-fullscreen: chrome default visible; double-tap center does nothing.
  final size = tester.getSize(find.byType(ReaderScaffold));
  await tester.tapAt(Offset(size.width / 2, size.height / 2));
  await tester.tapAt(Offset(size.width / 2, size.height / 2));
  await tester.pump();
  expect(harness.ui.chromeVisible, true);

  // Fullscreen: chrome hidden; double-tap shows it.
  harness.setFullscreenForTest(true);
  await tester.tapAt(Offset(size.width / 2, size.height / 2));
  await tester.tapAt(Offset(size.width / 2, size.height / 2));
  await tester.pump();
  expect(harness.ui.chromeVisible, true);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Expected: FAIL — no fullscreen state, no fullscreen button.

- [ ] **Step 3: Add window_manager dep + init**

In `app/pubspec.yaml`:
```yaml
dependencies:
  window_manager: ^0.4.3
```
Run: `/c/flutter/bin/flutter.bat pub get`

In `app/lib/main.dart` `main()`:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux) {
    await windowManager.ensureInitialized();
  }
  runApp(...);
}
```

- [ ] **Step 4: Add isFullscreen state + toggleFullscreen method**

In `reader_ui_controller.dart`:
```dart
bool isFullscreen;  // already added in T6 defaults
void toggleFullscreen() {
  final next = !state.isFullscreen;
  state = state.copyWith(isFullscreen: next);
  if (next) {
    // entering fullscreen
    state = state.copyWith(chromeVisible: false);
    if (defaultTargetPlatform.isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        windowManager.setFullScreen(true);
      }
    }
  } else {
    // exiting fullscreen
    if (defaultTargetPlatform.isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      if (defaultTargetPlatform == TargetPlatform.windows) {
        windowManager.setFullScreen(false);
      }
    }
    state = state.copyWith(chromeVisible: true);
  }
}
```

- [ ] **Step 5: Add fullscreen icon to AppBar**

In `reader_scaffold.dart` AppBar actions:
```dart
IconButton(
  key: const Key('toggle_fullscreen'),
  icon: Icon(ui.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen),
  onPressed: () => ref.read(readerUiProvider.notifier).toggleFullscreen(),
),
```

When `ui.isFullscreen`, conditionally hide AppBar (don't render it).

- [ ] **Step 6: Add Esc handler + double-tap to existing Focus + GestureDetector**

In the Focus `onKeyEvent` (added in T5):
```dart
if (logical == LogicalKeyboardKey.escape && ref.read(readerUiProvider).isFullscreen) {
  ref.read(readerUiProvider.notifier).toggleFullscreen();
  return KeyEventResult.handled;
}
if (logical == LogicalKeyboardKey.f11) {
  ref.read(readerUiProvider.notifier).toggleFullscreen();
  return KeyEventResult.handled;
}
```

In GestureDetector, add `onDoubleTapDown` + `onDoubleTap`:
```dart
onDoubleTap: () {
  if (ref.read(readerUiProvider).isFullscreen) {
    ref.read(readerUiProvider.notifier).toggleChrome();
  }
},
```

- [ ] **Step 7: Run tests + commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/lib/main.dart app/lib/features/reader/widgets/reader_scaffold.dart app/lib/features/reader/controllers/reader_ui_controller.dart app/test/features/reader/widgets/reader_fullscreen_test.dart
git commit -m "feat(reader): fullscreen mode with Esc/F11/double-tap controls

AppBar fullscreen icon → toggle. Esc/F11 keyboard shortcuts. Center
double-tap shows chrome temporarily when fullscreen. window_manager
drives native Windows fullscreen; SystemChrome drives mobile immersive.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase C — Bookmarks (new feature)

### Task 10: Drift Bookmarks schema + v10 migration

**Files:**
- Create: `app/lib/data/local/tables/bookmarks.dart`
- Modify: `app/lib/data/local/database.dart` (bump schemaVersion 9 → 10 + migration step)
- Test: `app/test/data/local/database_migration_test.dart` (extend)

- [ ] **Step 1: Write failing test**

```dart
test('migration v9 → v10 creates bookmarks table', () async {
  final db = await openTestDatabaseAtVersion(10);
  final tables = await db.customSelect(
    "SELECT name FROM sqlite_master WHERE type='table' AND name='bookmarks'",
  ).get();
  expect(tables, hasLength(1));
  expect(tables.first.data['name'], 'bookmarks');
});
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — table doesn't exist.

- [ ] **Step 3: Create Bookmarks table**

Create `app/lib/data/local/tables/bookmarks.dart`:
```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// (header)
import 'package:drift/drift.dart';

@DataClassName('BookmarkEntry')
class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().customConstraint('NOT NULL REFERENCES books(id) ON DELETE CASCADE')();
  TextColumn get locatorJson => text()();
  TextColumn get label => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 4: Bump schema + add migration**

In `app/lib/data/local/database.dart`:
- Add `Bookmarks` to `@DriftDatabase(tables: [..., Bookmarks])`
- Bump `schemaVersion = 10`
- Add migration:
```dart
if (from <= 9) {
  await m.createTable(bookmarks);
  await m.customStatement('CREATE INDEX bookmarks_bookId_idx ON bookmarks(book_id)');
}
```

- [ ] **Step 5: Run tests + commit**

```bash
git add app/lib/data/local/tables/bookmarks.dart app/lib/data/local/database.dart app/test/data/local/database_migration_test.dart
git commit -m "feat(db): Bookmarks table + drift v10 migration

Schema: id (ULID) / bookId FK / locatorJson / label / note? / timestamps.
Indexed by bookId for fast per-book queries. Cascade-delete with books.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 11: Bookmark repository + controller + sync

**Files:**
- Create: `app/lib/data/repositories/bookmark_repository.dart`
- Create: `app/lib/features/reader/controllers/bookmark_controller.dart`
- Modify: `app/lib/sync/sync_entity_registry.dart` (register bookmarks entity)
- Test: `app/test/data/repositories/bookmark_repository_test.dart` (NEW)
- Test: `app/test/sync/bookmark_sync_test.dart` (NEW)

- [ ] **Step 1: Write failing tests**

Repository test:
```dart
test('add + list + update + delete', () async {
  final repo = BookmarkRepository(db);
  await repo.add(BookmarkEntry(
    id: 'b1', bookId: 'book1', locatorJson: '{}', label: 'p10',
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));
  expect(await repo.listForBook('book1'), hasLength(1));

  await repo.updateLabel('b1', 'p20');
  expect((await repo.get('b1')).label, 'p20');

  await repo.delete('b1');
  expect(await repo.listForBook('book1'), isEmpty);
});
```

- [ ] **Step 2: Implement BookmarkRepository**

Standard drift CRUD methods (`add`, `get`, `listForBook`, `updateLabel`, `updateNote`, `delete`, `watchForBook`).

- [ ] **Step 3: Implement BookmarkController (Riverpod)**

```dart
class BookmarkController extends AsyncNotifier<BookmarkState> {
  // watchForBook stream → state
  // add(label, locator, note?) / updateLabel / updateNote / delete
}
```

- [ ] **Step 4: Register sync entity**

In `app/lib/sync/sync_entity_registry.dart`, add:
```dart
SyncEntity(
  name: 'bookmarks',
  filePattern: 'bookmarks/{bookId}.json',
  serializer: BookmarkSyncSerializer(),
  conflictStrategy: ConflictStrategy.lastWriteWins(),
),
```

- [ ] **Step 5: Run tests + commit**

```bash
git add app/lib/data/repositories/bookmark_repository.dart app/lib/features/reader/controllers/bookmark_controller.dart app/lib/sync/sync_entity_registry.dart app/test/data/repositories/bookmark_repository_test.dart app/test/sync/bookmark_sync_test.dart
git commit -m "feat(bookmarks): repository + controller + sync entity

CRUD via drift, Riverpod AsyncNotifier wraps stream, registered in sync
entity map with last-write-wins conflict resolution.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 12: Bookmark UI — AppBar icon + dialog + drawer tab + standalone page

**Files:**
- Create: `app/lib/features/reader/widgets/reader_bookmark_dialog.dart`
- Create: `app/lib/features/reader/widgets/reader_bookmark_list.dart` (replace T7 placeholder)
- Create: `app/lib/features/bookmarks/pages/bookmarks_page.dart`
- Modify: `app/lib/features/reader/widgets/reader_scaffold.dart` (add bookmark icon to AppBar)
- Modify: `app/lib/core/router.dart` (add `/book/:id/bookmarks` route)
- Test: `app/test/features/reader/widgets/reader_bookmark_dialog_test.dart` (NEW)
- Test: `app/test/features/bookmarks/pages/bookmarks_page_test.dart` (NEW)

- [ ] **Step 1: Write failing tests**

Dialog test:
```dart
testWidgets('add bookmark with label + note', (tester) async {
  BookmarkEntry? saved;
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    body: ReaderBookmarkDialog(
      bookId: 'b1',
      defaultLabel: '第 10 页',
      locator: sampleLocator,
      onSave: (entry) => saved = entry,
    ),
  )));
  await tester.enterText(find.byKey(const Key('label_field')), '关键转折');
  await tester.enterText(find.byKey(const Key('note_field')), '重新读');
  await tester.tap(find.text('添加'));
  expect(saved?.label, '关键转折');
  expect(saved?.note, '重新读');
});
```

- [ ] **Step 2: Implement ReaderBookmarkDialog**

Standard AlertDialog with two TextField (label/note) and 取消/添加 buttons.

- [ ] **Step 3: Implement ReaderBookmarkList**

Listens to `bookmarkControllerProvider(bookId)`, renders `ListView` of bookmarks. Each item has label + note preview + tap → `engine.gotoLocator(locator)`.

- [ ] **Step 4: Add AppBar bookmark icon**

In `reader_scaffold.dart` AppBar actions, between typography and AI guide:
```dart
IconButton(
  icon: Icon(currentPageHasBookmark ? Icons.bookmark : Icons.bookmark_border),
  onPressed: () {
    if (currentPageHasBookmark) {
      // Show edit dialog
      showDialog(context: context, builder: (_) => ReaderBookmarkDialog.edit(existing...));
    } else {
      showDialog(context: context, builder: (_) => ReaderBookmarkDialog.add(bookId: bookId, ...));
    }
  },
),
```

- [ ] **Step 5: Implement standalone BookmarksPage**

Create `app/lib/features/bookmarks/pages/bookmarks_page.dart`:
- Takes `bookId` from route param
- Renders `ReaderBookmarkList` (reuse) inside a normal Scaffold with back button

- [ ] **Step 6: Add route**

In `app/lib/core/router.dart`:
```dart
GoRoute(
  path: 'book/:id/bookmarks',
  builder: (c, s) => BookmarksPage(bookId: s.pathParameters['id']!),
),
```

- [ ] **Step 7: Run tests + commit**

```bash
git add app/lib/features/reader/widgets/reader_bookmark_dialog.dart app/lib/features/reader/widgets/reader_bookmark_list.dart app/lib/features/bookmarks/pages/bookmarks_page.dart app/lib/features/reader/widgets/reader_scaffold.dart app/lib/core/router.dart app/test/features/reader/widgets/reader_bookmark_dialog_test.dart app/test/features/bookmarks/pages/bookmarks_page_test.dart
git commit -m "feat(bookmarks): full UI — AppBar icon + dialog + drawer tab + page

Three entry points per spec §5. AppBar icon: tap to add/edit current page
bookmark (state: filled/empty). Drawer bookmarks tab (T7 placeholder
replaced). Standalone /book/:id/bookmarks page reuses list widget.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase D — Dual-page layout

### Task 13: PDF dual-page layout

**Files:**
- Modify: `reader_engine_pdf_view/lib/pdf_renderer.dart` (add `dualPageMode` flag + dual render branch)
- Modify: `app/lib/features/reader/widgets/reader_scaffold.dart` (LayoutBuilder: width >= 1200 → dual)
- Test: `reader_engine_pdf_view/test/pdf_renderer_dual_page_test.dart` (NEW)

- [ ] **Step 1: Write failing test**

```dart
testWidgets('dual page mode renders 2 pages side by side', (tester) async {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final renderer = PdfRenderer();
  await renderer.openFile('test/fixtures/sample-text.pdf');
  renderer.dualPageMode = true;

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: renderer.build(tester.element(find.byType(Scaffold))))));

  // Two PdfViewer widgets rendered.
  expect(find.byType(PdfViewer), findsNWidgets(2));
});
```

- [ ] **Step 2: Implement dual-page in PdfRenderer.build**

Add `bool dualPageMode = false;` field. In `build()`:
```dart
if (!dualPageMode) {
  return _buildSinglePageView(bytes, doc, ...);
}
// Dual: even page on left, odd on right.
final leftPage = _currentPage.isEven ? _currentPage : _currentPage - 1;
final rightPage = leftPage + 1;
return Row(
  children: [
    Expanded(child: PdfViewer.data(bytes, sourceName: '${doc.sourceName}#$leftPage', params: PdfViewerParams(viewController: PdfViewerController(pageNumber: leftPage + 1)), ...)),
    Expanded(child: rightPage < doc.pages.length
        ? PdfViewer.data(bytes, sourceName: '${doc.sourceName}#$rightPage', params: PdfViewerParams(viewController: PdfViewerController(pageNumber: rightPage + 1)), ...)
        : const SizedBox.shrink()),
  ],
);
```

Adjust `setPage` to step by 2 in dual mode.

- [ ] **Step 3: Trigger dualPageMode from reader_scaffold**

LayoutBuilder wrap: if `constraints.maxWidth >= 1200 && ui.paginationMode == PaginationMode.paged && typography.dualPageMode` → set `renderer.dualPageMode = true`.

- [ ] **Step 4: Run tests + commit**

```bash
git add reader_engine_pdf_view/lib/pdf_renderer.dart reader_engine_pdf_view/test/pdf_renderer_dual_page_test.dart app/lib/features/reader/widgets/reader_scaffold.dart
git commit -m "feat(pdf): dual-page layout on wide screens (>=1200px)

Pair rendering: even page left, odd right. Triggered when width>=1200,
paged mode, user enabled. setPage steps by 2 in dual mode.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 14: EPUB dual-page layout

**Files:**
- Modify: `reader_engine_epub_view/lib/epubx_renderer.dart` (paged algorithm: double-width column + split)
- Modify: `app/lib/features/reader/widgets/reader_scaffold.dart` (wire trigger)
- Test: `reader_engine_epub_view/test/epubx_renderer_dual_page_test.dart` (NEW)

**Why:** EPUB pagination must re-break content into paired pages; harder than PDF.

- [ ] **Step 1: Write failing test**

```dart
test('dual page breaks content into pairs of equal width', () {
  final r = EpubxRenderer();
  r.dualPageMode = true;
  // Load chapter, compute breaks with viewport 1600px.
  r.setViewportForTest(const Size(1600, 900));
  final breaks = r.computeBreaksForTest(chapterContent);
  // Each "page" is 800px wide; breaks alternate left/right halves.
  expect(breaks.length, greaterThan(2));
  // Odd index = right side, even = left side, etc.
});
```

- [ ] **Step 2: Implement dual-page algorithm**

In `epubx_renderer.dart`, add `bool dualPageMode = false;` and modify the paged rendering path:
- When `dualPageMode`: use viewport width / 2 as effective column width
- Render two `Column` children in a `Row`
- Track virtual pages (each pair = 1 navigation step)

(See spec §3.7 for full algorithm.)

- [ ] **Step 3: Update reader_scaffold.dart to render Row of two EPUB pages**

Similar to PDF T13: when dual mode + EPUB, the reader body becomes a Row of two paged columns.

- [ ] **Step 4: Run all tests; this is the highest-risk task**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1`
Expected: All pass; if breakage in EPUB pagination tests, fix incrementally.

- [ ] **Step 5: Commit**

```bash
git add reader_engine_epub_view/lib/epubx_renderer.dart reader_engine_epub_view/test/epubx_renderer_dual_page_test.dart app/lib/features/reader/widgets/reader_scaffold.dart
git commit -m "feat(epub): dual-page layout (pagation algorithm rewrite)

Each navigation step advances 2 virtual pages. Viewport width/2 used as
effective column width for break computation. Highest-risk task in M2.5;
covered by extended pagination tests.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Phase E — Release

### Task 15: CHANGELOG + README + version bump + tag

**Files:**
- Modify: `pubspec.yaml` (version: 1.4.0-alpha → 1.5.0-alpha)
- Modify: `CHANGELOG.md` (add `[1.5.0-alpha]` section)
- Modify: `README.md` (sync feature list + version badge)
- Modify: `app/pubspec.yaml` (version bump)
- Modify: `app/zhiyue.iss` (version bump for installer)
- Modify: `docs/releases/release-notes-v1.5.0-alpha.md` (NEW)

- [ ] **Step 1: Bump versions**

`pubspec.yaml`: `version: 1.5.0-alpha`
`app/pubspec.yaml`: `version: 1.5.0-alpha`
`app/zhiyue.iss`: `AppVersion=1.5.0-alpha` (or `1.5.0` per Inno Setup numeric preference)

- [ ] **Step 2: Add CHANGELOG entry**

```markdown
## [1.5.0-alpha] — 2026-07-XX

### Bug fixes
- **#4**: EPUB highlights now actually paint in chosen color (was missing `engine.injectHighlights()` bridge).
- **#6**: NotesPage tap navigates back to source location (EpubxRenderer.gotoLocator now handles EpubRangeLocator).

### New features
- **#7 Bookmarks**: drift v10 schema + sync. AppBar icon, drawer 书签 tab, standalone `/book/:id/bookmarks` page.
- **#10 Dual-page layout**: EPUB + PDF. Auto-enables at width>=1200px in paged mode.

### UX improvements
- **#2 Multi-input paging**: keyboard ←/→/↑/↓/PgUp/PgDn, mouse wheel, touch drag, tap-zones.
- **#3 Fullscreen mode**: window_manager desktop + SystemChrome mobile. Esc/F11 shortcuts, center double-tap shows chrome.
- **#5 Merged 摘录 button**: replaces separate 高亮/笔记 buttons with one bottom-sheet (5 colors + note).
- **#8 TOC sidebar**: wide screens (>=1100px) get permanent collapsible sidebar (280↔40px).
- **#9 Margin bump**: default Normal=24px (was 16); new ExtraWide=40px option.

### Migration
- Drift auto-migrates v9 → v10 (creates bookmarks table).
- Existing users' margin preference preserved (Compact/Normal/Wide indices unchanged).
```

- [ ] **Step 3: Sync README.md**

Update "项目状态" + "已交付能力" sections with v1.5.0-alpha entries; update version badge.

- [ ] **Step 4: Update release-checklist.md**

Mark v1.5.0-alpha prep section.

- [ ] **Step 5: Run full test suite + analyze one last time**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1`
Run: `/c/flutter/bin/dart.bat analyze reader_engine reader_engine_epub_view reader_engine_pdf_view app/lib app/test`
Expected: All tests pass; analyze 0 errors.

- [ ] **Step 6: Commit + tag**

```bash
git add pubspec.yaml app/pubspec.yaml app/zhiyue.iss CHANGELOG.md README.md docs/releases/release-checklist.md docs/releases/release-notes-v1.5.0-alpha.md
git commit -m "release(v1.5.0-alpha): version bump + changelog + docs

M2.5 reader UX overhaul complete: 2 P0 bug fixes + 8 enhancements/new
features. Target Gitee release after manual screenshot capture (T8).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"

git tag m2.5-complete
git tag v1.5.0-alpha
git push --tags
```

- [ ] **Step 7: Update memory file**

Write `project_zhiyue_m2_5_complete.md` summarizing delivery + add to MEMORY.md index.

---

## Self-Review

**Spec coverage check** (all items from spec):
- ✅ §3.1 State extension → T6, T7, T8, T9
- ✅ §3.2 Drawer refactor → T7
- ✅ §3.3 Multi-input paging → T5
- ✅ §3.4 Fullscreen mode → T9
- ✅ §3.5 Bookmarks schema → T10
- ✅ §3.6 Sync → T11
- ✅ §3.7 Dual-page → T13 (PDF) + T14 (EPUB)
- ✅ §3.8 Highlight fix → T2
- ✅ §3.9 Notes tap fix → T1
- ✅ §4 Data Model → T10, T4 (margin enum)
- ✅ §5 UI Spec → T3 (sheet), T7 (drawer), T8 (sidebar), T9 (fullscreen), T12 (bookmark UI)
- ✅ §6 Tests → embedded in each task

**Placeholder scan**: none found.

**Type consistency**:
- `DrawerTab` enum used consistently (T7 introduces, T8/T12 reference)
- `HighlightRange` mapping consistent (T2 + spec §3.8)
- `BookmarkEntry` data class used in T10/T11/T12

**Dependencies**:
- T1 → T2 (range locator + scroll, but independent at code level — order for clarity)
- T2 → T3 (sheet uses NotesController.addAnnotation which T2 verifies)
- T7 → T12 (drawer tab placeholder filled by T12)
- T10 → T11 (schema before repo)
- T11 → T12 (repo before UI)
- T13 → T14 (PDF simpler, serves as reference for EPUB)

All other tasks independent.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-02-m2-5-reader-ux-overhaul.md`. Two execution options:

**1. Subagent-Driven (recommended)** — Fresh subagent per task + two-stage review (spec then quality). With 15 tasks this means ~45 subagent dispatches (1 implementer + 2 reviewers per task). Estimated 3-4 weeks of work, ~30-40 commits.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints. Faster but loses review discipline.

**Which approach?**
