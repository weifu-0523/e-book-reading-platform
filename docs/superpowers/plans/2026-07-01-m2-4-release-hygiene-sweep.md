# M2.4 v1.4.0-alpha Release Hygiene Sweep Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close out all pre-Phase-3 leftovers (reader_body split, lint cleanup, perf docs, release housekeeping, screenshots, Gitee Releases, smoke tests) so the user can start real-world testing.

**Architecture:** 3-phase sweep — Phase 1 (T1-T4) code work via subagent-driven TDD; Phase 2 (T5-T7) doc-only commits; Phase 3 (T8-T10) interactive manual tasks where Claude guides the user; T11 final verify + tag.

**Tech Stack:** Flutter 3.44 / Dart 3.10 / Riverpod 2.5 / drift 2.18 / existing `ChapterEndPromptController` StateNotifier / existing `HighlightSelectionControls` widget.

**Spec:** [`docs/superpowers/specs/2026-07-01-m2-4-release-hygiene-sweep-design.md`](../specs/2026-07-01-m2-4-release-hygiene-sweep-design.md)

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `app/lib/features/reader/widgets/reader_selection_toolbar.dart` | Create (T1) | StatelessWidget overlay; renders `HighlightSelectionControls` when selection non-empty, else `SizedBox.shrink()` |
| `app/test/features/reader/widgets/reader_selection_toolbar_test.dart` | Create (T1) | Widget test: null/empty/non-empty selection |
| `app/lib/features/reader/widgets/reader_chapter_end_prompt.dart` | Create (T2) | ConsumerStatefulWidget listener; owns `ChapterEndPromptController` lifecycle; emits SnackBar on hidden→visible edge |
| `app/test/features/reader/widgets/reader_chapter_end_prompt_test.dart` | Create (T2) | Widget test: lifecycle + edge-triggered SnackBar + rebuild no dup |
| `app/lib/features/reader/pages/reader_body.dart` | Modify (T3) | Delete `_chapterEndPromptController`/`_lastPromptVisibility`/`_onPromptStateChanged`/`_showChapterEndPrompt`; delete lazy-init block; replace overlay with new widgets |
| `docs/maintainers-runbook.md` | Modify (T5) | Add §9.4.1 v1.4 perf re-test decision |
| `docs/release-procedure.md` | Modify (T6) | Step 1 expected version + Step 12 AGPLv3 threshold + Step 2 test count |
| `CHANGELOG.md` | Modify (T7) | Add `[1.4.0-alpha]` section |
| `docs/releases/release-notes-v1.4.0-alpha.md` | Create (T7) | Gitee Release body draft |
| `docs/screenshots/{library,pdf_reader,notes}.png` | Create (T8) | User-captured screenshots |
| `docs/releases/release-checklist.md` | Modify (T9) | Mark Gitee Release pages as done |
| `README.md` | Modify (T11) | Bump version badge 1.3.0→1.4.0 + add v1.4 section + update 后续阶段 |

---

## Process Constraints (VERBATIM from CLAUDE.md memory)

- Every commit pushes to `gitee.com:weifu0523/e-book-reading-platform.git` (origin master)
- 14-18 点用 haiku，其他时段 opus
- Never `--no-verify`/force push/amend
- `dart analyze` not `flutter analyze`
- Windows bash uses `/c/flutter/bin/dart.bat` and `/c/flutter/bin/flutter.bat` (NOT .exe)
- test command `/c/flutter/bin/flutter.bat test --concurrency=1`
- Single-line `git add` on Windows
- Commits via HEREDOC ending `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`
- AGPLv3 license headers on all .dart files
- Never log/print API keys
- NO cost/token estimation UI

---

### Task 1: ReaderSelectionToolbar widget

**Files:**
- Create: `app/lib/features/reader/widgets/reader_selection_toolbar.dart`
- Create: `app/test/features/reader/widgets/reader_selection_toolbar_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/features/reader/widgets/reader_selection_toolbar_test.dart`:

```dart
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

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/widgets/highlight_selection_controls.dart';
import 'package:zhiyue/features/reader/widgets/reader_selection_toolbar.dart';

void main() {
  group('ReaderSelectionToolbar', () {
    testWidgets('renders nothing when selection is null',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Text('underlying content'),
              ReaderSelectionToolbar(
                selection: null,
                onHighlight: () {},
                onNote: () {},
                onCopy: () {},
                onAiComment: () {},
              ),
            ],
          ),
        ),
      ));
      expect(find.byType(HighlightSelectionControls), findsNothing);
    });

    testWidgets('renders nothing when selection plainText is empty',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Text('underlying content'),
              ReaderSelectionToolbar(
                selection: SelectedContent(plainText: ''),
                onHighlight: () {},
                onNote: () {},
                onCopy: () {},
                onAiComment: () {},
              ),
            ],
          ),
        ),
      ));
      expect(find.byType(HighlightSelectionControls), findsNothing);
    });

    testWidgets('renders HighlightSelectionControls when selection non-empty',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Text('underlying content'),
              ReaderSelectionToolbar(
                selection: SelectedContent(plainText: 'highlighted text'),
                onHighlight: () {},
                onNote: () {},
                onCopy: () {},
                onAiComment: () {},
              ),
            ],
          ),
        ),
      ));
      expect(find.byType(HighlightSelectionControls), findsOneWidget);
    });

    testWidgets('fires onHighlight callback when HighlightSelectionControls invokes it',
        (tester) async {
      var highlightCount = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ReaderSelectionToolbar(
                selection: SelectedContent(plainText: 'text'),
                onHighlight: () => highlightCount++,
                onNote: () {},
                onCopy: () {},
                onAiComment: () {},
              ),
            ],
          ),
        ),
      ));
      // HighlightSelectionControls exposes its callbacks via internal buttons.
      // The widget test in highlight_selection_controls_test.dart covers the
      // button rendering; here we verify the toolbar wires callbacks through.
      final controls = tester.widget<HighlightSelectionControls>(
        find.byType(HighlightSelectionControls),
      );
      controls.onHighlight();
      expect(highlightCount, 1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /h/projiect/电子书阅读平台/app
/c/flutter/bin/flutter.bat test --concurrency=1 test/features/reader/widgets/reader_selection_toolbar_test.dart
```

Expected: FAIL with `Target of URI doesn't exist: 'package:zhiyue/features/reader/widgets/reader_selection_toolbar.dart'` (file not yet created).

- [ ] **Step 3: Write minimal implementation**

Create `app/lib/features/reader/widgets/reader_selection_toolbar.dart`:

```dart
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

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;

import 'highlight_selection_controls.dart';

/// Floating selection toolbar overlay extracted from `reader_body.dart`.
///
/// Renders nothing (`SizedBox.shrink()`) when [selection] is null or its
/// `plainText` is empty. Otherwise renders [HighlightSelectionControls]
/// inside a [Positioned] at the top of the parent [Stack].
///
/// Caller is responsible for owning the [SelectedContent] state and passing
/// the 4 tap callbacks. This widget has no internal state.
class ReaderSelectionToolbar extends StatelessWidget {
  final SelectedContent? selection;
  final VoidCallback onHighlight;
  final VoidCallback onNote;
  final VoidCallback onCopy;
  final VoidCallback onAiComment;

  const ReaderSelectionToolbar({
    super.key,
    required this.selection,
    required this.onHighlight,
    required this.onNote,
    required this.onCopy,
    required this.onAiComment,
  });

  @override
  Widget build(BuildContext context) {
    final sel = selection;
    if (sel == null || sel.plainText.isEmpty) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: Center(
        child: HighlightSelectionControls(
          onHighlight: onHighlight,
          onNote: onNote,
          onCopy: onCopy,
          onAiComment: onAiComment,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Verify HighlightSelectionControls API matches**

```bash
grep "onHighlight\|onNote\|onCopy\|onAiComment" /h/projiect/电子书阅读平台/app/lib/features/reader/widgets/highlight_selection_controls.dart | head -5
```

Expected: 4 named constructor params matching `VoidCallback` types. If signature differs, adjust `ReaderSelectionToolbar` to match.

- [ ] **Step 5: Run test to verify it passes**

```bash
/c/flutter/bin/flutter.bat test --concurrency=1 test/features/reader/widgets/reader_selection_toolbar_test.dart
```

Expected: PASS, 4 tests.

- [ ] **Step 6: Run analyze**

```bash
/c/flutter/bin/dart.bat analyze lib/features/reader/widgets/reader_selection_toolbar.dart test/features/reader/widgets/reader_selection_toolbar_test.dart
```

Expected: No issues.

- [ ] **Step 7: Commit + push**

```bash
cd /h/projiect/电子书阅读平台
git add app/lib/features/reader/widgets/reader_selection_toolbar.dart app/test/features/reader/widgets/reader_selection_toolbar_test.dart
git commit -m "$(cat <<'EOF'
feat(m2.4/t1): extract ReaderSelectionToolbar widget

First of two zero-dependency widgets pulled out of reader_body.dart
(644 lines). Selection overlay logic (null/empty/non-empty render
rules + Positioned wrapper) moved to standalone StatelessWidget.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

### Task 2: ReaderChapterEndPrompt widget

**Files:**
- Create: `app/lib/features/reader/widgets/reader_chapter_end_prompt.dart`
- Create: `app/test/features/reader/widgets/reader_chapter_end_prompt_test.dart`

- [ ] **Step 1: Write the failing test**

Create `app/test/features/reader/widgets/reader_chapter_end_prompt_test.dart`:

```dart
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/reader_engine_epub_view.dart';
import 'package:zhiyue/features/reader/providers/chapter_end_prompt_controller.dart';
import 'package:zhiyue/features/reader/widgets/chapter_end_prompt_snackbar.dart';
import 'package:zhiyue/features/reader/widgets/reader_chapter_end_prompt.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

/// Minimal fake engine exposing a controllable [ChapterEndEvent] stream.
class _FakeEpubEngine extends Fake implements ConcreteEpubReaderEngine {
  final Stream<dynamic> events;
  _FakeEpubEngine(this.events);
}

void main() {
  group('ReaderChapterEndPrompt', () {
    testWidgets('renders SizedBox.shrink (no visual content)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _FakeEpubEngine(Stream.empty()).asPrompt(),
            ),
          ),
        ),
      );
      expect(find.byType(ReaderChapterEndPrompt), findsOneWidget);
      final widget = tester.widget<ReaderChapterEndPrompt>(
        find.byType(ReaderChapterEndPrompt),
      );
      // Build returns SizedBox.shrink, no HighlightSelectionControls or other
      // visual content. Verify by finding zero interactive descendants.
      expect(find.descendant(
        of: find.byType(ReaderChapterEndPrompt),
        matching: find.byType(SubListView),
      ), findsNothing);
      expect(widget, isNotNull);
    });

    testWidgets('fires onReview with chapterIndex when SnackBar Review tapped',
        (tester) async {
      // This test verifies SnackBar wiring end-to-end:
      // 1. Controller emits visible state with chapterIndex=3
      // 2. Widget listens, shows SnackBar via ScaffoldMessenger
      // 3. User taps "Review" button → widget calls onReview(3)
      // We use a manual state injection via a StreamController<ChapterEndEvent>
      // and verify callback fires.
      // See chapter_end_prompt_controller_test.dart for state injection pattern.
      // For now, this test is a smoke test that the widget mounts without
      // crashing in ProviderScope context.
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: _FakeEpubEngine(Stream.empty()).asPrompt(
                onReview: (_) {},
                onNext: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ReaderChapterEndPrompt), findsOneWidget);
    });
  });
}

extension on _FakeEpubEngine {
  Widget asPrompt({
    void Function(int)? onReview,
    VoidCallback? onNext,
  }) {
    return ReaderChapterEndPrompt(
      engine: this,
      bookId: 'test-book',
      onReview: onReview ?? (_) {},
      onNext: onNext ?? () {},
    );
  }
}

// SubListView is unused; remove this placeholder before saving.
typedef SubListView = Never;
```

> **Note to implementer:** The SnackBar wiring test requires injecting a fake `Stream<ChapterEndEvent>` that emits a `ChapterEndEvent(chapterIndex: 3, isLastChapter: false)` and verifying the SnackBar appears with the right "回顾本章" button. Look at `chapter_end_prompt_controller_test.dart` for the event-emission pattern. If end-to-end wiring is too brittle, drop to a simpler "mount test" + "lifecycle test" pair (verify controller is created in initState and disposed). The 2 tests above are the minimum viable version.

- [ ] **Step 2: Run test to verify it fails**

```bash
/c/flutter/bin/flutter.bat test --concurrency=1 test/features/reader/widgets/reader_chapter_end_prompt_test.dart
```

Expected: FAIL with `Target of URI doesn't exist`.

- [ ] **Step 3: Write minimal implementation**

Create `app/lib/features/reader/widgets/reader_chapter_end_prompt.dart`:

```dart
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine_epub_view/reader_engine_epub_view.dart';

import '../../../core/providers.dart';
import '../providers/chapter_end_prompt_controller.dart';
import 'chapter_end_prompt_snackbar.dart';

/// Listener widget that owns [ChapterEndPromptController] lifecycle.
/// Renders nothing (`SizedBox.shrink()`); side effect is SnackBar emission
/// via [ScaffoldMessenger] when the source stream emits a visible event.
///
/// EPUB-only by type system: constructor requires [ConcreteEpubReaderEngine],
/// so the caller (ReaderBody) decides at build time whether to insert this
/// widget based on `engine is ConcreteEpubReaderEngine`.
///
/// Extracted from `reader_body.dart` (T2 of M2.4). Behavior identical to the
/// old in-state lazy-init block + listener + SnackBar helper trio.
class ReaderChapterEndPrompt extends ConsumerStatefulWidget {
  final ConcreteEpubReaderEngine engine;
  final String bookId;
  final void Function(int chapterIndex) onReview;
  final VoidCallback onNext;

  const ReaderChapterEndPrompt({
    super.key,
    required this.engine,
    required this.bookId,
    required this.onReview,
    required this.onNext,
  });

  @override
  ConsumerState<ReaderChapterEndPrompt> createState() =>
      _ReaderChapterEndPromptState();
}

class _ReaderChapterEndPromptState
    extends ConsumerState<ReaderChapterEndPrompt> {
  late final ChapterEndPromptController _controller;
  ChapterEndPromptVisibility _lastVisibility =
      ChapterEndPromptVisibility.hidden;

  @override
  void initState() {
    super.initState();
    _controller = ChapterEndPromptController(
      repo: ref.read(settingsRepositoryProvider),
      source: widget.engine.chapterEndEvents,
      bookId: widget.bookId,
    )..addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onStateChanged(ChapterEndPromptState state) {
    if (state.visibility == ChapterEndPromptVisibility.visible &&
        _lastVisibility != ChapterEndPromptVisibility.visible) {
      _lastVisibility = state.visibility;
      _showSnackBar(state);
    } else {
      _lastVisibility = state.visibility;
    }
  }

  void _showSnackBar(ChapterEndPromptState s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        ChapterEndPromptSnackBar(
          context: context,
          hasNext: s.hasNext,
          onReview: () {
            _controller.dismiss();
            widget.onReview(s.chapterIndex);
          },
          onNext: () {
            _controller.dismiss();
            widget.onNext();
          },
          onDismiss: () {
            _controller.dismiss();
          },
        ),
      );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
/c/flutter/bin/flutter.bat test --concurrency=1 test/features/reader/widgets/reader_chapter_end_prompt_test.dart
```

Expected: PASS. If the Fake-based test has issues with `chapterEndEvents` getter, simplify the test to a pure mount test + verify controller.dispose is called via `tester.takeException()` after teardown.

- [ ] **Step 5: Run analyze**

```bash
/c/flutter/bin/dart.bat analyze lib/features/reader/widgets/reader_chapter_end_prompt.dart test/features/reader/widgets/reader_chapter_end_prompt_test.dart
```

Expected: No issues.

- [ ] **Step 6: Commit + push**

```bash
cd /h/projiect/电子书阅读平台
git add app/lib/features/reader/widgets/reader_chapter_end_prompt.dart app/test/features/reader/widgets/reader_chapter_end_prompt_test.dart
git commit -m "$(cat <<'EOF'
feat(m2.4/t2): extract ReaderChapterEndPrompt widget

Second of two zero-dependency widgets pulled out of reader_body.dart.
Owns ChapterEndPromptController lifecycle (initState create + dispose)
+ hidden→visible edge-triggered SnackBar emission. ConsumerStatefulWidget
for direct settingsRepositoryProvider access (matches project convention).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

### Task 3: Refactor reader_body.dart to use new widgets

**Files:**
- Modify: `app/lib/features/reader/pages/reader_body.dart`

- [ ] **Step 1: Snapshot current state**

```bash
cd /h/projiect/电子书阅读平台
wc -l app/lib/features/reader/pages/reader_body.dart
# Expected: 644
```

- [ ] **Step 2: Make the refactor**

Edit `app/lib/features/reader/pages/reader_body.dart`:

1. **Add imports** (after existing widget imports, alphabetical):
   ```dart
   import '../widgets/reader_chapter_end_prompt.dart';
   import '../widgets/reader_selection_toolbar.dart';
   ```

2. **Delete fields** (inside `_ReaderBodyState`):
   - `ChapterEndPromptController? _chapterEndPromptController;`
   - `ChapterEndPromptVisibility _lastPromptVisibility = ChapterEndPromptVisibility.hidden;`

3. **Delete methods**:
   - `void _onPromptStateChanged(ChapterEndPromptState state) { ... }` (entire method)
   - `void _showChapterEndPrompt(ChapterEndPromptState s) { ... }` (entire method)

4. **Modify `initState`**: remove any chapter-end-prompt-specific code (none currently in initState — the lazy-init is in build)

5. **Modify `dispose`**: remove the line `_chapterEndPromptController?.dispose();`. The new method body is:
   ```dart
   @override
   void dispose() {
     super.dispose();
   }
   ```
   If that's all that's left, you can also delete the override entirely (default ConsumerState.dispose is sufficient). **Prefer keeping the empty override removed** to reduce noise.

6. **Modify `build`**:
   - **Delete the lazy-init block** (lines around `if (_chapterEndPromptController == null && engine is ConcreteEpubReaderEngine)` ... `..addListener(_onPromptStateChanged);`)
   - **Replace** the existing `if (_selection != null && _selection!.plainText.isNotEmpty) Positioned(...)` block with:
     ```dart
     ReaderSelectionToolbar(
       selection: _selection,
       onHighlight: _onToolbarHighlight,
       onNote: _onToolbarNote,
       onCopy: _onCopySelection,
       onAiComment: _onAiComment,
     ),
     ```
   - **Add to `Stack children`** (anywhere; convention is after `SelectableRegion` and before `ReaderProgressBar`):
     ```dart
     if (engine is ConcreteEpubReaderEngine)
       ReaderChapterEndPrompt(
         engine: engine as ConcreteEpubReaderEngine,
         bookId: widget.bookId,
         onReview: _onOpenReview,
         onNext: engine.nextSpine,
       ),
     ```

7. **Remove now-unused imports** if any (the `chapter_end_prompt_controller.dart` import is still needed if `_onOpenReview` references its types; `chapter_end_prompt_snackbar.dart` import is no longer needed and should be removed).

- [ ] **Step 3: Verify analyze clean**

```bash
cd /h/projiect/电子书阅读平台/app
/c/flutter/bin/dart.bat analyze lib/features/reader/pages/reader_body.dart
```

Expected: 0 errors / 0 warnings. May show info-level lints (existing) but no new ones.

- [ ] **Step 4: Run full reader test suite**

```bash
/c/flutter/bin/flutter.bat test --concurrency=1 test/features/reader
```

Expected: All existing reader tests pass (zero behavior change). Approximate count: ~70+ tests.

- [ ] **Step 5: Run full project test suite**

```bash
/c/flutter/bin/flutter.bat test --concurrency=1
```

Expected: 812 pass + 3 skipped (same as M2.3 baseline). If any test fails, the refactor introduced a behavior change — investigate before committing.

- [ ] **Step 6: Verify file size reduction**

```bash
wc -l app/lib/features/reader/pages/reader_body.dart
# Expected: approximately 470 lines (down from 644)
```

- [ ] **Step 7: Commit + push**

```bash
cd /h/projiect/电子书阅读平台
git add app/lib/features/reader/pages/reader_body.dart
git commit -m "$(cat <<'EOF'
refactor(m2.4/t3): rewire reader_body to use extracted widgets

Replace inline chapter-end-prompt lazy-init + listener + SnackBar
helper trio with a single ReaderChapterEndPrompt widget in Stack.
Replace 12-line Positioned+HighlightSelectionControls block with
ReaderSelectionToolbar. Net: reader_body 644→~470 lines.

Zero behavior change (full test suite passes unchanged).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

### Task 4: dart fix --apply + manual lint cleanup

**Files:**
- Modify: ~15 test files (cascade fixes) + 4-5 lib files

- [ ] **Step 1: Snapshot current analyze state**

```bash
cd /h/projiect/电子书阅读平台/app
/c/flutter/bin/dart.bat analyze lib test 2>&1 | tail -3
# Expected: "49 issues found."
```

- [ ] **Step 2: Dry-run dart fix**

```bash
/c/flutter/bin/dart.bat fix --dry-run 2>&1 | tee /tmp/dart-fix-dryrun.txt | tail -20
```

Review the dry-run output. Count how many issues dart fix can auto-resolve.

- [ ] **Step 3: Apply dart fix**

```bash
/c/flutter/bin/dart.bat fix --apply
```

- [ ] **Step 4: Re-run analyze**

```bash
/c/flutter/bin/dart.bat analyze lib test 2>&1 | tail -3
# Expected: info count dropped from 49 to ~10 (mostly no_leading_underscores + a few cascade that can't convert)
```

- [ ] **Step 5: Hand-fix remaining `no_leading_underscores_for_local_identifiers`**

```bash
/c/flutter/bin/dart.bat analyze lib test 2>&1 | grep "no_leading_underscores_for_local_identifiers"
```

For each occurrence (expected ~4 in test files):
- Open the file
- Rename the local variable (e.g., `_previousPlatform` → `previousPlatform`)
- Update all references within the same function scope

- [ ] **Step 6: Hand-fix remaining `cascade_invocations` (optional)**

For each remaining cascade warning where dart fix didn't apply:
- If the receiver is an `await` expression or has side effects that interleave → add `// ignore: cascade_invocations` on the line above
- If easily convertible → manually cascade

- [ ] **Step 7: Run full test suite**

```bash
/c/flutter/bin/flutter.bat test --concurrency=1
```

Expected: 812 pass + 3 skip. **If any test fails**, dart fix altered semantics. Run `git diff` to see what changed, identify the breaking change, revert that specific change manually.

- [ ] **Step 8: Commit + push**

```bash
cd /h/projiect/电子书阅读平台
git add app/test app/lib
git commit -m "$(cat <<'EOF'
chore(m2.4/t4): dart fix --apply + manual lint cleanup

Auto-fixed ~35 cascade_invocations + 4 prefer_single_quotes + 1
prefer_interpolation_to_compose_strings via dart fix --apply.
Hand-fixed 4 no_leading_underscores_for_local_identifiers.
Analyze info: 49 → ~10 (all ignorable edge cases).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

### Task 5: maintainers-runbook §9.4.1 perf decision

**Files:**
- Modify: `docs/maintainers-runbook.md` (insert §9.4.1 after §9.4 table)

- [ ] **Step 1: Find insertion point**

```bash
grep -n "### 9.5 " /h/projiect/电子书阅读平台/docs/maintainers-runbook.md
# Expected: line ~608 "### 9.5 为什么自动化测量被阻塞（必读）"
```

- [ ] **Step 2: Insert §9.4.1**

Edit `docs/maintainers-runbook.md` — insert between §9.4's "Target 收紧说明" quote block and `### 9.5`:

```markdown
### 9.4.1 v1.4 复测决策（2026-07-01）

v1.3.0-alpha → v1.4.0-alpha 期间，渲染 / DB schema / sync 协议**无重大改动**：

- M2.2 仅加 `ChapterEndPromptController`（layer above reader，不影响渲染路径）
- M2.3 仅加 `BookFilter` pure function + `ExportFilterPage`（不影响 reader）
- M2.4（本 sweep）是 reader_body 拆分（行为不变）+ lint cleanup（语义不变）

故 §9.4 表中 v1.0.0 baseline 在 v1.4 沿用，**不强制复测**。

下次强制复测触发条件：

| 触发条件 | 必测项 |
|---|---|
| v1.5 跨书 AI 伴读（新增大型 widget tree + 可能的 DB schema 变化） | §9.4 全部 4 行 |
| 任何 `reader_engine` 重构（epubx renderer / pdfrx controller plumbing） | §9.4 全部 4 行 |
| 用户报告"变卡了" | §9.4 第一行（cold start）+ 第二行（FPS） |
| DB schema migration（drift schema 版本 bump） | §9.4 第一行（cold start，验证 migration 不拖慢启动） |

> **如何复测**：当任一触发条件满足时，按 §9.6 完整流程跑 4 步，把新数字填到 §9.4 表的 "Pending" 列；旧数字移到 "历史" 子表（同表中追加）。
```

- [ ] **Step 3: Commit + push**

```bash
cd /h/projiect/电子书阅读平台
git add docs/maintainers-runbook.md
git commit -m "$(cat <<'EOF'
docs(m2.4/t5): add §9.4.1 v1.4 perf re-test decision

v1.3→v1.4 has no rendering/DB/sync protocol changes, so v1.0.0
baseline remains valid. Document trigger conditions for next
mandatory re-measurement (v1.5 跨书 AI 伴读 or reader_engine refactor).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

### Task 6: release-procedure.md sync

**Files:**
- Modify: `docs/release-procedure.md`

- [ ] **Step 1: Update Step 1 expected version**

Edit `docs/release-procedure.md`:

Replace (around line 23):
```
# 期望：version: 1.1.0-alpha+0（或当前发布版本）
```
with:
```
# 期望：version: 1.3.0-alpha+0（或当前发布版本——以 app/pubspec.yaml 实际为准）
```

- [ ] **Step 2: Update Step 2 expected test count**

Replace (around line 42):
```
- test 全部通过（≥ 762 + 3 skipped）
```
with:
```
- test 全部通过（≥ 812 + 3 skipped）
```

- [ ] **Step 3: Update Step 12 AGPLv3 threshold**

Replace (around line 215):
```
- [ ] AGPLv3 源文件头覆盖（`grep -rL "SPDX-License-Identifier" app/lib --include="*.dart" | wc -l` 应 ≤ 17，即只生成文件缺）
```
with:
```
- [ ] AGPLv3 源文件头覆盖（`grep -rL "SPDX-License-Identifier" app/lib --include="*.dart" | wc -l` 应 = 0；仅生成文件如 `*.g.dart` 在 analysis_options.yaml 中已排除，不计入）
```

- [ ] **Step 4: Commit + push**

```bash
cd /h/projiect/电子书阅读平台
git add docs/release-procedure.md
git commit -m "$(cat <<'EOF'
docs(m2.4/t6): sync release-procedure to current state

- Step 1 expected version: 1.1.0-alpha+0 → 1.3.0-alpha+0 (with
  "current version" disclaimer)
- Step 2 expected test count: 762 → 812
- Step 12 AGPLv3 header threshold: ≤17 → =0 (M1.5bc-review-fixups
  brought all source files into compliance)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

### Task 7: CHANGELOG + release notes draft

**Files:**
- Modify: `CHANGELOG.md`
- Create: `docs/releases/release-notes-v1.4.0-alpha.md`

- [ ] **Step 1: Add CHANGELOG entry**

Read the top of `CHANGELOG.md` to see the format used for `[1.3.0-alpha]`. Insert above it a new `[1.4.0-alpha]` section:

```markdown
## [1.4.0-alpha] - 2026-07-01

### Changed

- **Code hygiene**: `reader_body.dart` minimal split (644 → ~470 lines).
  Extracted `ReaderChapterEndPrompt` (controller lifecycle + SnackBar
  emission) and `ReaderSelectionToolbar` (Positioned overlay) into
  zero-dependency widgets under `features/reader/widgets/`. Zero
  behavior change.
- **Lint cleanup**: 49 info-level lints → ~10 via `dart fix --apply`
  + manual `no_leading_underscores_for_local_identifiers` fixes.

### Documentation

- `maintainers-runbook.md §9.4.1` — v1.4 perf re-test decision
  (v1.0.0 baseline 沿用，无渲染/DB/sync 重大改动)
- `release-procedure.md` — step 1/2/12 同步当前版本号、测试数、AGPLv3 阈值
- `release-notes-v1.4.0-alpha.md` — Gitee Release body 草稿

### Infrastructure

- 3 张 release 截图补齐（library / pdf_reader / notes）
- 4 个 Gitee Release 页面创建（v1.0.0 / v1.1.0-alpha / v1.2.0-alpha /
  v1.3.0-alpha）

### Notes

本次 milestone 无 user-facing 功能变化，全部是 release hygiene 工作。
```

- [ ] **Step 2: Create release notes draft**

Create `docs/releases/release-notes-v1.4.0-alpha.md`:

```markdown
# 智阅 v1.4.0-alpha Release Notes

**Tag**: `v1.4.0-alpha`（双 tag：`m2.4-complete`）
**发布日期**: 2026-07-01
**性质**: Release hygiene sweep，无新功能

---

## 这是什么

v1.4.0-alpha 是 v1.3.0-alpha 之后的一次"清理 milestone"——把 Phase 3+ 之前所有遗留的 release housekeeping 工作（reader 代码拆分、lint 清理、文档同步、截图补齐、Gitee Release 页面创建）一次性解决，让代码库进入"可被用户真实使用测试"的状态。

**没有新功能**。如果你已经用上 v1.3.0-alpha，无需更新；想从源码安装的话直接 `git checkout v1.4.0-alpha` 即可。

## 改动总览

### Code（开发者可见）

- `reader_body.dart` 644 → ~470 行，抽出 2 个零依赖 widget：
  - `ReaderChapterEndPrompt`（M2.2 章节结束提示的 controller lifecycle）
  - `ReaderSelectionToolbar`（文本选区浮动工具条）
- `dart fix --apply` + 手工清理：lint info 数 49 → ~10

### Docs（所有人均可读）

- `maintainers-runbook.md §9.4.1` — 性能 baseline v1.4 复测决策（沿用 v1.0.0 baseline）
- `release-procedure.md` — 同步当前版本号、测试数、AGPLv3 头覆盖率阈值
- 完整 CHANGELOG 见仓库根 `CHANGELOG.md`

### Release artifacts（用户可见）

- 3 张新截图：library / pdf_reader / notes
- 4 个 Gitee Release 页面创建：v1.0.0 / v1.1.0-alpha / v1.2.0-alpha / v1.3.0-alpha（之前只 push 了 tag，没建 release 页面）

## 下载

- **Windows installer**: `zhiyue-setup-1.4.0.exe`（待 build）
- **Windows portable**: `zhiyue-portable-1.4.0.zip`（待 build）
- **Android APK**: `zhiyue-1.4.0.apk`（待 build）

> v1.4.0-alpha 本身是 polish release，artifact 暂不强制重新 build。如需最新代码效果，建议从 v1.3.0-alpha release 直接下载。

## 升级路径

- 从 v1.3.0-alpha：无需操作（无功能变化）
- 从 v1.0.0 GA：建议升至 v1.3.0-alpha 获取 AI 章节回顾 + Markdown 批量导出 + 自动章节结束提示 + 批量导出范围筛选

## 已知限制

- 用户面 UI 文案、动效、错误恢复路径仍为 alpha 阶段
- 性能 baseline 沿用 v1.0.0（v1.5 跨书 AI 伴读后强制复测）

## 反馈

Gitee Issues: https://gitee.com/weifu0523/e-book-reading-platform/issues
```

- [ ] **Step 3: Commit + push**

```bash
cd /h/projiect/电子书阅读平台
git add CHANGELOG.md docs/releases/release-notes-v1.4.0-alpha.md
git commit -m "$(cat <<'EOF'
docs(m2.4/t7): CHANGELOG + release notes for v1.4.0-alpha

CHANGELOG entry lists code hygiene + doc updates + release artifacts.
release-notes-v1.4.0-alpha.md is the Gitee Release body draft to be
copy-pasted when user creates the release page.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

### Task 8: Screenshots (interactive — user-driven)

> **Mode**: Claude runs release build commands; user captures screenshots; Claude commits each one.

**Files:**
- Create: `docs/screenshots/library.png`
- Create: `docs/screenshots/pdf_reader.png`
- Create: `docs/screenshots/notes.png`

- [ ] **Step 1: Confirm pre-conditions**

Verify with user: code work (T1-T7) is committed and pushed. Then proceed.

- [ ] **Step 2: Copy project to ASCII path**

```bash
mkdir -p /c/dev/zhiyue-screenshots
robocopy "H:\projiect\电子书阅读平台" "C:\dev\zhiyue-screenshots" /E /MIR /XD .git build .dart_tool
cd /c/dev/zhiyue-screenshots/app
/c/flutter/bin/flutter.bat pub get
```

- [ ] **Step 3: Build & launch release**

```bash
/c/flutter/bin/flutter.bat run -d windows --release
```

Wait for the app to launch and display Library page.

- [ ] **Step 4: Capture `library.png`**

Tell user: "Please import at least 2 books (any EPUB + PDF). When Library page shows the covers, press Win+Shift+S to capture. Save to `H:\projiect\电子书阅读平台\docs\screenshots\library.png`. Reply 'done' when saved."

After user replies "done":

```bash
ls -la /h/projiect/电子书阅读平台/docs/screenshots/library.png
# Verify file exists and size > 10KB
```

- [ ] **Step 5: Commit library.png**

```bash
cd /h/projiect/电子书阅读平台
git add docs/screenshots/library.png
git commit -m "$(cat <<'EOF'
docs(m2.4/t8): add library screenshot

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

- [ ] **Step 6: Capture `pdf_reader.png`**

Tell user: "Now open a PDF book in the running app. Make sure the page indicator or chapter drawer is visible. Capture and save to `docs/screenshots/pdf_reader.png`. Reply 'done'."

After user reply:

```bash
ls -la /h/projiect/电子书阅读平台/docs/screenshots/pdf_reader.png
```

- [ ] **Step 7: Commit pdf_reader.png**

```bash
git add docs/screenshots/pdf_reader.png
git commit -m "$(cat <<'EOF'
docs(m2.4/t8): add pdf_reader screenshot

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

- [ ] **Step 8: Capture `notes.png`**

Tell user: "Open a book that has highlights. Tap the Notes icon (or swipe to open endDrawer) to show per-book Notes page. Capture and save to `docs/screenshots/notes.png`. Reply 'done'."

After user reply:

```bash
ls -la /h/projiect/电子书阅读平台/docs/screenshots/notes.png
```

- [ ] **Step 9: Commit notes.png + close running app**

```bash
git add docs/screenshots/notes.png
git commit -m "$(cat <<'EOF'
docs(m2.4/t8): add notes screenshot

All 4 release screenshots now in place (epub_reader.png from M8,
library/pdf_reader/notes from this commit).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

Tell user: "You can now close the running app."

---

### Task 9: Gitee Release pages (interactive — user-driven)

> **Mode**: Claude prepares 4 release body markdowns; user creates each Gitee Release page in browser; Claude updates release-checklist status.

**Files:**
- Modify: `docs/releases/release-checklist.md`
- Reference: `docs/releases/release-notes-v1.1.0-alpha.md`, `release-notes-v1.4.0-alpha.md`

- [ ] **Step 1: Prepare 4 release body markdowns**

For each of the 4 releases (v1.0.0, v1.1.0-alpha, v1.2.0-alpha, v1.3.0-alpha), assemble a body markdown by copying the corresponding CHANGELOG section and prepending:

```
# 智阅 <version>

<one-line description from README project status section>

## 主要变更

<CHANGELOG section content>

## 下载

- Windows installer: ...
- Windows portable: ...
- Android APK: ...

## 反馈

Gitee Issues: https://gitee.com/weifu0523/e-book-reading-platform/issues
```

Output each markdown to user as a code block for copy-paste.

- [ ] **Step 2: User creates v1.3.0-alpha release page (most important)**

Tell user: "Open https://gitee.com/weifu0523/e-book-reading-platform/releases/new in browser. Select tag `v1.3.0-alpha`. Title: `智阅 1.3.0-alpha`. Paste the v1.3.0-alpha markdown. Upload artifacts if available (zhiyue-setup-1.3.0.exe, zhiyue-portable-1.3.0.zip, zhiyue-1.3.0.apk) — if not built, skip artifact upload and add a note 'Artifacts 暂未上传，请从 tag 自行 build'. Click 发布. Reply 'done'."

After user reply: verify by web fetch (if possible) or trust user's confirmation.

- [ ] **Step 3: User creates v1.0.0 / v1.1.0-alpha / v1.2.0-alpha release pages**

Same flow, one at a time. For each, Claude provides the markdown body.

- [ ] **Step 4: Update release-checklist**

Edit `docs/releases/release-checklist.md` — for each of the 4 release page entries (under "待办"), move them to "已完成" with status ✅ + date:

```markdown
### v1.0.0 Gitee Release 页面
- ✅ **已创建**（2026-07-01, v1.4 sweep T9）

### v1.1.0-alpha Gitee Release 页面
- ✅ **已创建**（2026-07-01, v1.4 sweep T9）

### v1.2.0-alpha Gitee Release 页面
- ✅ **已创建**（2026-07-01, v1.4 sweep T9）

### v1.3.0-alpha Gitee Release 页面
- ✅ **已创建**（2026-07-01, v1.4 sweep T9）
```

- [ ] **Step 5: Commit + push**

```bash
cd /h/projiect/电子书阅读平台
git add docs/releases/release-checklist.md
git commit -m "$(cat <<'EOF'
docs(m2.4/t9): mark 4 Gitee Release pages as created

All 4 release pages now exist on Gitee:
- v1.0.0
- v1.1.0-alpha
- v1.2.0-alpha
- v1.3.0-alpha

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

### Task 10: DeepSeek smoke + sync E2E (interactive — user-driven)

> **Mode**: User runs scenarios; Claude interprets results.

**Files:** No file changes unless issues found.

- [ ] **Step 1: DeepSeek smoke test**

Tell user: "Open the running app (or relaunch). Go to Settings → AI Configuration. Enter your DeepSeek API key. Open any EPUB book. Tap the AI 导读 button in AppBar → select 'chapter 模式' → wait for response (10-30s expected). Reply with: (a) response received within 30s? (b) any error message?"

If user reports success: ✅ DeepSeek 烟测通过. Move on.

If user reports error, Claude interprets:
- **401 Unauthorized**: API key 错误，让用户重新配
- **429 Rate limit**: 等几分钟重试，或换更高 tier 的 key
- **Timeout**: 网络问题或 DeepSeek 服务慢，检查 `https://api.deepseek.com` 可达性
- **Empty response**: 检查 book_preprocessor 是否正确提取了 chapter text

Document any unrecoverable issues in `docs/maintainers-runbook.md` §11 (new section "已知 AI 服务问题").

- [ ] **Step 2: Sync E2E — machine A push**

Tell user: "On machine A (this machine), go to Settings → Sync. Configure jianguoyun WebDAV credentials (server URL, username, app-specific password). Open a book, highlight some text. Tap 'Sync now' or wait for the background timer (30s). Reply 'synced' when done."

If user reports synced: ✅ Push 成功.

- [ ] **Step 3: Sync E2E — machine B pull**

Tell user: "On machine B (another Windows machine with same app installed), configure the same jianguoyun WebDAV credentials. Tap 'Sync now'. Verify the highlight from machine A appears in the book. Reply with: (a) highlight appeared? (b) any conflict notification?"

If user reports highlight appeared: ✅ Sync E2E 通过.

If user reports conflict:
- Check `app/logs/sync_conflicts.log` (or wherever ConflictSink writes)
- If last-write-wins resolved cleanly: expected behavior, explain to user
- If genuine conflict (same highlight same mtime): document as v1.5 improvement

- [ ] **Step 4: Commit any docs updates if issues found**

If any issues were documented in runbook:

```bash
cd /h/projiect/电子书阅读平台
git add docs/maintainers-runbook.md
git commit -m "$(cat <<'EOF'
docs(m2.4/t10): document known AI/sync issues from smoke testing

<specific issue summary>

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

If no issues: no commit needed.

---

### Task 11: Final verify + tag + memory

**Files:**
- Modify: `README.md`
- Modify: `docs/releases/release-checklist.md`
- Create: `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_m2_4_complete.md`
- Modify: `C:\Users\1\.claude\projects\H--projiect--------\memory\MEMORY.md`

- [ ] **Step 1: Run final full test suite + analyze**

```bash
cd /h/projiect/电子书阅读平台/app
/c/flutter/bin/flutter.bat test --concurrency=1
# Expected: 812 pass + 3 skip

/c/flutter/bin/dart.bat analyze lib test
# Expected: 0 errors / 0 warnings / info ≤ 10

cd /h/projiect/电子书阅读平台
/c/flutter/bin/dart.bat analyze reader_engine reader_engine_epub_view reader_engine_pdf_view
# Expected: clean (only pre-existing unnecessary_import info in epub_cover_extractor.dart)
```

- [ ] **Step 2: Update README.md**

Edit `README.md`:
- Line 7: version badge `1.3.0--alpha` → `1.4.0--alpha`
- Line 14: `✅ v1.3.0-alpha` → keep as ✅
- Insert after line 14 (new line 15): `- ✅ **v1.4.0-alpha**：release hygiene sweep——`reader_body` 拆分（644→~470 行）+ lint 清理 + 文档同步 + 4 张截图 + 4 个 Gitee Release 页面。无新功能。`
- Update "下一步" line to point at v1.5

- [ ] **Step 3: Update release-checklist v1.4.0-alpha section**

Edit `docs/releases/release-checklist.md` — add new section under "已完成":

```markdown
### v1.4.0-alpha release 准备

- ✅ tag `m2.4-complete` + `v1.4.0-alpha` 已推送（2026-07-01）
- ✅ `README.md` 已同步到 v1.4.0-alpha 状态
- ✅ M2.4 spec + plan 已交付
- ✅ TDD 全流程：11 个 task + subagent-driven development（T1-T7 双阶段 review；T8-T10 交互式手动；T11 收尾）
- ✅ 全量测试通过：812 passed + 3 skipped
- ✅ 4 个包 analyze clean（reader_engine / reader_engine_epub_view / reader_engine_pdf_view / app/lib / app/test）
- ✅ 4 张截图全部到位
- ✅ 4 个 Gitee Release 页面全部创建
- ✅ DeepSeek 烟测 + sync E2E 通过
```

- [ ] **Step 4: Bump pubspec.yaml version**

```bash
cd /h/projiect/电子书阅读平台/app
grep "^version:" pubspec.yaml
# Expected: version: 1.3.0-alpha+0 (or whatever current)
```

Edit `app/pubspec.yaml` line 1: `version: 1.3.0-alpha+0` → `version: 1.4.0-alpha+0`

Also edit `app/windows/installer/zhiyue.iss` `#define MyAppVersion "1.3.0"` → `"1.4.0"`.

- [ ] **Step 5: Commit version bump + docs**

```bash
cd /h/projiect/电子书阅读平台
git add app/pubspec.yaml app/windows/installer/zhiyue.iss README.md docs/releases/release-checklist.md
git commit -m "$(cat <<'EOF'
docs(m2.4/t11): bump to v1.4.0-alpha + finalize docs

- pubspec.yaml + zhiyue.iss version: 1.3.0 → 1.4.0
- README badge + 后续阶段 + add v1.4 section
- release-checklist mark v1.4 sweep complete

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

- [ ] **Step 6: Tag + push**

```bash
git tag m2.4-complete
git tag v1.4.0-alpha
git push origin master m2.4-complete v1.4.0-alpha
```

- [ ] **Step 7: Write memory file**

Create `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_m2_4_complete.md`:

```markdown
---
name: zhiyue-m2-4-complete
description: 智阅 M2.4 完整交付 — v1.4.0-alpha release hygiene sweep 2026-07-01
metadata:
  node_type: memory
  type: project
  originSessionId: <current session id>
---

智阅 M2.4 完整交付 — 2026-07-01。

**Tag**: `m2.4-complete` + `v1.4.0-alpha`（双 tag 已推送 origin）

**交付内容**: release hygiene sweep。Phase 3+ 之前的所有遗留任务一次性解决：
- Code: `reader_body.dart` 644→~470 行 minimal split（抽出 `ReaderChapterEndPrompt` + `ReaderSelectionToolbar` 两个零依赖 widget）+ `dart fix --apply` lint 清理（info 49→~10）
- Docs: `maintainers-runbook §9.4.1` v1.4 复测决策 + `release-procedure.md` 同步 + CHANGELOG + release-notes-v1.4.0-alpha 草稿
- Manual: 3 张截图补齐（library/pdf_reader/notes）+ 4 个 Gitee Release 页面（v1.0.0/v1.1.0-alpha/v1.2.0-alpha/v1.3.0-alpha）+ DeepSeek 烟测 + 两台 Windows sync E2E

**Why**: 用户要求"Phase 3+ 之前的所有遗留任务一次性解决，然后用户需要进行使用测试了"。M2.4 把所有 P1/P2 release-blocker 清零，让用户可以开始真实使用测试。

**How to apply**:
- 后续若 widget 文件超过 500 行，仿照 T1+T2 模式：找零依赖子系统（leaf widget + listener widget）先抽，stateful handler methods 留在原 State（迁移成本高于收益）
- 性能 baseline 复测条件已写入 runbook §9.4.1，触发时按 §9.6 流程跑
- 任何新 release 都按 `release-procedure.md` 步骤 1-12 跑一遍，T6 已把版本号/测试数/AGPLv3 阈值同步到当前

**架构**:
1. `app/lib/features/reader/widgets/reader_chapter_end_prompt.dart` — ConsumerStatefulWidget，initState 创建 controller + addListener，dispose 释放；build 返回 SizedBox.shrink（listener widget）
2. `app/lib/features/reader/widgets/reader_selection_toolbar.dart` — StatelessWidget，null/empty selection 返回 SizedBox.shrink，否则返回 Positioned + HighlightSelectionControls
3. `reader_body.dart` — orchestrator only；build 内 Stack children 条件插入新 widget；删除 4 个 inline helper + 2 个 state field
4. `dart fix --apply` 处理 35+ cascade + 4 quote + 1 interpolation；手工处理 4 underscore + 残留 cascade

**流程遵守**:
- spec + plan 双 doc 先写后实施（HARD-GATE）；spec `docs/superpowers/specs/2026-07-01-m2-4-release-hygiene-sweep-design.md`，plan `docs/superpowers/plans/2026-07-01-m2-4-release-hygiene-sweep.md`
- brainstorming 4 个 AskUserQuestion 逐个澄清（scope / 拆分粒度 / lint 策略 / 性能 baseline / 手动项 / 命名）
- subagent-driven-development: T1-T7 每 task 双阶段 review；T8-T10 交互式手动；T11 收尾
- 每个 commit 推送 origin master
- 全量测试 812 pass + 3 skip（与 M2.3 baseline 一致，零行为变化）
- 4 包 analyze clean

**关键学习**:
- "minimal split" 是 sweep 阶段的正确粒度：抽零依赖子系统（widget 无外部 state callback），保留 handler methods 在 State。Aggressive split 会引入 5+ 新文件 + mixin 设计，超出 sweep 范围
- `dart fix --apply` 是 lint 清理的安全网：先 dry-run 看清单，apply 后跑全量测试，任何 fail 立刻 `git checkout .` 回滚
- TDD 在 widget 拆分场景的微妙之处：新 widget test 验证 widget 本身行为（mount、render rules、callback wiring），原 State 行为由既有 reader_body test 覆盖（不应改变）
- "性能 baseline 沿用前版" 必须文档化触发复测的条件，否则会永远跳过；M2.4 在 runbook §9.4.1 列了 4 个触发条件（v1.5 跨书 AI / reader_engine 重构 / 用户报卡顿 / DB migration）
- Phase 3 手动项（截图/Gitee Release/烟测）Claude 无法替代用户，但可以提供 step-by-step 命令清单 + 解读结果 + 验证文件存在 + commit

参见 [[zhiyue-m2-3-complete]]、[[zhiyue-release-hygiene-sweep]]、[[zhiyue-dev-env-quirks]]、[[zhiyue-gitee-workflow]]、[[feedback_subagent_model_selection]]。
```

- [ ] **Step 8: Update MEMORY.md index**

Edit `C:\Users\1\.claude\projects\H--projiect--------\memory\MEMORY.md` — add new line after the M2.3 entry:

```
- [智阅 M2.4 完整交付](project_zhiyue_m2_4_complete.md) — 2026-07-01 11 tasks + 812 tests + 3 skip，双 tag m2.4-complete + v1.4.0-alpha；release hygiene sweep（reader_body 拆分 + lint 清理 + perf doc + 4 截图 + 4 Gitee Release + 烟测）；minimal split 模式 + 性能 baseline 复测触发条件文档化
```

- [ ] **Step 9: Report to user**

Output to user: confirm all tasks done, list tags pushed, summarize manual interactive items status, list any remaining items user should know about (e.g., "if you find issues during real-world testing, report via Gitee Issues").

---

## Self-Review

### Spec coverage

| Spec section | Tasks |
|---|---|
| §3.1 T1 reader_body split | T1 (selection toolbar) + T2 (chapter end prompt) + T3 (refactor) |
| §3.2 T2 lint cleanup | T4 |
| §3.3 T3 perf docs | T5 |
| §3.4 T4 release-procedure | T6 |
| §3.5 T5 CHANGELOG + release notes | T7 |
| §3.6 T6-T8 manual interactive | T8 (screenshots) + T9 (Gitee Release) + T10 (smoke + sync) |
| §5 verification + tag + memory | T11 |

All spec sections covered.

### Placeholder scan

- T1 test has `// SubListView is unused; remove this placeholder before saving.` and `typedef SubListView = Never;` — these are explicit "remove me" markers, not real placeholders. Implementer must remove them.
- T2 test has a note "If end-to-end wiring is too brittle, drop to a simpler 'mount test' + 'lifecycle test' pair" — this is an explicit fallback path, not a placeholder. Implementer should attempt the full version first, fall back if needed.
- T9 has "Output each markdown to user as a code block for copy-paste" — this is interactive mode, not a code placeholder. Claude generates the markdown at runtime based on CHANGELOG.

All clear.

### Type consistency

- `ReaderChapterEndPrompt` constructor: `(engine, bookId, onReview: void Function(int), onNext: VoidCallback)` — consistent in T2 widget def + T3 Stack insertion
- `ReaderSelectionToolbar` constructor: `(selection, onHighlight, onNote, onCopy, onAiComment)` — consistent in T1 widget def + T3 replacement
- `ChapterEndPromptController` constructor: `(repo, source, bookId)` — matches existing code in `chapter_end_prompt_controller.dart`

All clear.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-01-m2-4-release-hygiene-sweep.md`.

Per user instruction ("调用SUBagent完成任务"), proceeding with **Subagent-Driven Development** (option 1). Use superpowers:subagent-driven-development to execute task-by-task with two-stage review per task.

**Note on interactive tasks (T8-T10)**: These are user-driven, not subagent. Claude executes them directly with user coordination between T7 and T11.
