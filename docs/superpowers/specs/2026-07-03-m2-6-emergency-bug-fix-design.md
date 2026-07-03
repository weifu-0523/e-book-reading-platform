# M2.6 Emergency Bug Fix Design

> **Status**: Approved (3 design decisions confirmed via AskUserQuestion on 2026-07-03)
> **Predecessor**: M2.5 (v1.5.0-alpha, shipped 2026-07-03 09:00)
> **Successor**: M2.7 (TBD; likely v1.6 GA prep)
> **Target tag**: `m2.6-complete` + `v1.5.1-alpha`
> **Estimated scope**: 14 tasks (was 13; Bug #9 added 2026-07-03), ~6-10 hours

## Context

M2.5 shipped 2026-07-03 with 15 tasks (sidebar drawer, fullscreen, dual-page, bookmarks, multi-input paging, typography tweaks). User rebuilt the Windows Debug exe (`flutter build windows --debug`, 09:16) and ran hands-on UX testing on 2026-07-03 morning. Reported 9 bugs (was 8; Bug #9 ESC fullscreen added later same day), several of which block core reading flow.

Four parallel opus-review subagents investigated the original 8; main thread verified key file:line claims. Bug #9 root cause analyzed by main thread post-hoc. Root-cause confidence is HIGH for 5 bugs, MEDIUM for 3, LOW for 1 (needs runtime stack trace).

This is a regression/quality milestone, not a feature milestone. Goal: restore v1.4-level reading usability on top of the M2.5 architecture, then ship v1.5.1-alpha patch.

## Goals

1. **All 9 user-reported bugs closed** with at least one regression test each (Bug #1 ships defensive only)
2. **No new features** — pure fix sweep
3. **Version bumped** to v1.5.1-alpha, dual-tagged and pushed
4. **Memory + runbook** updated with M2.6 entry

## Non-Goals (deferred)

- EPUB dual-page rendering (still v1.6, only API surface in M2.5/T14)
- AI guide improvements
- Sync pipeline enhancements
- Performance baseline re-measurement (still deferred to v1.6 GA prep per `maintainers-runbook §9.4.2`)
- 4 missing/outdated screenshots (user-facing manual op; pause until M2.6 ships so screenshots reflect the fixed state)

## Bug Catalog (Root Causes Verified)

### P0 — Blocks core reading

#### Bug #6: Keyboard/mouse paging broken (HIGH confidence)

**User report**: "键盘左右键，不能翻页，鼠标单击翻页延迟非常高，而且翻页逻辑有问题，感觉在乱翻"

**Root cause** (`app/lib/features/reader/widgets/reader_scaffold.dart:253-302`):
```dart
if (widget.paginationMode != PaginationMode.paged) {
  return KeyEventResult.ignored;
}
```
Keyboard handlers (line 253), pointer-signal / wheel handler (line 292), and horizontal drag handler (line 302) all gate on `paginationMode == paged`. PDF engine returns `PaginationMode.scroll`, so all three input paths are silently dropped. Only tap-zone paging bypasses the gate (line 314-334), but inherits inconsistent stepping from the `dualPageMode` state machine (1 vs 2 pages).

**Why tests missed it**: `reader_paging_test.dart` passes `PaginationMode.paged` explicitly to the test harness, never exercising the actual `PdfReaderEngine.paginationMode` getter.

**Fix**: Lift the paginationMode gate from keyboard/wheel/drag handlers. Each engine's `nextSpine/previousSpine` already knows how to step (1 page in scroll, 1-2 in paged dual). The gate was overzealous — paged-specific semantics (e.g., snap-to-page) belong inside the engine, not the input handler.

**Tap-zone model update (per A2 below)**: Mouse-click paging is restricted to left/right margin rectangles (Bug #5a fix). Center-area clicks do NOT page — they reach SelectableRegion for text selection. This eliminates the "乱翻" symptom (inconsistent 1 vs 2 page stepping on accidental center clicks) by design.

#### Bug #4: PDF dual-page not engaging (HIGH confidence, related to #6)

**User report**: "浏览书籍还是一个页面，全屏下没有分为左右两页"

**Root cause** (`reader_engine_pdf_view/lib/pdf_reader_engine.dart:132` + `pdf_renderer.dart`):
- `PdfReaderEngine.paginationMode` hardcoded to `PaginationMode.scroll`
- LayoutBuilder in reader_body.dart:281 sets `renderer.dualPageMode = true` at ≥1200px, but
- The dual-page widget tree (`_buildDualPage` at pdf_renderer.dart:293) renders correctly ONLY when `paginationMode` lets it; in scroll mode the renderer falls back to single-page vertical scroll

**User decision**: Keep PDF `paginationMode = scroll` by default. Add an **independent dual-page toggle** (decoupled from paginationMode) so users can opt into dual-page rendering without losing continuous scroll.

**Fix**:
- T2.1: Add `dualPageMode` field + setter on `PdfReaderEngine` (mirror of `PdfRenderer.dualPageMode`)
- T2.2: When `dualPageMode == true`, PdfRenderer renders two pages side-by-side in a horizontal PageView embedded inside the existing scroll view (or as an overlay), preserving scroll semantics
- T2.3: Add a toggle button in the reader AppBar / settings (visible only for PDF books)
- T2.4: Persist toggle state per-book in SharedPreferences (`pdf_dual_page_<bookId>`)

**Implementation note**: This is more work than the "just go paged" alternative the user rejected. Trade-off: respects user's choice of scroll-mode semantics while still enabling dual-page viewing.

#### Bug #3: Typography page controls unresponsive (HIGH confidence)

**User report**: "排版页面，目前不能修改任何选项，点击不了没有反应"

**Root cause** (`reader_engine_epub_view/lib/concrete_reader_engine.dart:81`):
```dart
@override
TypographySettings get typography => TypographySettings.defaults();
// 注：typography 实际由 _renderer 持有；为简洁此处返回默认。
// M3 重构为 _renderer.typography。
```

`TypographyPanel` reads `engine.typography` for current values; getting a const default means every `onChanged` writes to a discarded object. The renderer's `_typography` field (in `epubx_renderer.dart`) is never reached.

**Why tests missed it**: Existing typography tests verify (a) serialization round-trip, (b) widget rendering with explicit settings. None verifies the live data flow from panel → engine → renderer.

**Fix**: One-line change: `TypographySettings get typography => _renderer.typography;`. The author's own TODO admitted this.

#### Bug #5b: Highlights don't render after marking (MEDIUM confidence)

**User report**: "标记颜色后，书籍内文字依旧没有变化"

**Root cause** (multi-layer):
1. `epubx_renderer.dart:488` — `injectHighlights()` is `async Future<void>` that only mutates `_allHighlights` field
2. `reader_body.dart:221-240` — `ref.listen<NotesState>` calls `await engine.injectHighlights(ranges)` but does not trigger a widget rebuild afterward
3. `epubx_renderer.dart` build() reads `_allHighlights` — but only rebuilds when the engine emits a new state via `_stateController`
4. setTypography at line 472-475 has comment "build() 直接读 _typography → TextStyle，无需手动重建 widget tree" — but typography changes propagate via the `setTypography` Future completing and Riverpod rebuilding the consumer. Highlights have no equivalent path.

**Fix**:
- After `injectHighlights` updates `_allHighlights`, emit a state notification (e.g., `_stateController.add(ReaderEngineReady())` or a new `ReaderEngineHighlightsUpdated` state)
- Wrap the consumer in a `ref.listen` that calls `setState` on state changes
- Add a `HtmlHighlightInjector` test that verifies offsets are non-null for sample HTML; log + skip when null

**Risk**: A rebuild loop if `injectHighlights` is called inside a build phase. Verify the call originates from a listener, not a builder.

### P1 — Feature broken but workaround exists

#### Bug #2: Note tap exits book entirely (HIGH confidence)

**User report**: "左侧导航笔记栏中，点击笔记直接退出书籍"

**Root cause** (`app/lib/features/reader/pages/reader_body.dart:506`):
```dart
await Navigator.of(context).maybePop(); // 关闭 endDrawer
```
Stale comment. M2.5/T7 changed the drawer from `endDrawer` to `Scaffold.drawer`. On narrow screens `maybePop()` now pops the reader route. On wide screens the drawer is a persistent sidebar so `maybePop()` is also a no-op or worse.

**Fix**: Replace line 506 with the same pattern already used at line 809 (`_onBookmarkJump`):
```dart
if (!_isWideScreen(context)) {
  unawaited(Navigator.of(context).maybePop());
}
```

**Why tests missed it**: `notes_drawer_test.dart` only checks widget structure, not navigation behavior. Need a widget test that wraps the reader in a mock navigator and asserts the route remains after note tap.

#### Bug #7: TOC tap doesn't navigate to chapter page (MEDIUM confidence)

**User report**: "左侧点击目录不能调整到目录所在页面"

**Root cause** (`reader_engine_epub_view/lib/epubx_renderer.dart:452-468`):
```dart
if (locator is EpubRangeLocator) {
  // ...
  if (locator.chapterIndex != _currentChapterIndex) {
    _currentChapterIndex = locator.chapterIndex;
    _chapterEndFiredForCurrentChapter = false;
    _cachedBreaks = null;
    _beginChapterSwitch();
  }
  return;  // ← no positioning, no state notification
}
```
The EpubRangeLocator branch updates chapter index but doesn't trigger a state notification. Compare to EpubCfiLocator branch (line 419-451) which calls `addPostFrameCallback` to scroll. The bug-6 fix comment claims "paged-mode page positioning is caller's responsibility via ScrollToOffsetService", but TOC entries don't go through ScrollToOffsetService.

**Fix**:
- After `_beginChapterSwitch()` in the EpubRangeLocator branch, emit a state notification (similar to EpubCfiLocator's pattern but without scroll jump)
- OR: have `reader_drawer_builders.dart:58-63` TOC `onSelect` callback also call ScrollToOffsetService for EpubRangeLocator entries

**Decision**: emit state in renderer (`epubx_renderer.dart` EpubRangeLocator branch). Rationale: benefits all callers (TOC, notes, bookmarks) without each one wiring ScrollToOffsetService. The state notification triggers consumer rebuild; precise scroll positioning is a follow-up if user reports residual "chapter changed but not positioned" symptom.

#### Bug #9: ESC doesn't exit fullscreen (HIGH confidence, focus dynamics)

**User report (2026-07-03, added post-M2.6 kickoff)**: "全屏后 esc 不能退出全屏状态"

**Root cause** (`app/lib/features/reader/widgets/reader_scaffold.dart:114-116 + 245-251`):

The ESC handler IS wired:
```dart
// reader_scaffold.dart:114
return Focus(
  autofocus: true,
  onKeyEvent: (node, event) => _handleKeyEvent(event),
  ...
);

// reader_scaffold.dart:245-251 (inside _handleKeyEvent)
if (key == LogicalKeyboardKey.escape) {
  final ui = ref.read(readerUiControllerProvider);
  if (ui.isFullscreen) {
    ref.read(readerUiControllerProvider.notifier).toggleFullscreen();
    return KeyEventResult.handled;
  }
}
```

So the code path exists. The bug is **focus dynamics**:
1. User clicks the fullscreen button in AppBar → `IconButton`'s `Focus` node receives focus
2. After click, the Focus node remains on the button (or its parent)
3. Reader_scaffold's outer `Focus(autofocus: true)` only requests focus on initial mount; it does NOT reclaim focus when the AppBar button releases it
4. ESC key events are dispatched to the currently-focused widget's `onKeyEvent`
5. The button doesn't have an ESC handler → ESC is silently dropped

**Why tests missed it**: The widget test for fullscreen ESC (M2.5/T9) likely `pumpWidget`s ReaderScaffold directly and sends a keyEvent via `tester.sendKeyEvent`, which dispatches to whatever has focus at the top of the tree — which IS ReaderScaffold in the test harness. Real app has a deeper widget tree with AppBar buttons competing for focus.

**Fix options**:
- **Option A (recommended)**: Use a `FocusScope` with `onKeyEvent` at a higher level than ReaderScaffold (e.g., wrap the entire `MaterialApp` or the reader `Scaffold`). Higher-level scopes receive events that bubble up.
- **Option B**: After `toggleFullscreen()` is called from the button, programmatically re-request focus on the ReaderScaffold Focus node (`_focusNode.requestFocus()`).
- **Option C**: Use `HardwareKeyboard` global listener (added in Flutter 3.x) — doesn't depend on focus at all.
- **Option D**: Add `Shortcut` + `Action` for ESC with high priority.

Lean toward Option B (minimal change, well-targeted). In `IconButton.onPressed` for the fullscreen button at `reader_scaffold.dart:188-194`:
```dart
onPressed: () {
  ref.read(readerUiControllerProvider.notifier).toggleFullscreen();
  // Reclaim focus so ESC handler receives future key events
  _focusNode.requestFocus();
},
```

This requires hoisting the Focus node to a field (`_focusNode`) instead of using `autofocus: true` on an anonymous Focus widget.

**Risk**: Other AppBar buttons (TOC, bookmark) may also need to relinquish focus after click. Generalize the pattern: every IconButton in `_buildChrome` calls `_focusNode.requestFocus()` after its onPressed side-effect.

**Confidence**: HIGH — focus dynamics explanation is consistent with Flutter's event dispatch model. Verification: user re-test post-fix.

#### Bug #1: Bookmark click → red error screen (LOW confidence — needs stack trace)

**User report**: "左侧书签点击出现错误，红色背景，黄色一大串英文报错"

**Root cause hypothesis** (`app/lib/features/reader/pages/reader_body.dart:787-809`):
- jsonDecode is wrapped in try-catch (line 794) ✓
- locator null check + SnackBar (line 797) ✓
- `engine.gotoLocator(locator)` (line 804) is **NOT** wrapped in try-catch

Most likely crash paths:
1. Locator type mismatch: bookmark saved as EpubRangeLocator, engine state has stale flatChapters index → `decoded.chapterIndex` out of bounds → uncaught RangeError bubbles to widget tree → red screen
2. Engine not yet ready when bookmark tapped → gotoLocator hits an internal assert
3. PDF bookmark locator (PdfPageLocator) routed to wrong engine branch

**Action**: T9 will add try-catch around gotoLocator + log stack trace. User will reproduce and report the actual stack trace from the yellow text; we'll patch the specific cause in a follow-up if the generic try-catch doesn't fully resolve.

### P2 — Polish

#### Bug #5a: Selection flaky + tap-zone overlap with text (MEDIUM confidence)

**User report**: "不能自由的选择书籍内容进行摘要，偶尔选择到文字摘要"

**Refined requirement (per user 2026-07-03)**: 仿真书模型——
- **左右空白边**（text 与屏幕边缘之间的 margin 区域）：点击 = 翻页（左 = 上一页，右 = 下一页）
- **文字内容区**（text 本身）：纯选择，不翻页；SelectableRegion 独享手势
- **上下空白**：上下也必须留白（与左右一致），文字不贴边——和真实书籍排版一致

**Root cause** (`app/lib/features/reader/widgets/reader_scaffold.dart:119-123`):
```dart
child: GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTapUp: (details) => _handleTap(...),
  onHorizontalDragEnd: _handleDragEnd,
  child: Stack(children: [widget.content, ...]),
)
```
The GestureDetector with `HitTestBehavior.opaque` sits ABOVE the content (which contains SelectableRegion). The opaque behavior + nested `Listener` for pointer signals can win the gesture arena in edge cases, blocking SelectableRegion's long-press. Tap zones are also computed by `localPosition.dx / size.width` (left 1/3, right 1/3, center 1/3) which spans the entire surface — meaning any tap-up gesture, including one ending on text, can trigger paging.

**User decision**: Book-like model — tap zones restricted to **left/right margin rectangles only**. Center content area is pure selection territory.

**Fix**:
- Restructure `reader_scaffold.dart` build() to use a `Stack` with explicit layers:
  - **Bottom layer**: `widget.content` (SelectableRegion gets first-class gesture scope across the entire content area)
  - **Top layer 1 (left margin)**: `Positioned(left: 0, width: marginPx, top: 0, bottom: 0)` containing a transparent `GestureDetector(onTapUp: prev)`, `onHorizontalDragEnd: dragHandler`
  - **Top layer 2 (right margin)**: same as above with `right: 0`, calls `next`
  - **Top layer 3 (center double-tap zone)**: optional, `Positioned(left: marginPx, right: marginPx, top: 0, bottom: 0)` for double-tap-to-toggle-chrome — does NOT consume single taps
- `marginPx` is read from current `TypographySettings.margin` pixel value (Compact 8 / Normal 32 / Wide 48 / ExtraWide 64) — see Bug #8 fix. With Normal=32, each tap zone is 32px wide which is the WCAG minimum tap target.
- The opaque GestureDetector (line 119) is **removed entirely**; replaced by the three Positioned layers above
- `_handleTap(details.localPosition.dx, size.width)` is replaced by per-zone handlers — no zone arithmetic needed

**Side benefit**: Bug #6's mouse-click "乱翻" symptom (inconsistent 1 vs 2 page stepping) becomes a non-issue in the text area because clicks there no longer page.

**Risk**: 
- Widget test gesture arena is unreliable — manual smoke required
- Margin <32px (Compact=8) means tap zone is too narrow; document that Compact is "viewing-only, no comfortable tap-to-page"
- Need to verify top/bottom padding is actually applied to content (see Bug #8 side note)

#### Bug #8: Margins still too tight (HIGH confidence, tuning)

**User report**: "浏览书籍时文字距离边界还是太近了，还需要进行调整" + "每一页文字出来左右要留空白外，上下也必须留空，就和一本真实的书籍一样"

**Current values** (`reader_engine/lib/core/typography_settings.dart:25-32`):
- compact: 8
- normal: 24 (was 16 pre-M2.5)
- wide: 32 (was 24 pre-M2.5)
- extraWide: 40 (new in M2.5)

**User decision**: Bump to normal=32, wide=48, extraWide=64. Compact stays 8. **Plus**: verify top/bottom padding matches left/right (book-like 4-sided whitespace).

**Fix**:
1. Update enum pixel values: normal 24→32, wide 32→48, extraWide 40→64
2. Audit `epubx_renderer.dart` padding application (line ~538 / 556 / 598): confirm `EdgeInsets.all(marginPx)` or symmetric — NOT just horizontal
3. If only horizontal padding today, add top/bottom (recommend 0.5× horizontal for visual balance, e.g., Normal horizontal=32 / vertical=16) — exact ratio to be confirmed during impl
4. Margin pixel value is reused as tap-zone width in Bug #5a fix → Normal=32 satisfies WCAG tap target

**Migration note**: This is another behavior change for existing users (margin grows again). CHANGELOG entry must call out: "v1.5.1-alpha 再次调整边距：Normal 24→32 (推荐), Wide 32→48, ExtraWide 40→64，并补足上下留白。如偏好窄边距请 Settings → Typography → Margin 切到 Compact。"

## Architecture Decisions

### A1: PDF keeps scroll mode, dual-page is independent toggle

**Decision**: PDF `paginationMode` stays `scroll`. Dual-page is a separate boolean state, per-book, persisted in SharedPreferences.

**Rationale (per user)**: PDFs are page-based but users want continuous scroll for navigation; dual-page is a viewing preference, not a mode change. Decoupling avoids forcing users into paged mode to get dual-page.

**Trade-off**: Implementation is more complex than "just switch to paged" — the dual-page widget must coexist with scroll semantics. Estimated +1 task of work.

### A2: Book-like reading model (margin-only tap zones + 4-sided whitespace)

**Decision**: Reader tap zones exist ONLY in left/right margin rectangles. Center content area is pure selection territory. Pages also have top/bottom whitespace matching left/right (book-like 4-sided).

**Rationale (per user 2026-07-03)**: "戍边在左右空白区域点击翻页，在书籍内部鼠标主要还是选择文字，每一页文字出来左右要留空白外，上下也必须留空，就和一本真实的书籍一样". Mirrors real-book interaction model where you tap edge to turn page and the text body is selection territory.

**Trade-off**: 
- Reader_scaffold.dart gets a substantial rewrite (remove opaque GestureDetector, add 3 Positioned layers)
- Compact margin (8px) makes tap zones too narrow — document as "viewing-only"
- Margins must be sized to double as comfortable tap targets (≥32px = WCAG minimum)

**Coupling with Bug #8**: margin pixel value now serves two purposes (visual whitespace + tap target size). Must coordinate T4 (margin bump) with T9 (sibling-layer refactor).

### A3: Bug #1 ships with defensive try-catch, awaits user stack trace

**Decision**: T8 wraps `engine.gotoLocator(locator)` in try-catch with debugPrint. If user reproduces and provides the yellow-text stack trace, we ship a targeted fix in M2.7 or a v1.5.2-alpha hotfix.

**Rationale**: Can't reliably reproduce without the actual error. Defensive catch prevents the red screen; root-cause fix needs data.

## Test Strategy

Each bug gets at least one regression test:

| Bug | Test type | Test file |
|---|---|---|
| #1 | widget test (mock gotoLocator throwing) | `reader_bookmark_jump_test.dart` (new) |
| #2 | widget test with mock navigator | `notes_drawer_navigation_test.dart` (new) |
| #3 | unit test of `engine.typography` after `setTypography` | `concrete_reader_engine_typography_test.dart` (new) |
| #4 | widget test: PdfReaderEngine dualPageMode toggle | `pdf_dual_page_test.dart` (new) |
| #5a | manual smoke (gesture arena unreliable in widget tests) | documented in runbook §7.7 |
| #5b | widget test: injectHighlights triggers listener notification | `highlight_render_test.dart` (new) |
| #6 | widget test: keyboard input on PdfReaderEngine (scroll mode) | `reader_paging_pdf_test.dart` (new) |
| #7 | widget test: TOC tap triggers chapter switch | `toc_navigation_test.dart` (new) |
| #8 | unit test of margin enum values | `typography_settings_test.dart` (extend) |

Target test count: ~1085+ (1066 baseline + ~20 new regression tests).

## Task Breakdown (Plan Skeleton)

13 tasks total. Each task: TDD (write failing test → implement → green → commit). Subagent-driven development with two-stage review (spec then quality).

**P0 fixes (T1-T5):**
- T1: Lift paginationMode gate from reader_scaffold input handlers (Bug #6)
- T2: PdfReaderEngine dualPageMode as independent toggle (Bug #4)
- T3: Fix typography getter (Bug #3)
- T4: Bump margin values (Bug #8) [also P2]
- T5: Fix injectHighlights state notification (Bug #5b)

**P1 fixes (T6-T9):**
- T6: Fix note tap drawer close (Bug #2)
- T7: Fix TOC gotoLocator state notification (Bug #7)
- T8: Wrap bookmark jump gotoLocator in try-catch (Bug #1)
- T9: Refactor reader_scaffold GestureDetector to sibling layer (Bug #5a)

**Polish (T10-T13):**
- T10: Regression test sweep — verify all 9 tests above
- T11: Full analyze + test, single commit
- T12: CHANGELOG + version bump v1.5.1-alpha + dual tag
- T13: Rebuild Debug exe, update memory + runbook

## Risks

1. **Bug #1 may not be fully fixed** without the actual stack trace. Mitigation: defensive catch + user reproduces.
2. **T9 sibling-layer refactor** could introduce new gesture bugs. Mitigation: extensive manual smoke + keep old code path on a feature flag for one milestone (defer).
3. **T2 PDF dual-page in scroll mode** is novel; no existing pattern. Mitigation: spike first, fall back to "paged mode + toggle" if scroll+dual proves too complex.
4. **User-facing CHANGELOG caveat** about margin change (24→32). Mitigation: clear notes pointing to Compact option.

## Success Criteria

- [ ] All 8 user-reported bugs addressed (1 with defensive-only fix)
- [ ] 4 packages `dart analyze` clean
- [ ] All existing tests pass + ~20 new regression tests pass
- [ ] Dual tag `m2.6-complete` + `v1.5.1-alpha` pushed to Gitee
- [ ] Fresh Windows Debug exe built and shipped to user for re-test
- [ ] Memory file `project_zhiyue_m2_6_complete.md` saved
- [ ] User confirms 7/8 bugs resolved in next testing round (Bug #1 may need second pass with stack trace)

## Out-of-Scope (Explicit)

- New features of any kind
- Refactoring beyond what each bug requires
- Performance optimization
- Documentation overhaul (only CHANGELOG + runbook milestone entry)
- Release build / Gitee Release page creation (still pending from v1.5.0-alpha)
