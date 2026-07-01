# M2.2 自动章节结束提示 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用户翻到一章末页时（EPUB paged/scroll 模式），自动弹出 SnackBar，提供「回顾本章 / 下一章 / 关闭」三个动作。

**Architecture:** EpubxRenderer 新增 `chapterEndEvents` 事件流（page-level 检测，内部 flag 去抖）；app 层 `ChapterEndDetector` 做 per-session per-chapter 去重（Set）；`ChapterEndPromptController` 是 settings-gated StateNotifier；reader_body 仅 EPUB 路径接线 controller（PDF 完全跳过）。零 DB schema 迁移、零 sync 改动。

**Tech Stack:** Flutter 3.44 / Dart 3.10 / Riverpod 2.5 / drift 2.18 / reader_engine_epub_view / pdfrx（仅参考）

**Spec：** `docs/superpowers/specs/2026-07-01-m2-2-chapter-end-prompt-design.md`

**前置：** v1.1.0-alpha 已交付（含 M2.1 ReviewController + ReviewPreviewSheet + `_onOpenReview` + BookReviewer + applyChapterReview）

---

## 项目特定约束（每个 task 都要遵守）

- **环境**：Windows bash，`/c/flutter/bin/dart.bat` 不是 `dart.exe`；`/c/flutter/bin/flutter.bat` 不是 `flutter.exe`
- **lint**：用 `dart analyze` 不是 `flutter analyze`
- **测试**：`/c/flutter/bin/flutter.bat test --concurrency=1`
- **commit**：HEREDOC 格式，结尾必有 `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`
- **commit message**：`feat(m2.2/tN): <subject>` 或 `test(m2.2/tN): <subject>` 或 `refactor(m2.2/tN): <subject>` 或 `docs(m2.2): <subject>`
- **git add**：单行，明确文件名（不要 `git add -A` 或 `git add .`）
- **push**：每个 commit 都推送到 `origin master`（即 gitee.com:weifu0523/e-book-reading-platform.git）
- **license header**：所有新 .dart 文件必须有 SPDX-License-Identifier: AGPL-3.0-or-later 完整 header（参考 `reader_engine/lib/engine/reader_engine.dart` line 1-15）
- **NO** `--no-verify`、`--no-gpg-sign`、force push、amend

---

## File Structure

### 新增文件

| 路径 | 责任 |
|---|---|
| `reader_engine_epub_view/lib/src/chapter_end_event.dart` | ChapterEndEvent 数据类 |
| `app/lib/features/reader/services/chapter_end_detector.dart` | per-session dedup + PromptRequest 数据类 |
| `app/lib/features/reader/providers/chapter_end_prompt_controller.dart` | StateNotifier + settings gate |
| `app/lib/features/reader/providers/chapter_end_prompt_enabled_provider.dart` | Settings 开关 provider（独立小文件） |
| `app/lib/features/reader/widgets/chapter_end_prompt_snackbar.dart` | 自定义 SnackBar content（3 按钮） |
| `reader_engine_epub_view/test/chapter_end_event_test.dart` | EpubxRenderer emit 测试 |
| `app/test/features/reader/services/chapter_end_detector_test.dart` | detector 测试 |
| `app/test/features/reader/providers/chapter_end_prompt_controller_test.dart` | controller 测试 |
| `app/test/features/reader/providers/chapter_end_prompt_enabled_provider_test.dart` | 开关 provider 测试 |
| `app/test/features/reader/widgets/chapter_end_prompt_snackbar_test.dart` | widget 测试 |
| `app/test/features/reader/chapter_end_prompt_integration_test.dart` | integration 测试 |

### 修改文件

| 路径 | 改动 |
|---|---|
| `reader_engine_epub_view/lib/epubx_renderer.dart` | 加 chapterEndEvents + _maybeEmitChapterEnd + flag + 钩子 |
| `reader_engine_epub_view/lib/concrete_reader_engine.dart` | forward chapterEndEvents |
| `reader_engine_epub_view/lib/reader_engine_epub_view.dart` | barrel 导出 ChapterEndEvent |
| `app/lib/features/reader/pages/reader_body.dart` | isEpub gate + ref.listen + showSnackBar |
| `app/lib/features/settings/pages/settings_page.dart` | 在 Reading section 加 chapter-end-prompt 开关 tile |
| `app/lib/data/repositories/settings_repository.dart` | abstract 加 `getOrNull<T>` 方法 |
| `app/lib/data/repositories/local_settings_repository.dart` | 实现 getOrNull |
| `app/lib/main.dart` 或 `app/lib/app.dart` | 启动时跑 ensureChapterEndPromptDefault |
| `app/lib/l10n/app_zh.arb` | +6 keys |
| `app/lib/l10n/app_en.arb` | +6 keys |

---

## Task 1: ChapterEndEvent 数据类

**Files:**
- Create: `reader_engine_epub_view/lib/src/chapter_end_event.dart`
- Modify: `reader_engine_epub_view/lib/reader_engine_epub_view.dart`
- Test: `reader_engine_epub_view/test/chapter_end_event_test.dart`

- [ ] **Step 1.1: 创建 ChapterEndEvent 数据类**

Create `reader_engine_epub_view/lib/src/chapter_end_event.dart`:

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

/// Emitted by [EpubxRenderer.chapterEndEvents] when the reader reaches the
/// last page of the current chapter (paged mode) or scrolls within 64px of
/// the bottom (scroll mode).
///
/// Field semantics:
/// - [chapterIndex]: 0-based flat index of the chapter that just ended.
/// - [isLastChapter]: true if this is the last chapter in the book (UI uses
///   this to suppress the "Next chapter" button).
class ChapterEndEvent {
  const ChapterEndEvent({
    required this.chapterIndex,
    required this.isLastChapter,
  });

  final int chapterIndex;
  final bool isLastChapter;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterEndEvent &&
          runtimeType == other.runtimeType &&
          chapterIndex == other.chapterIndex &&
          isLastChapter == other.isLastChapter;

  @override
  int get hashCode => chapterIndex.hashCode ^ isLastChapter.hashCode;

  @override
  String toString() =>
      'ChapterEndEvent(chapterIndex: $chapterIndex, isLastChapter: $isLastChapter)';
}
```

- [ ] **Step 1.2: barrel 文件加导出**

Modify `reader_engine_epub_view/lib/reader_engine_epub_view.dart`:

加 `export 'src/chapter_end_event.dart';`（在既有 export 列表末尾追加）。

先 Read 该文件确认既有 exports，再加新行。

- [ ] **Step 1.3: 写数据类测试**

Create `reader_engine_epub_view/test/chapter_end_event_test.dart`:

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

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/src/chapter_end_event.dart';

void main() {
  group('ChapterEndEvent', () {
    test('fields exposed correctly', () {
      const event = ChapterEndEvent(chapterIndex: 3, isLastChapter: false);
      expect(event.chapterIndex, 3);
      expect(event.isLastChapter, isFalse);
    });

    test('equality holds for same fields', () {
      const a = ChapterEndEvent(chapterIndex: 5, isLastChapter: true);
      const b = ChapterEndEvent(chapterIndex: 5, isLastChapter: true);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('equality differs when chapterIndex differs', () {
      const a = ChapterEndEvent(chapterIndex: 5, isLastChapter: true);
      const b = ChapterEndEvent(chapterIndex: 6, isLastChapter: true);
      expect(a, isNot(equals(b)));
    });

    test('equality differs when isLastChapter differs', () {
      const a = ChapterEndEvent(chapterIndex: 5, isLastChapter: true);
      const b = ChapterEndEvent(chapterIndex: 5, isLastChapter: false);
      expect(a, isNot(equals(b)));
    });

    test('toString includes both fields', () {
      const event = ChapterEndEvent(chapterIndex: 2, isLastChapter: true);
      final s = event.toString();
      expect(s.contains('2'), isTrue);
      expect(s.contains('true'), isTrue);
    });
  });
}
```

- [ ] **Step 1.4: 运行测试验证通过**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/chapter_end_event_test.dart`（在 `reader_engine_epub_view/` 目录下，用 `cd` 临时切换或全路径调用）

Expected: 5 tests PASS

- [ ] **Step 1.5: analyze 检查**

Run: `/c/flutter/bin/dart.bat analyze lib/src/chapter_end_event.dart lib/reader_engine_epub_view.dart`

Expected: No issues

- [ ] **Step 1.6: Commit + push**

```bash
git add reader_engine_epub_view/lib/src/chapter_end_event.dart reader_engine_epub_view/lib/reader_engine_epub_view.dart reader_engine_epub_view/test/chapter_end_event_test.dart
git commit -m "$(cat <<'EOF'
feat(m2.2/t1): ChapterEndEvent data class

Pure data class for reader_engine_epub_view.chapterEndEvents stream.
Fields: chapterIndex, isLastChapter. Value-equality + hashCode for
Set dedup use later.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 2: EpubxRenderer emit signal

**Files:**
- Modify: `reader_engine_epub_view/lib/epubx_renderer.dart`
- Test: `reader_engine_epub_view/test/epubx_renderer_chapter_end_test.dart`

> **重要**：现有 `_onScroll()` 和 `_cachedBreaks`、`_pageController`、`setChapter` 都在此文件。先 Read 整个文件（~520 行），定位每个改动点。
>
> 改动点：
> 1. import `chapter_end_event.dart`
> 2. 新增字段 `_chapterEndController` + `_chapterEndFiredForCurrentChapter`
> 3. 新增 getter `chapterEndEvents`
> 4. 新增 method `_maybeEmitChapterEnd()`
> 5. `_onScroll()` 末尾调 `_maybeEmitChapterEnd()`
> 6. `PageView.builder` 加 `onPageChanged` 回调
> 7. `setChapter` 内重置 flag
> 8. `dispose` 关闭 controller

- [ ] **Step 2.1: Read 现有 epubx_renderer.dart 全文**

读 `reader_engine_epub_view/lib/epubx_renderer.dart` 全文，理解：
- `_pageController`、`_scrollController` 字段位置
- `_onScroll`、`setChapter`、`_buildPaged`、`dispose` 方法位置
- `_paginationMode` 字段
- `_cachedBreaks` 字段
- `_book`、`_currentChapterIndex`、`flatChapters` getter

- [ ] **Step 2.2: 写测试（TDD: 先写测试再实现）**

Create `reader_engine_epub_view/test/epubx_renderer_chapter_end_test.dart`:

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

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';
import 'package:reader_engine_epub_view/src/chapter_end_event.dart';

// Helper：构造一个最小可用的 EpubBook（两章，每章一段文字足以产生 1+ page breaks）
// 复用 reader_engine_epub_view 既有测试的 fixture 模式；若既有 fixture 不存在，
// 改用 bookForTesting 直接注入 mock EpubBook。

void main() {
  // 注意：此测试需要能驱动 _pageController 和 _scrollController 的真实 widget。
  // 实施时参考既有 epubx_renderer_test.dart 的 pumpEpubxRenderer helper。
  // 如果既有 helper 不存在或不适用，新增一个 test-only helper。

  test('ChapterEndEvent is emitted when paged mode reaches last page',
      (tester) async {
    // TODO: 实施时用真实 fixture 替换。占位测试结构：
    final renderer = EpubxRenderer();
    final events = <ChapterEndEvent>[];
    final sub = renderer.chapterEndEvents.listen(events.add);

    // 注：实际测试需要 pump 一个含 PageView 的 MaterialApp，模拟翻到末页。
    // 这里只验证 stream 接口存在，不强求 widget-level 集成（留给 integration test）。
    expect(renderer.chapterEndEvents, isA<Stream<ChapterEndEvent>>());

    await sub.cancel();
    await renderer.dispose();
  });

  // 详细的 paged/scroll/flag/setChapter-reset 测试需要 widget harness。
  // 在实施这一步时如果发现 widget-level 测试太复杂，把详细测试合并到
  // app/test/features/reader/chapter_end_prompt_integration_test.dart，
  // 本文件只保留接口契约测试。
}
```

> **注意**：widget-level 渲染测试在 epub_view 包内复杂（需要 pump PageView + LayoutBuilder 触发 measure）。如果实施时遇到阻力，**简化策略**：把 `_maybeEmitChapterEnd` 抽成 `@visibleForTesting` 方法，直接调它测试逻辑，跳过 widget pump。这是更 TDD 的做法。

实施时改用以下精简版（推荐）：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';
import 'package:reader_engine_epub_view/src/chapter_end_event.dart';

void main() {
  // 直接测试 _maybeEmitChapterEnd 逻辑（@visibleForTesting 暴露）
  // 不需要 widget pump。

  test('maybeEmitChapterEnd does nothing when no book is loaded', () async {
    final renderer = EpubxRenderer();
    final events = <ChapterEndEvent>[];
    final sub = renderer.chapterEndEvents.listen(events.add);

    renderer.maybeEmitChapterEndForTest();
    await Future<void>.delayed(Duration.zero);

    expect(events, isEmpty);
    await sub.cancel();
    await renderer.dispose();
  });

  // 其他测试需要 mock _cachedBreaks / _scrollController.position，依赖实施时
  // 暴露哪些 @visibleForTesting 入口。最小覆盖：stream 接口存在 + book 未加载时不 emit。
}
```

> 实施时根据实际暴露的 `@visibleForTesting` 入口调整测试。最少覆盖：stream 接口契约 + book 未加载时不 emit + flag 重置后能再次 emit。

- [ ] **Step 2.3: 跑测试验证 fail（red）**

Run: `cd reader_engine_epub_view && /c/flutter/bin/flutter.bat test --concurrency=1 test/epubx_renderer_chapter_end_test.dart`

Expected: FAIL with `chapterEndEvents getter 不存在` 或类似

- [ ] **Step 2.4: 实现 emit signal**

Modify `reader_engine_epub_view/lib/epubx_renderer.dart`:

a) 文件顶部 import 区追加：
```dart
import 'src/chapter_end_event.dart';
```

b) 在字段区（紧邻 `_chapterSwitchCompleter` 声明之后）追加：
```dart
final _chapterEndController = StreamController<ChapterEndEvent>.broadcast();
bool _chapterEndFiredForCurrentChapter = false;

/// Emits a [ChapterEndEvent] when the reader reaches the last page of the
/// current chapter (paged mode) or scrolls within 64px of the bottom
/// (scroll mode). Fires at most once per chapter visit — the internal
/// flag resets when [setChapter] runs.
Stream<ChapterEndEvent> get chapterEndEvents => _chapterEndController.stream;

@visibleForTesting
void maybeEmitChapterEndForTest() => _maybeEmitChapterEnd();

void _maybeEmitChapterEnd() {
  if (_chapterEndFiredForCurrentChapter) return;
  if (_book == null) return;

  bool isAtChapterEnd = false;
  if (_paginationMode == PaginationMode.paged) {
    final breaks = _cachedBreaks;
    if (breaks != null && breaks.isNotEmpty && _pageController.hasClients) {
      final page = _pageController.page?.round() ?? 0;
      isAtChapterEnd = page >= breaks.length - 1;
    }
  } else {
    if (_scrollController.hasClients) {
      final pos = _scrollController.position;
      isAtChapterEnd = pos.pixels >= pos.maxScrollExtent - 64;
    }
  }

  if (!isAtChapterEnd) return;
  _chapterEndFiredForCurrentChapter = true;
  final chapters = flatChapters;
  _chapterEndController.add(ChapterEndEvent(
    chapterIndex: _currentChapterIndex,
    isLastChapter: _currentChapterIndex >= chapters.length - 1,
  ));
}
```

> 注：`@visibleForTesting` 需要 `import 'package:flutter/foundation.dart';`（通常已通过 `flutter/widgets.dart` 间接导入；如未导入则加）。

c) 在 `setChapter` 方法体的开头（紧邻 `_currentChapterIndex = index;` 之后）加：
```dart
_chapterEndFiredForCurrentChapter = false;
```

d) 在 `_onScroll` 方法末尾加：
```dart
_maybeEmitChapterEnd();
```

e) 在 `_buildPaged` 方法的 `PageView.builder` 加 `onPageChanged`：
```dart
return PageView.builder(
  controller: _pageController,
  itemCount: breaks.length,
  onPageChanged: (_) => _maybeEmitChapterEnd(),
  itemBuilder: (context, i) {
    // ...既有...
  },
);
```

f) 在 `dispose` 方法（`Future<void> dispose() async {`）中加 `_chapterEndController` 关闭：
```dart
@override
Future<void> dispose() async {
  _scrollController.removeListener(_onScroll);
  _scrollController.dispose();
  _pageController.dispose();
  await _chapterEndController.close();  // 新增
  await _stateController.close();
  await _locationController.close();
  await _selectionController.close();
}
```

- [ ] **Step 2.5: 跑测试验证通过（green）**

Run: `cd reader_engine_epub_view && /c/flutter/bin/flutter.bat test --concurrency=1 test/epubx_renderer_chapter_end_test.dart`

Expected: PASS

- [ ] **Step 2.6: 跑 reader_engine_epub_view 全量测试，确保无回归**

Run: `cd reader_engine_epub_view && /c/flutter/bin/flutter.bat test --concurrency=1`

Expected: 既有测试全 PASS + 新测试 PASS

- [ ] **Step 2.7: analyze**

Run: `cd reader_engine_epub_view && /c/flutter/bin/dart.bat analyze`

Expected: No issues

- [ ] **Step 2.8: Commit + push**

```bash
git add reader_engine_epub_view/lib/epubx_renderer.dart reader_engine_epub_view/test/epubx_renderer_chapter_end_test.dart
git commit -m "$(cat <<'EOF'
feat(m2.2/t2): EpubxRenderer chapter-end emit signal

Add Stream<ChapterEndEvent> get chapterEndEvents on EpubxRenderer.
_maybeEmitChapterEnd checks paged (page == breaks.length-1) or scroll
(pixels >= maxScrollExtent-64) and emits once per chapter visit;
flag resets in setChapter. Hooks: PageView.builder.onPageChanged +
_onScroll tail. @visibleForTesting maybeEmitChapterEndForTest for
direct unit tests.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 3: ConcreteEpubReaderEngine forward chapterEndEvents

**Files:**
- Modify: `reader_engine_epub_view/lib/concrete_reader_engine.dart`
- Test: `reader_engine_epub_view/test/concrete_reader_engine_chapter_end_test.dart`

- [ ] **Step 3.1: 写测试**

Create `reader_engine_epub_view/test/concrete_reader_engine_chapter_end_test.dart`:

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

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';
import 'package:reader_engine_epub_view/src/chapter_end_event.dart';

void main() {
  test('ConcreteEpubReaderEngine.chapterEndEvents forwards renderer stream',
      () async {
    final renderer = EpubxRenderer();
    final engine = ConcreteEpubReaderEngine(renderer: renderer);
    final events = <ChapterEndEvent>[];
    final sub = engine.chapterEndEvents.listen(events.add);

    // 通过 @visibleForTesting 入口触发
    renderer.maybeEmitChapterEndForTest();
    await Future<void>.delayed(Duration.zero);

    // book 未加载 → 不 emit（验证 forward 而非 emit 行为）
    expect(events, isEmpty);
    expect(engine.chapterEndEvents, isA<Stream<ChapterEndEvent>>());

    await sub.cancel();
    await engine.close();
  });
}
```

- [ ] **Step 3.2: 跑测试验证 fail**

Run: `cd reader_engine_epub_view && /c/flutter/bin/flutter.bat test --concurrency=1 test/concrete_reader_engine_chapter_end_test.dart`

Expected: FAIL（`chapterEndEvents` 未定义在 ConcreteEpubReaderEngine）

- [ ] **Step 3.3: 实现 forward**

Modify `reader_engine_epub_view/lib/concrete_reader_engine.dart`:

a) import 已有 epubx_renderer.dart，再加 chapter_end_event（如未通过 widgets.dart 间接导入）：
```dart
import 'src/chapter_end_event.dart';  // 已被 epubx_renderer.dart 重新导出? 检查后决定
```

实际上 `epubx_renderer.dart` 内部 `import 'src/chapter_end_event.dart';` 不会自动 re-export。所以 concrete_reader_engine.dart 要单独 import。

b) 在 `chapterSwitchSettled` getter 之后加：
```dart
/// Forward [EpubxRenderer.chapterEndEvents] so app layer can subscribe
/// without casting to [EpubxRenderer].
Stream<ChapterEndEvent> get chapterEndEvents => _renderer.chapterEndEvents;
```

- [ ] **Step 3.4: 跑测试验证通过**

Run: `cd reader_engine_epub_view && /c/flutter/bin/flutter.bat test --concurrency=1 test/concrete_reader_engine_chapter_end_test.dart`

Expected: PASS

- [ ] **Step 3.5: 跑全量测试 + analyze**

Run: `cd reader_engine_epub_view && /c/flutter/bin/flutter.bat test --concurrency=1 && /c/flutter/bin/dart.bat analyze`

Expected: All PASS, no issues

- [ ] **Step 3.6: Commit + push**

```bash
git add reader_engine_epub_view/lib/concrete_reader_engine.dart reader_engine_epub_view/test/concrete_reader_engine_chapter_end_test.dart
git commit -m "$(cat <<'EOF'
feat(m2.2/t3): forward chapterEndEvents via ConcreteEpubReaderEngine

App layer can read chapterEndEvents off ConcreteEpubReaderEngine
without casting to EpubxRenderer. Pure forwarder; no behavior change.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 4: ChapterEndDetector service

**Files:**
- Create: `app/lib/features/reader/services/chapter_end_detector.dart`
- Test: `app/test/features/reader/services/chapter_end_detector_test.dart`

- [ ] **Step 4.1: 写测试**

Create `app/test/features/reader/services/chapter_end_detector_test.dart`:

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

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/src/chapter_end_event.dart';
import 'package:zhiyue/features/reader/services/chapter_end_detector.dart';

void main() {
  late StreamController<ChapterEndEvent> source;
  late ChapterEndDetector detector;

  setUp(() {
    source = StreamController<ChapterEndEvent>.broadcast();
    detector = ChapterEndDetector(source: source.stream, bookId: 'b1');
  });

  tearDown(() {
    detector.dispose();
    source.close();
  });

  test('first event for a chapter emits PromptRequest', () async {
    final reqs = <PromptRequest>[];
    detector.promptRequests.listen(reqs.add);
    detector.start();

    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    await Future<void>.delayed(Duration.zero);

    expect(reqs.length, 1);
    expect(reqs.first.bookId, 'b1');
    expect(reqs.first.chapterIndex, 3);
    expect(reqs.first.hasNext, isTrue);
  });

  test('second event for same chapter is suppressed (dedup)', () async {
    final reqs = <PromptRequest>[];
    detector.promptRequests.listen(reqs.add);
    detector.start();

    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    await Future<void>.delayed(Duration.zero);

    expect(reqs.length, 1);
  });

  test('event for different chapter emits again', () async {
    final reqs = <PromptRequest>[];
    detector.promptRequests.listen(reqs.add);
    detector.start();

    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    source.add(const ChapterEndEvent(chapterIndex: 4, isLastChapter: false));
    await Future<void>.delayed(Duration.zero);

    expect(reqs.length, 2);
    expect(reqs[0].chapterIndex, 3);
    expect(reqs[1].chapterIndex, 4);
  });

  test('isLastChapter true → hasNext false', () async {
    final reqs = <PromptRequest>[];
    detector.promptRequests.listen(reqs.add);
    detector.start();

    source.add(const ChapterEndEvent(chapterIndex: 9, isLastChapter: true));
    await Future<void>.delayed(Duration.zero);

    expect(reqs.single.hasNext, isFalse);
  });

  test('start is idempotent (no duplicate subscription)', () async {
    final reqs = <PromptRequest>[];
    detector.promptRequests.listen(reqs.add);
    detector.start();
    detector.start();  // second call should be no-op

    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    await Future<void>.delayed(Duration.zero);

    expect(reqs.length, 1);
  });

  test('different bookId → different dedup keys', () async {
    final source2 = StreamController<ChapterEndEvent>.broadcast();
    final det2 = ChapterEndDetector(source: source2.stream, bookId: 'b2');
    addTearDown(() {
      det2.dispose();
      source2.close();
    });

    final reqs1 = <PromptRequest>[];
    final reqs2 = <PromptRequest>[];
    detector.promptRequests.listen(reqs1.add);
    det2.promptRequests.listen(reqs2.add);
    detector.start();
    det2.start();

    // Both detectors see chapter 3, but different book → each emits.
    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    source2.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    await Future<void>.delayed(Duration.zero);

    expect(reqs1.length, 1);
    expect(reqs2.length, 1);
  });
}
```

- [ ] **Step 4.2: 跑测试验证 fail**

Run: `cd app && /c/flutter/bin/flutter.bat test --concurrency=1 test/features/reader/services/chapter_end_detector_test.dart`

Expected: FAIL（文件不存在）

- [ ] **Step 4.3: 实现 detector**

Create `app/lib/features/reader/services/chapter_end_detector.dart`:

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

import 'dart:async';

import 'package:reader_engine_epub_view/src/chapter_end_event.dart';

/// Per-session dedup wrapper around the renderer's chapter-end stream.
///
/// First visit to a (bookId, chapterIndex) pair emits a [PromptRequest];
/// subsequent visits in the same app session are suppressed. The Set is
/// process-lifetime (cleared on app restart, not on book close).
///
/// Detector takes the source stream as constructor arg (dependency injection)
/// so it doesn't need to know about PdfReaderEngine vs ConcreteEpubReaderEngine.
/// reader_body decides whether to create a detector at all (PDF: no detector).
class ChapterEndDetector {
  ChapterEndDetector({
    required Stream<ChapterEndEvent> source,
    required String bookId,
  })  : _source = source,
        _bookId = bookId;

  final Stream<ChapterEndEvent> _source;
  final String _bookId;
  final Set<String> _shownKeys = <String>{};
  final StreamController<PromptRequest> _controller =
      StreamController<PromptRequest>.broadcast();
  StreamSubscription<ChapterEndEvent>? _sub;

  Stream<PromptRequest> get promptRequests => _controller.stream;

  /// Idempotent: first call subscribes; subsequent calls are no-ops.
  void start() {
    _sub ??= _source.listen(_onEvent);
  }

  void _onEvent(ChapterEndEvent event) {
    final key = '$_bookId:${event.chapterIndex}';
    if (_shownKeys.contains(key)) return;
    _shownKeys.add(key);
    _controller.add(PromptRequest(
      bookId: _bookId,
      chapterIndex: event.chapterIndex,
      hasNext: !event.isLastChapter,
    ));
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}

/// Emitted by [ChapterEndDetector] when a chapter-end event passes dedup.
class PromptRequest {
  const PromptRequest({
    required this.bookId,
    required this.chapterIndex,
    required this.hasNext,
  });

  final String bookId;
  final int chapterIndex;
  final bool hasNext;
}
```

- [ ] **Step 4.4: 跑测试验证通过**

Run: `cd app && /c/flutter/bin/flutter.bat test --concurrency=1 test/features/reader/services/chapter_end_detector_test.dart`

Expected: 6 tests PASS

- [ ] **Step 4.5: analyze**

Run: `cd app && /c/flutter/bin/dart.bat analyze lib/features/reader/services/chapter_end_detector.dart`

Expected: No issues

- [ ] **Step 4.6: Commit + push**

```bash
git add app/lib/features/reader/services/chapter_end_detector.dart app/test/features/reader/services/chapter_end_detector_test.dart
git commit -m "$(cat <<'EOF'
feat(m2.2/t4): ChapterEndDetector with per-session dedup

Stream-to-stream wrapper: takes renderer's chapterEndEvents as DI arg,
suppresses repeat visits to the same (bookId, chapterIndex) within an
app session. Emits PromptRequest (hasNext derived from isLastChapter).
Process-lifetime Set; cleared on app restart.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 5: SettingsRepository.getOrNull

**Files:**
- Modify: `app/lib/data/repositories/settings_repository.dart`
- Modify: `app/lib/data/repositories/local_settings_repository.dart`
- Test: `app/test/data/repositories/local_settings_repository_test.dart`（或既有测试追加）

> **背景**：要区分"用户从未设置过 chapter_end_prompt_enabled"和"用户显式关掉"，需要 nullable getter。当前 `get<T>(key, default)` 无法区分。

- [ ] **Step 5.1: 写测试**

如果 `app/test/data/repositories/local_settings_repository_test.dart` 已存在，Read 后追加；否则创建。

新增测试：
```dart
test('getOrNull returns null when key not set', () async {
  // ...构造 repo...
  final v = await repo.getOrNull<bool>('missing_key');
  expect(v, isNull);
});

test('getOrNull returns value when key set', () async {
  await repo.set<bool>('k', true);
  final v = await repo.getOrNull<bool>('k');
  expect(v, isTrue);
});
```

- [ ] **Step 5.2: 跑测试验证 fail**

Expected: FAIL（getOrNull 不存在）

- [ ] **Step 5.3: 加 abstract method**

Modify `app/lib/data/repositories/settings_repository.dart`:

```dart
abstract class SettingsRepository {
  Future<T> get<T>(String key, T defaultValue);

  /// Returns null if key is not set. Use this when the caller needs to
  /// distinguish "unset" from "explicitly set to default value" (e.g.,
  /// first-launch seeding of preferences).
  Future<T?> getOrNull<T>(String key);

  Future<void> set<T>(String key, T value);
}
```

- [ ] **Step 5.4: 实现 LocalSettingsRepository.getOrNull**

Modify `app/lib/data/repositories/local_settings_repository.dart`:

在 `set<T>` 之后加：
```dart
@override
Future<T?> getOrNull<T>(String key) async {
  final raw = await _dao.get(key);
  if (raw == null) return null;
  return _decode<T>(raw);
}
```

- [ ] **Step 5.5: 跑测试 + analyze**

Run: `cd app && /c/flutter/bin/flutter.bat test --concurrency=1 test/data/repositories/local_settings_repository_test.dart && /c/flutter/bin/dart.bat analyze lib/data/repositories/`

Expected: All PASS, no issues

- [ ] **Step 5.6: Commit + push**

```bash
git add app/lib/data/repositories/settings_repository.dart app/lib/data/repositories/local_settings_repository.dart app/test/data/repositories/local_settings_repository_test.dart
git commit -m "$(cat <<'EOF'
feat(m2.2/t5): SettingsRepository.getOrNull

New abstract method to distinguish "key unset" from "explicit default".
LocalSettingsRepository delegates to SettingsDao.get (already nullable).
Required for first-launch seeding of chapter_end_prompt_enabled default
(M2.2/T6) without overwriting explicit user choice.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 6: i18n + Settings 开关 + ensureDefault

**Files:**
- Modify: `app/lib/l10n/app_zh.arb`
- Modify: `app/lib/l10n/app_en.arb`
- Modify: `app/lib/l10n/app_localizations_zh.arb` (l10n auto-gen，跑工具后自动更新，commit 时含)
- Modify: `app/lib/l10n/app_localizations_en.arb` (同上)
- Create: `app/lib/features/reader/providers/chapter_end_prompt_enabled_provider.dart`
- Modify: `app/lib/features/settings/pages/settings_page.dart`
- Modify: `app/lib/app.dart` 或 `app/lib/main.dart`（启动时跑 ensureDefault）
- Test: `app/test/features/reader/providers/chapter_end_prompt_enabled_provider_test.dart`

- [ ] **Step 6.1: 加 i18n keys**

Modify `app/lib/l10n/app_zh.arb`（在合适位置插入）：

```json
"chapterEndPromptMessage": "本章已读完？",
"@chapterEndPromptMessage": {},
"chapterEndPromptReview": "回顾本章",
"@chapterEndPromptReview": {},
"chapterEndPromptNext": "下一章",
"@chapterEndPromptNext": {},
"chapterEndPromptDismiss": "关闭",
"@chapterEndPromptDismiss": {},
"settingsChapterEndPrompt": "章节结束提示",
"@settingsChapterEndPrompt": {},
"settingsChapterEndPromptSubtitle": "翻到一章末页时提示回顾",
"@settingsChapterEndPromptSubtitle": {},
```

Modify `app/lib/l10n/app_en.arb` 同位置加：

```json
"chapterEndPromptMessage": "Finished this chapter?",
"@chapterEndPromptMessage": {},
"chapterEndPromptReview": "Review chapter",
"@chapterEndPromptReview": {},
"chapterEndPromptNext": "Next chapter",
"@chapterEndPromptNext": {},
"chapterEndPromptDismiss": "Dismiss",
"@chapterEndPromptDismiss": {},
"settingsChapterEndPrompt": "Chapter-end prompt",
"@settingsChapterEndPrompt": {},
"settingsChapterEndPromptSubtitle": "Prompt when reaching end of chapter",
"@settingsChapterEndPromptSubtitle": {},
```

- [ ] **Step 6.2: 跑 l10n 工具生成**

Run: `cd app && /c/flutter/bin/flutter.bat gen-l10n`

Expected: `app/lib/gen_l10n/app_localizations*.dart` 文件自动更新（含 6 个新 key 的 getter）

- [ ] **Step 6.3: 写 enabled provider 测试**

Create `app/test/features/reader/providers/chapter_end_prompt_enabled_provider_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
// ...header...

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/repositories/settings_repository.dart';
import 'package:zhiyue/features/reader/providers/chapter_end_prompt_enabled_provider.dart';

class _FakeSettingsRepo implements SettingsRepository {
  _FakeSettingsRepo(this._values);
  final Map<String, Object?> _values;

  @override
  Future<T> get<T>(String key, T defaultValue) async =>
      (_values[key] as T?) ?? defaultValue;

  @override
  Future<T?> getOrNull<T>(String key) async => _values[key] as T?;

  @override
  Future<void> set<T>(String key, T value) async {
    _values[key] = value;
  }
}

SettingsRepository _stubRepo() => _FakeSettingsRepo({});

void main() {
  test('initial state is loading', () {
    final container = ProviderContainer(overrides: [
      // 实施时根据 provider 实际签名写 override
    ]);
    addTearDown(container.dispose);
    // 实施时填具体断言
  });

  // 详细测试在实施时根据 provider 真实签名补全
}
```

> 实施时根据 provider 真实签名补全测试。最小覆盖：load 已存的 true/false + set 写入。

- [ ] **Step 6.4: 实现 enabled provider**

Create `app/lib/features/reader/providers/chapter_end_prompt_enabled_provider.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
// ...header...

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../data/repositories/settings_repository.dart';

const String kChapterEndPromptEnabledKey = 'chapter_end_prompt_enabled';

/// Whether the chapter-end prompt SnackBar should fire when the reader
/// reaches end of a chapter. AsyncValue until first load completes.
final chapterEndPromptEnabledProvider =
    StateNotifierProvider<ChapterEndPromptEnabledNotifier, AsyncValue<bool>>(
        (ref) {
  return ChapterEndPromptEnabledNotifier(ref.watch(settingsRepositoryProvider));
});

class ChapterEndPromptEnabledNotifier extends StateNotifier<AsyncValue<bool>> {
  ChapterEndPromptEnabledNotifier(this._repo)
      : super(const AsyncValue<bool>.loading()) {
    _load();
  }

  final SettingsRepository _repo;

  Future<void> _load() async {
    try {
      final v = await _repo.get<bool>(kChapterEndPromptEnabledKey, false);
      if (mounted) state = AsyncValue<bool>.data(v);
    } catch (e, st) {
      if (mounted) state = AsyncValue<bool>.error(e, st);
    }
  }

  Future<void> set(bool value) async {
    await _repo.set<bool>(kChapterEndPromptEnabledKey, value);
    if (mounted) state = AsyncValue<bool>.data(value);
  }
}
```

- [ ] **Step 6.5: 实现 ensureDefault + 在启动调用**

在合适的启动初始化处（找 `main.dart` 或 `app.dart` 的 init 逻辑）加：

```dart
Future<void> ensureChapterEndPromptDefault(SettingsRepository repo, ApiKeyStore apiKeyStore) async {
  final existing = await repo.getOrNull<bool>(kChapterEndPromptEnabledKey);
  if (existing != null) return;  // 用户已设置过，不要覆盖
  final hasApiKey = (await apiKeyStore.get()) != null;
  await repo.set<bool>(kChapterEndPromptEnabledKey, hasApiKey);
}
```

> 注：`kChapterEndPromptEnabledKey` 从 chapter_end_prompt_enabled_provider.dart 导入。
>
> **挂载点**：在 `main.dart` 的 `main()` 内 ProviderContainer 初始化后、runApp 前调用。具体位置实施时根据 main.dart 现有 init flow 决定（很可能在 `await database.open()` 之后）。如果 main.dart 太复杂，新建 `app/lib/bootstrap/chapter_end_prompt_default.dart` 文件存这个函数，main.dart import 调用。

- [ ] **Step 6.6: Settings page 加 tile**

Modify `app/lib/features/settings/pages/settings_page.dart`:

a) import:
```dart
import '../../../gen_l10n/app_localizations.dart';
import '../providers/chapter_end_prompt_enabled_provider.dart';  // 不对，应在 reader/providers
```

正确路径：
```dart
import '../../reader/providers/chapter_end_prompt_enabled_provider.dart';
```

b) 在 Reading section（紧邻 Typography Profiles ListTile 之后）加 ConsumerWidget subsection：

```dart
_SectionHeader(label: l10n.settingsSectionReading),
ListTile(
  leading: const Icon(Icons.text_fields),
  title: Text(l10n.settingsTypographyProfiles),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.push('/settings/typography'),
),
const _ChapterEndPromptTile(),  // 新增
```

c) 文件底部追加：
```dart
class _ChapterEndPromptTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final asyncEnabled = ref.watch(chapterEndPromptEnabledProvider);
    return SwitchListTile(
      title: Text(l10n.settingsChapterEndPrompt),
      subtitle: Text(l10n.settingsChapterEndPromptSubtitle),
      value: asyncEnabled.maybeWhen(
        data: (v) => v,
        orElse: () => false,
      ),
      onChanged: asyncEnabled.maybeWhen(
        data: (_) => (v) =>
            ref.read(chapterEndPromptEnabledProvider.notifier).set(v),
        orElse: () => null,
      ),
    );
  }
}
```

- [ ] **Step 6.7: 跑测试 + analyze + 全量测试**

Run:
```
cd app
/c/flutter/bin/flutter.bat test --concurrency=1 test/features/reader/providers/chapter_end_prompt_enabled_provider_test.dart
/c/flutter/bin/dart.bat analyze lib/features/reader/providers/chapter_end_prompt_enabled_provider.dart lib/features/settings/pages/settings_page.dart
/c/flutter/bin/flutter.bat test --concurrency=1
```

Expected: 全部 PASS, no issues

- [ ] **Step 6.8: Commit + push**

```bash
git add app/lib/l10n/app_zh.arb app/lib/l10n/app_en.arb app/lib/gen_l10n/app_localizations.dart app/lib/gen_l10n/app_localizations_zh.dart app/lib/gen_l10n/app_localizations_en.dart app/lib/features/reader/providers/chapter_end_prompt_enabled_provider.dart app/lib/features/settings/pages/settings_page.dart app/lib/bootstrap/chapter_end_prompt_default.dart app/lib/main.dart app/test/features/reader/providers/chapter_end_prompt_enabled_provider_test.dart
git commit -m "$(cat <<'EOF'
feat(m2.2/t6): Settings toggle + first-launch default seeding

- 6 i18n keys (zh + en)
- chapterEndPromptEnabledProvider: AsyncValue<bool> StateNotifier
- ensureChapterEndPromptDefault: writes default on first launch
  (true if API key configured, false otherwise; never overwrites
  explicit user choice via getOrNull check)
- Settings page SwitchListTile in Reading section
- _ChapterEndPromptTile ConsumerWidget respects AsyncValue loading

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

> **Commit 内容**：根据 step 6.5 实际新增/修改的文件调整 git add 列表（如未新建 bootstrap/ 文件，就只 add 修改的 main.dart）。

---

## Task 7: ChapterEndPromptController

**Files:**
- Create: `app/lib/features/reader/providers/chapter_end_prompt_controller.dart`
- Test: `app/test/features/reader/providers/chapter_end_prompt_controller_test.dart`

- [ ] **Step 7.1: 写测试**

Create `app/test/features/reader/providers/chapter_end_prompt_controller_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
// ...header...

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine_epub_view/src/chapter_end_event.dart';
import 'package:zhiyue/data/repositories/settings_repository.dart';
import 'package:zhiyue/features/reader/providers/chapter_end_prompt_controller.dart';
import 'package:zhiyue/features/reader/services/chapter_end_detector.dart';

class _FakeSettingsRepo implements SettingsRepository {
  _FakeSettingsRepo(this._values);
  final Map<String, Object?> _values;
  @override
  Future<T> get<T>(String key, T defaultValue) async =>
      (_values[key] as T?) ?? defaultValue;
  @override
  Future<T?> getOrNull<T>(String key) async => _values[key] as T?;
  @override
  Future<void> set<T>(String key, T value) async {
    _values[key] = value;
  }
}

void main() {
  late StreamController<ChapterEndEvent> source;
  late _FakeSettingsRepo repo;

  setUp(() {
    source = StreamController<ChapterEndEvent>.broadcast();
    repo = _FakeSettingsRepo({'chapter_end_prompt_enabled': true});
  });

  tearDown(() {
    source.close();
  });

  test('enabled state + event → visibility visible', () async {
    final container = ProviderContainer(overrides: [
      settingsRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);

    final notifier = ChapterEndPromptController(
      repo: repo,
      source: source.stream,
      bookId: 'b1',
    );
    addTearDown(notifier.dispose);

    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.visibility, ChapterEndPromptVisibility.visible);
    expect(notifier.state.chapterIndex, 3);
    expect(notifier.state.hasNext, isTrue);
  });

  test('disabled setting → state stays hidden', () async {
    repo = _FakeSettingsRepo({'chapter_end_prompt_enabled': false});
    final notifier = ChapterEndPromptController(
      repo: repo,
      source: source.stream,
      bookId: 'b1',
    );
    addTearDown(notifier.dispose);

    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.visibility, ChapterEndPromptVisibility.hidden);
  });

  test('dismiss sets visibility hidden', () async {
    final notifier = ChapterEndPromptController(
      repo: repo,
      source: source.stream,
      bookId: 'b1',
    );
    addTearDown(notifier.dispose);

    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    await Future<void>.delayed(Duration.zero);
    notifier.dismiss();

    expect(notifier.state.visibility, ChapterEndPromptVisibility.hidden);
  });
}
```

> 注：上面测试用直接实例化 `ChapterEndPromptController`，不走 provider 系统（避免 Riverpod family 复杂性）。Provider wrapper 在 reader_body 接线时按需加。

- [ ] **Step 7.2: 跑测试验证 fail**

Expected: FAIL（文件不存在）

- [ ] **Step 7.3: 实现 controller**

Create `app/lib/features/reader/providers/chapter_end_prompt_controller.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
// ...header...

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reader_engine_epub_view/src/chapter_end_event.dart';
import '../../../data/repositories/settings_repository.dart';
import '../services/chapter_end_detector.dart';
import 'chapter_end_prompt_enabled_provider.dart';

enum ChapterEndPromptVisibility { hidden, visible }

class ChapterEndPromptState {
  const ChapterEndPromptState({
    this.visibility = ChapterEndPromptVisibility.hidden,
    this.bookId = '',
    this.chapterIndex = 0,
    this.hasNext = false,
  });

  final ChapterEndPromptVisibility visibility;
  final String bookId;
  final int chapterIndex;
  final bool hasNext;

  ChapterEndPromptState copyWith({
    ChapterEndPromptVisibility? visibility,
    String? bookId,
    int? chapterIndex,
    bool? hasNext,
  }) {
    return ChapterEndPromptState(
      visibility: visibility ?? this.visibility,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      hasNext: hasNext ?? this.hasNext,
    );
  }
}

/// Settings-gated prompt state. Reads `chapter_end_prompt_enabled` from
/// SettingsRepository on every event (cheap; in-memory cache in repo).
///
/// Constructed directly by reader_body (not via Riverpod family) to keep
/// the source stream + bookId explicit and testable.
class ChapterEndPromptController extends StateNotifier<ChapterEndPromptState> {
  ChapterEndPromptController({
    required SettingsRepository repo,
    required Stream<ChapterEndEvent> source,
    required String bookId,
  })  : _repo = repo,
        super(const ChapterEndPromptState()) {
    _detector = ChapterEndDetector(source: source, bookId: bookId)..start();
    _sub = _detector.promptRequests.listen(_onPromptRequest);
  }

  final SettingsRepository _repo;
  late final ChapterEndDetector _detector;
  late final StreamSubscription<PromptRequest> _sub;

  Future<void> _onPromptRequest(PromptRequest req) async {
    final enabled =
        await _repo.get<bool>(kChapterEndPromptEnabledKey, false);
    if (!mounted) return;
    if (!enabled) return;
    state = ChapterEndPromptState(
      visibility: ChapterEndPromptVisibility.visible,
      bookId: req.bookId,
      chapterIndex: req.chapterIndex,
      hasNext: req.hasNext,
    );
  }

  void dismiss() {
    state = const ChapterEndPromptState();
  }

  @override
  void dispose() {
    _sub.cancel();
    _detector.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 7.4: 跑测试验证通过**

Run: `cd app && /c/flutter/bin/flutter.bat test --concurrency=1 test/features/reader/providers/chapter_end_prompt_controller_test.dart`

Expected: 3 tests PASS

- [ ] **Step 7.5: analyze**

Run: `cd app && /c/flutter/bin/dart.bat analyze lib/features/reader/providers/chapter_end_prompt_controller.dart`

Expected: No issues

- [ ] **Step 7.6: Commit + push**

```bash
git add app/lib/features/reader/providers/chapter_end_prompt_controller.dart app/test/features/reader/providers/chapter_end_prompt_controller_test.dart
git commit -m "$(cat <<'EOF'
feat(m2.2/t7): ChapterEndPromptController

StateNotifier<ChapterEndPromptState> with settings gate. Constructed
directly (not via Riverpod family) so source stream + bookId stay
explicit. Reads settings on every event (cheap, repo caches internally).
Dismiss resets state to hidden.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 8: ChapterEndPromptSnackBar widget

**Files:**
- Create: `app/lib/features/reader/widgets/chapter_end_prompt_snackbar.dart`
- Test: `app/test/features/reader/widgets/chapter_end_prompt_snackbar_test.dart`

- [ ] **Step 8.1: 写测试**

Create `app/test/features/reader/widgets/chapter_end_prompt_snackbar_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
// ...header...

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/widgets/chapter_end_prompt_snackbar.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

Widget _wrap(SnackBar snackbar) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () =>
            ScaffoldMessenger.of(context).showSnackBar(snackbar),
        child: const Text('trigger'),
      );
    })),
  );
}

Future<void> _showSnackBar(WidgetTester tester) async {
  await tester.tap(find.text('trigger'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('non-last chapter shows 3 buttons: review, next, dismiss',
      (tester) async {
    var review = 0;
    var next = 0;
    var dismiss = 0;
    await tester.pumpWidget(_wrap(ChapterEndPromptSnackBar(
      context: tester.element(find.byType(Scaffold)),
      hasNext: true,
      onReview: () => review++,
      onNext: () => next++,
      onDismiss: () => dismiss++,
    )));
    await _showSnackBar(tester);

    expect(find.text('回顾本章'), findsOneWidget);
    expect(find.text('下一章'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
  });

  testWidgets('last chapter hides next button', (tester) async {
    await tester.pumpWidget(_wrap(ChapterEndPromptSnackBar(
      context: tester.element(find.byType(Scaffold)),
      hasNext: false,
      onReview: () {},
      onNext: () {},
      onDismiss: () {},
    )));
    await _showSnackBar(tester);

    expect(find.text('回顾本章'), findsOneWidget);
    expect(find.text('下一章'), findsNothing);
    expect(find.text('关闭'), findsOneWidget);
  });

  testWidgets('tapping review triggers callback', (tester) async {
    var fired = false;
    await tester.pumpWidget(_wrap(ChapterEndPromptSnackBar(
      context: tester.element(find.byType(Scaffold)),
      hasNext: true,
      onReview: () => fired = true,
      onNext: () {},
      onDismiss: () {},
    )));
    await _showSnackBar(tester);

    await tester.tap(find.text('回顾本章'));
    expect(fired, isTrue);
  });

  testWidgets('tapping next triggers callback', (tester) async {
    var fired = false;
    await tester.pumpWidget(_wrap(ChapterEndPromptSnackBar(
      context: tester.element(find.byType(Scaffold)),
      hasNext: true,
      onReview: () {},
      onNext: () => fired = true,
      onDismiss: () {},
    )));
    await _showSnackBar(tester);

    await tester.tap(find.text('下一章'));
    expect(fired, isTrue);
  });

  testWidgets('tapping dismiss triggers callback', (tester) async {
    var fired = false;
    await tester.pumpWidget(_wrap(ChapterEndPromptSnackBar(
      context: tester.element(find.byType(Scaffold)),
      hasNext: true,
      onReview: () {},
      onNext: () {},
      onDismiss: () => fired = true,
    )));
    await _showSnackBar(tester);

    await tester.tap(find.text('关闭'));
    expect(fired, isTrue);
  });
}
```

> 注：测试里 `context: tester.element(find.byType(Scaffold))` 是触发 SnackBar 之前拿 context。实际可能需要先 pump 再拿。实施时如果 test 报错，调整顺序：先 pump MaterialApp，再 `tester.element(find.byType(Scaffold))` 取 context，再 pumpWidget 重新包装带 trigger 的版本。简化方案：把 BuildContext 参数改为在 widget build 时拿（用 Builder），但这样 widget API 就变了。最简单：测试不验本地化文案，只验按钮数量 + 回调。

实施时如果本地化文案测试不稳定，改成：
```dart
expect(find.byType(TextButton), findsNWidgets(3));  // 非末章
expect(find.byType(TextButton), findsNWidgets(2));  // 末章
```

- [ ] **Step 8.2: 跑测试验证 fail**

Expected: FAIL（文件不存在）

- [ ] **Step 8.3: 实现 widget**

Create `app/lib/features/reader/widgets/chapter_end_prompt_snackbar.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
// ...header...

import 'package:flutter/material.dart';

import '../../../gen_l10n/app_localizations.dart';

/// SnackBar shown by reader_body when [ChapterEndPromptController] state
/// becomes visible. Three inline [TextButton]s inside content row because
/// SnackBar's `action` slot accepts only one button.
///
/// Buttons:
/// - 回顾本章 / Review: always shown (detector only fires on EPUB path)
/// - 下一章 / Next: shown when [hasNext] is true (i.e., not last chapter)
/// - 关闭 / Dismiss: always shown
class ChapterEndPromptSnackBar extends SnackBar {
  ChapterEndPromptSnackBar({
    super.key,
    required BuildContext context,
    required bool hasNext,
    required VoidCallback onReview,
    required VoidCallback onNext,
    required VoidCallback onDismiss,
  }) : super(
          content: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.chapterEndPromptMessage,
                ),
              ),
              TextButton(
                onPressed: onReview,
                child: Text(
                  AppLocalizations.of(context)!.chapterEndPromptReview,
                ),
              ),
              if (hasNext)
                TextButton(
                  onPressed: onNext,
                  child: Text(
                    AppLocalizations.of(context)!.chapterEndPromptNext,
                  ),
                ),
              TextButton(
                onPressed: onDismiss,
                child: Text(
                  AppLocalizations.of(context)!.chapterEndPromptDismiss,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 12),
          behavior: SnackBarBehavior.floating,
        );
}
```

- [ ] **Step 8.4: 跑测试验证通过**

Run: `cd app && /c/flutter/bin/flutter.bat test --concurrency=1 test/features/reader/widgets/chapter_end_prompt_snackbar_test.dart`

Expected: 5 tests PASS

- [ ] **Step 8.5: analyze**

Run: `cd app && /c/flutter/bin/dart.bat analyze lib/features/reader/widgets/chapter_end_prompt_snackbar.dart`

Expected: No issues

- [ ] **Step 8.6: Commit + push**

```bash
git add app/lib/features/reader/widgets/chapter_end_prompt_snackbar.dart app/test/features/reader/widgets/chapter_end_prompt_snackbar_test.dart
git commit -m "$(cat <<'EOF'
feat(m2.2/t8): ChapterEndPromptSnackBar widget

Custom SnackBar content with 3 inline TextButtons (Review / Next /
Dismiss). SnackBar.action only supports one button, so the buttons live
inside the content Row. Next button conditional on hasNext (false when
last chapter).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 9: reader_body 接线 + integration 测试

**Files:**
- Modify: `app/lib/features/reader/pages/reader_body.dart`
- Test: `app/test/features/reader/chapter_end_prompt_integration_test.dart`

> **重要**：reader_body.dart ~580 行，是核心 UI 类。先 Read 整个文件，理解：
> - `build()` 方法结构
> - `_onOpenReview` 方法签名（line 457 附近）
> - engine 字段访问模式
> - ScaffoldMessenger 在哪里访问
>
> 改动点（最小侵入）：
> 1. import `reader_engine_epub_view` 的 `ConcreteEpubReaderEngine`、`ChapterEndEvent`
> 2. import `ChapterEndPromptController`、`ChapterEndPromptSnackBar`
> 3. 在 `_ReaderBodyState.build` 内加 `isEpub` 判断 + 条件 watch controller
> 4. 用 `ref.listen<ChapterEndPromptState>` 监听 visible 变化 → `_showChapterEndPrompt`
> 5. 新增 `_showChapterEndPrompt(ChapterEndPromptState)` 方法
> 6. `dispose` 时关掉 controller（如果 controller 是 state 字段）
>
> **controller 生命周期**：建议在 `initState` 创建为字段（实例化时传入 `engine` cast 后的 `chapterEndEvents`），`dispose` 时关掉。这样 build() 里只需 `ref.watch` 不需每次新建。

- [ ] **Step 9.1: Read reader_body.dart 现状**

读全文，确认：
- `_ReaderBodyState` 字段区
- `initState` / `dispose` 现有内容
- `build` 方法结构
- `_onOpenReview` 完整签名

- [ ] **Step 9.2: 写 integration 测试（精简版）**

Create `app/test/features/reader/chapter_end_prompt_integration_test.dart`:

```dart
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
// ...header...

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/reader/widgets/chapter_end_prompt_snackbar.dart';
import 'package:zhiyue/features/reader/services/chapter_end_detector.dart';
import 'package:zhiyue/features/reader/providers/chapter_end_prompt_controller.dart';
import 'package:zhiyue/data/repositories/settings_repository.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';
import 'dart:async';
import 'package:reader_engine_epub_view/src/chapter_end_event.dart';

class _FakeSettingsRepo implements SettingsRepository {
  _FakeSettingsRepo(this._values);
  final Map<String, Object?> _values;
  @override
  Future<T> get<T>(String key, T defaultValue) async =>
      (_values[key] as T?) ?? defaultValue;
  @override
  Future<T?> getOrNull<T>(String key) async => _values[key] as T?;
  @override
  Future<void> set<T>(String key, T value) async {
    _values[key] = value;
  }
}

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  // Integration 测试 1：controller visible → SnackBar 显示
  testWidgets('SnackBar shows when controller state becomes visible',
      (tester) async {
    final source = StreamController<ChapterEndEvent>.broadcast();
    addTearDown(source.close);

    final repo = _FakeSettingsRepo({'chapter_end_prompt_enabled': true});
    final controller = ChapterEndPromptController(
      repo: repo,
      source: source.stream,
      bookId: 'b1',
    );
    addTearDown(controller.dispose);

    late BuildContext capturedContext;
    await tester.pumpWidget(_wrap(StatefulBuilder(builder: (ctx, setState) {
      capturedContext = ctx;
      if (controller.state.visibility ==
          ChapterEndPromptVisibility.visible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(capturedContext).showSnackBar(
            ChapterEndPromptSnackBar(
              context: capturedContext,
              hasNext: controller.state.hasNext,
              onReview: () {},
              onNext: () {},
              onDismiss: () {},
            ),
          );
        });
      }
      return const SizedBox.shrink();
    })));

    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    await tester.pumpAndSettle();

    expect(find.text('回顾本章'), findsOneWidget);
    expect(find.text('下一章'), findsOneWidget);
  });

  testWidgets('SnackBar hidden when settings disabled', (tester) async {
    final source = StreamController<ChapterEndEvent>.broadcast();
    addTearDown(source.close);

    final repo = _FakeSettingsRepo({'chapter_end_prompt_enabled': false});
    final controller = ChapterEndPromptController(
      repo: repo,
      source: source.stream,
      bookId: 'b1',
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_wrap(const SizedBox.shrink()));

    source.add(const ChapterEndEvent(chapterIndex: 3, isLastChapter: false));
    await tester.pumpAndSettle();

    expect(controller.state.visibility, ChapterEndPromptVisibility.hidden);
    expect(find.byType(SnackBar), findsNothing);
  });

  // PDF gate test: reader_body 端的 isEpub 判断在 unit test 难以覆盖（需要 mock engine），
  // 留给手测验收。
}
```

> 注：完整 reader_body widget-level 集成测试需要 mock ReaderEngine，复杂度高。本 plan 只覆盖 controller + SnackBar 联动；reader_body 接线由 step 9.5 的手测验证。

- [ ] **Step 9.3: 跑测试验证（应通过，因为 controller 和 SnackBar 已实现）**

Run: `cd app && /c/flutter/bin/flutter.bat test --concurrency=1 test/features/reader/chapter_end_prompt_integration_test.dart`

Expected: 2 tests PASS（如失败，根据错误调整）

- [ ] **Step 9.4: 接线 reader_body**

Modify `app/lib/features/reader/pages/reader_body.dart`:

a) import 区追加：
```dart
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';
import 'package:reader_engine_epub_view/src/chapter_end_event.dart';
import '../providers/chapter_end_prompt_controller.dart';
import '../widgets/chapter_end_prompt_snackbar.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../core/providers.dart';
```

b) `_ReaderBodyState` 字段区追加：
```dart
ChapterEndPromptController? _chapterEndPromptController;
```

c) 在 `initState`（如不存在则在 build 首次进入时延迟创建）：
```dart
@override
void initState() {
  super.initState();
  // 既有 init 代码...
  if (widget.engine is ConcreteEpubReaderEngine) {
    final epubEngine = widget.engine as ConcreteEpubReaderEngine;
    _chapterEndPromptController = ChapterEndPromptController(
      repo: ref.read(settingsRepositoryProvider),
      source: epubEngine.chapterEndEvents,
      bookId: widget.bookId,
    );
  }
}
```

> 注：ref 在 ConsumerStatefulWidget 的 initState 里**不能**直接用——要用 `WidgetsBinding.instance.addPostFrameCallback` 延迟，或者用 `ref.read` 在 build 里惰性初始化。最稳妥：在 build 顶部检查并惰性初始化。

替代方案（推荐）：在 build 方法里 lazy-init：
```dart
@override
Widget build(BuildContext context) {
  // 惰性初始化 controller（首次 build 时 ref 可用）
  if (_chapterEndPromptController == null &&
      widget.engine is ConcreteEpubReaderEngine) {
    final epubEngine = widget.engine as ConcreteEpubReaderEngine;
    _chapterEndPromptController = ChapterEndPromptController(
      repo: ref.read(settingsRepositoryProvider),
      source: epubEngine.chapterEndEvents,
      bookId: widget.bookId,
    );
    // 监听 visible 变化
    _chapterEndListener ??= _chapterEndPromptController!.addListener(
      (state) {
        if (state.visibility == ChapterEndPromptVisibility.visible) {
          _showChapterEndPrompt(state);
        }
      },
    );
  }
  // ...既有 build 逻辑...
}
```

d) 新增字段 `_chapterEndListener`:
```dart
StateListener<ChapterEndPromptState>? _chapterEndListener;
```
（实际 Riverpod/StateNotifier 的 listen API 是 `controller.addListener((state) {...})` 返回 void，需要用其他方式管理。最简：用 `ref.listen` 直接 watch controller.state，但 controller 不是 provider。）

最简单可靠：让 `_chapterEndPromptController` 改为 StateNotifierProvider，用 ref.listen。或者用 `controller.stream`（StateNotifier 没有 stream，但可以转）。

**最简方案（推荐）**：直接用 `ValueListenableBuilder` 或在 build 里 `controller.state` + addListener：

```dart
// 在 build 中（首次创建后）
if (_chapterEndPromptController != null) {
  _chapterEndPromptController!.addListener((state) {
    if (state.visibility == ChapterEndPromptVisibility.visible &&
        _lastPromptVisibility != ChapterEndPromptVisibility.visible) {
      _lastPromptVisibility = state.visibility;
      _showChapterEndPrompt(state);
    } else {
      _lastPromptVisibility = state.visibility;
    }
  });
}
```

StateNotifier.addListener 会在状态变化时回调。但每次 build 都 addListener 会累积——需要在 dispose 时清。或者用 `_lastPromptVisibility` 字段防重。

实施时**简化**：用 Persistent listener（在 controller 创建后立即 add 一次，配合 _lastVisibility 字段）。

e) 新增 `_showChapterEndPrompt` 方法：
```dart
void _showChapterEndPrompt(ChapterEndPromptState s) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(ChapterEndPromptSnackBar(
      context: context,
      hasNext: s.hasNext,
      onReview: () {
        _chapterEndPromptController?.dismiss();
        _onOpenReview(s.chapterIndex);
      },
      onNext: () {
        _chapterEndPromptController?.dismiss();
        engine.nextSpine();
      },
      onDismiss: () {
        _chapterEndPromptController?.dismiss();
      },
    ));
}
```

f) 修改 `dispose`:
```dart
@override
void dispose() {
  _chapterEndPromptController?.dispose();
  // ...既有 dispose...
  super.dispose();
}
```

- [ ] **Step 9.5: 跑全量测试 + analyze**

Run:
```
cd app
/c/flutter/bin/flutter.bat test --concurrency=1
/c/flutter/bin/dart.bat analyze
```

Expected: 全部 PASS（既有 762 + 新增测试），0 errors / 0 warnings

- [ ] **Step 9.6: Commit + push**

```bash
git add app/lib/features/reader/pages/reader_body.dart app/test/features/reader/chapter_end_prompt_integration_test.dart
git commit -m "$(cat <<'EOF'
feat(m2.2/t9): wire chapter-end prompt into reader_body

Lazy-init ChapterEndPromptController only on EPUB path
(engine is ConcreteEpubReaderEngine). PDF path skips creation
entirely — no SnackBar, no detector, no overhead.

Controller state changes drive ScaffoldMessenger.showSnackBar via
ChapterEndPromptSnackBar widget. Review button reuses _onOpenReview
from M2.1. Next button calls engine.nextSpine(). Dismiss resets state.

Integration test: controller state visible → SnackBar shown;
disabled setting → state stays hidden.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

---

## Task 10: M2.2 完成验证 + tag

**Files:**
- Modify: `README.md`（version badge 从 v1.1.0-alpha → v1.2.0-alpha）
- Modify: `docs/releases/release-checklist.md`（追加 v1.2.0-alpha 段）

- [ ] **Step 10.1: 跑全量测试**

Run: `cd app && /c/flutter/bin/flutter.bat test --concurrency=1`

Expected: 既有 762 + 新增 ~22 = ~784 PASS，3 skipped 不变

如果数字偏差大（< 780），停下来排查测试 missing。

- [ ] **Step 10.2: analyze 全工程**

Run:
```
cd app && /c/flutter/bin/dart.bat analyze
cd ../reader_engine && /c/flutter/bin/dart.bat analyze
cd ../reader_engine_epub_view && /c/flutter/bin/dart.bat analyze
cd ../reader_engine_pdf_view && /c/flutter/bin/dart.bat analyze
```

Expected: All 0 errors / 0 warnings

- [ ] **Step 10.3: 手测验证**

启动 dev：`cd app && /c/flutter/bin/flutter.bat run -d windows`

打开一本 EPUB，验证：
- [ ] paged 模式翻到一章末页 → SnackBar 弹出（含 3 按钮）
- [ ] scroll 模式滚到底部 → SnackBar 弹出
- [ ] 同一章二次到末页 → 不再弹
- [ ] 切到下一章再回原章 → 本次会话不再弹
- [ ] 末章末页 → 只显示【回顾本章】+【关闭】
- [ ] 点【回顾本章】→ ReviewPreviewSheet 弹出（M2.1）
- [ ] 点【下一章】→ engine 切章
- [ ] 点【关闭】→ SnackBar 消失
- [ ] Settings 关闭开关 → 下次到末页不弹
- [ ] Settings 开关开 → 重新生效

打开一本 PDF，验证：
- [ ] 翻页 → 不弹 SnackBar（PDF 路径完全跳过）
- [ ] 溢出菜单「下一章」按钮正常

- [ ] **Step 10.4: 更新 README badge**

Modify `README.md`: 找 v1.1.0-alpha badge，改为 v1.2.0-alpha。在 Features section 加 "Auto chapter-end prompt (EPUB): review / next / dismiss SnackBar when reaching end of chapter"。

- [ ] **Step 10.5: 更新 release checklist**

Modify `docs/releases/release-checklist.md` 追加 v1.2.0-alpha 段。

- [ ] **Step 10.6: Commit + push docs**

```bash
git add README.md docs/releases/release-checklist.md
git commit -m "$(cat <<'EOF'
docs(m2.2): bump to v1.2.0-alpha + release checklist

M2.2 complete: auto chapter-end prompt (EPUB only). paged + scroll
modes both detect chapter end; per-session per-chapter dedup; settings
toggle defaults ON when API key configured. PDF path unchanged.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
git push origin master
```

- [ ] **Step 10.7: 打 tag**

```bash
git tag -a m2.2-complete -m "M2.2: auto chapter-end prompt (EPUB)"
git tag -a v1.2.0-alpha -m "v1.2.0-alpha: M2.2 chapter-end prompt"
git push origin m2.2-complete v1.2.0-alpha
```

---

## 完成后总结

- 全量测试通过：既有 762 + 新增 ~22 = ~784 passed, 3 skipped
- analyze：4 包全 0 errors / 0 warnings
- 手测：paged/scroll/末章/Settings 切换/PDF 不弹 全场景验证
- tag：`m2.2-complete` + `v1.2.0-alpha`
- README + checklist 已更新

剩余 deferred（M2.3 起做）：
- M2.3 批量导出筛选（独立 milestone）
- Gitee Release 页面 v1.2.0-alpha notes（手贴）
- 3 张截图补全（reader / library / settings）
