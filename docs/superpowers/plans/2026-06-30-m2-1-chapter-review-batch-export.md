# M2.1 章节学习回顾 + Markdown 批量导出 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 交付章节学习回顾（手动触发，AI 流式生成 summary + keyTakeaways，复用 book_notes 存储）与 Markdown 批量导出（书架 → Obsidian vault 文件夹），完成 v1.1.0-alpha。

**Architecture:** 两个独立新服务，零数据库 schema 迁移。`BookReviewer` **完全独立**（不复用 AiGuide），因为 review 的缓存 hash 必须包含用户高亮状态，而 AiGuide 的 sourceHash 只覆盖文本——直接复用会导致高亮变化后仍命中旧缓存。`VaultExporter` 是纯函数批处理 + 直接文件 I/O。

**Tech Stack:** Flutter 3.44 / Dart 3.10 / Riverpod 2.5 / drift 2.18 / file_picker（**已是依赖**，无需 pubspec 改动）/ OpenAiCompatibleClient（已有）

**Spec 偏差说明**：spec §4.4 提议 BookReviewer 通过 `AiGuide.run(mode: review)` 复用 AiGuide。实施前发现 AiGuide 的 sourceHash 只 hash 章节文本，不包含用户高亮——会导致"新增高亮后回顾"命中错误缓存。本计划让 BookReviewer 独立处理缓存（mirror AiGuide 的 cache+stream+persist 模式，但用自己的 sourceHash 算法）。spec §9 中"`ai_guide.dart` 修改"在本计划里**不需要**。

**Windows 环境约束**（项目 memory）：
- 测试：`/c/flutter/bin/flutter.bat test --concurrency=1 <test_path>`
- 分析：`/c/flutter/bin/dart.bat analyze`（不用 `flutter analyze`，中文路径冲突）
- git add：单行命令，禁用反斜杠续行
- commit：HEREDOC，结尾 `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`
- 工作目录：`H:\projiect\电子书阅读平台`

---

## File Structure

### 新建（10 lib + 10 test）

```
app/lib/
├── services/ai/
│   ├── book_reviewer.dart                 # BookReviewer 服务（独立 stream pipeline）
│   └── review_output_parser.dart          # ReviewOutputParser 纯函数
├── features/ai/
│   ├── providers/
│   │   └── review_controller.dart         # ReviewController + reviewControllerProvider
│   └── widgets/
│       └── review_preview_sheet.dart      # ReviewPreviewSheet 模态
├── features/notes/services/
│   └── vault_exporter.dart                # VaultExporter 纯逻辑 + I/O
└── features/library/widgets/
    └── batch_export_dialog.dart           # BatchExportDialog stateful widget

app/test/  (10 个对应 _test.dart 文件)
```

### 修改（8 处）

| 文件 | 改动 |
|---|---|
| `app/lib/services/ai/prompt_builder.dart` | 新增 `review()` 模板 + bump `promptVersion` 1→2 |
| `app/lib/data/repositories/notes_repository.dart` | 加 `applyChapterReview` 抽象方法 |
| `app/lib/data/repositories/local_notes_repository.dart` | 实现 `applyChapterReview` |
| `app/lib/features/reader/widgets/toc_drawer.dart` | 每行加回顾 IconButton |
| `app/lib/features/reader/pages/reader_body.dart` | 顶栏溢出菜单加"回顾本章" |
| `app/lib/features/library/pages/library_page.dart` | AppBar 溢出菜单加"导出为 Markdown" |
| `app/lib/main.dart` 或 `lib/core/app_providers.dart` | 注入生产 `BookReviewer` override |
| `app/lib/gen_l10n/app_localizations_zh.arb` + `_en.arb` | 加 25 个 i18n key + regen |

---

## Task 1: 添加 i18n keys（25 个）

**Files:**
- Modify: `app/lib/gen_l10n/app_localizations_zh.arb`
- Modify: `app/lib/gen_l10n/app_localizations_en.arb`
- Regen: `app/lib/gen_l10n/app_localizations*.dart`

- [ ] **Step 1: 添加中文 arb keys**

打开 `app/lib/gen_l10n/app_localizations_zh.arb`，在最后一个 key 之前追加：

```json
  "reviewButtonLabel": "回顾本章",
  "@reviewButtonLabel": {},
  "reviewCurrentChapterMenuLabel": "回顾本章",
  "@reviewCurrentChapterMenuLabel": {},
  "reviewDisabledNotPreprocessedHint": "需先预处理本书",
  "@reviewDisabledNotPreprocessedHint": {},
  "reviewSheetTitle": "回顾：第 {n} 章 · {title}",
  "@reviewSheetTitle": {
    "placeholders": {
      "n": { "type": "int" },
      "title": { "type": "String" }
    }
  },
  "reviewSummarySection": "核心摘要",
  "@reviewSummarySection": {},
  "reviewTakeawaysSection": "核心要点",
  "@reviewTakeawaysSection": {},
  "reviewSaveButton": "保存到读书笔记",
  "@reviewSaveButton": {},
  "reviewCancelButton": "取消",
  "@reviewCancelButton": {},
  "reviewRetryButton": "重试",
  "@reviewRetryButton": {},
  "reviewStatusLoading": "AI 思考中…",
  "@reviewStatusLoading": {},
  "reviewStatusStreaming": "AI 正在生成…",
  "@reviewStatusStreaming": {},
  "reviewEmptyHighlightsHint": "（本章无高亮，AI 将基于正文做通用回顾）",
  "@reviewEmptyHighlightsHint": {},
  "reviewErrorAuthFailed": "API 密钥无效或未配置，请检查设置",
  "@reviewErrorAuthFailed": {},
  "reviewErrorParseFailed": "AI 输出格式异常，请重试",
  "@reviewErrorParseFailed": {},
  "reviewErrorServer": "网络或服务异常，请重试",
  "@reviewErrorServer": {},
  "batchExportMenuLabel": "导出为 Markdown",
  "@batchExportMenuLabel": {},
  "batchExportConfirmTitle": "导出读书笔记",
  "@batchExportConfirmTitle": {},
  "batchExportConfirmMessage": "将导出 {count} 本书的读书笔记到指定文件夹。",
  "@batchExportConfirmMessage": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "batchExportNoNotesTitle": "暂无可导出内容",
  "@batchExportNoNotesTitle": {},
  "batchExportNoNotesMessage": "还没有任何读书笔记。先做一些高亮或笔记再导出。",
  "@batchExportNoNotesMessage": {},
  "batchExportProgress": "正在导出 {current}/{total}：{title}",
  "@batchExportProgress": {
    "placeholders": {
      "current": { "type": "int" },
      "total": { "type": "int" },
      "title": { "type": "String" }
    }
  },
  "batchExportSuccess": "已导出 {count} 本书到 {path}",
  "@batchExportSuccess": {
    "placeholders": {
      "count": { "type": "int" },
      "path": { "type": "String" }
    }
  },
  "batchExportPartialFailure": "已导出 {success}/{total}，{failed} 本失败",
  "@batchExportPartialFailure": {
    "placeholders": {
      "success": { "type": "int" },
      "total": { "type": "int" },
      "failed": { "type": "int" }
    }
  },
  "batchExportCancelled": "已取消，导出 {success}/{total}",
  "@batchExportCancelled": {
    "placeholders": {
      "success": { "type": "int" },
      "total": { "type": "int" }
    }
  },
  "batchExportOpenFolder": "打开文件夹",
  "@batchExportOpenFolder": {},
```

- [ ] **Step 2: 添加英文 arb keys**

打开 `app/lib/gen_l10n/app_localizations_en.arb`，同样位置追加对应英文：

```json
  "reviewButtonLabel": "Review chapter",
  "@reviewButtonLabel": {},
  "reviewCurrentChapterMenuLabel": "Review this chapter",
  "@reviewCurrentChapterMenuLabel": {},
  "reviewDisabledNotPreprocessedHint": "Preprocess the book first",
  "@reviewDisabledNotPreprocessedHint": {},
  "reviewSheetTitle": "Review: ch {n} · {title}",
  "@reviewSheetTitle": {
    "placeholders": {
      "n": { "type": "int" },
      "title": { "type": "String" }
    }
  },
  "reviewSummarySection": "Summary",
  "@reviewSummarySection": {},
  "reviewTakeawaysSection": "Key takeaways",
  "@reviewTakeawaysSection": {},
  "reviewSaveButton": "Save to notes",
  "@reviewSaveButton": {},
  "reviewCancelButton": "Cancel",
  "@reviewCancelButton": {},
  "reviewRetryButton": "Retry",
  "@reviewRetryButton": {},
  "reviewStatusLoading": "AI thinking…",
  "@reviewStatusLoading": {},
  "reviewStatusStreaming": "AI generating…",
  "@reviewStatusStreaming": {},
  "reviewEmptyHighlightsHint": "(No highlights in this chapter; AI will produce a generic review.)",
  "@reviewEmptyHighlightsHint": {},
  "reviewErrorAuthFailed": "API key invalid or missing. Check settings.",
  "@reviewErrorAuthFailed": {},
  "reviewErrorParseFailed": "AI output malformed. Please retry.",
  "@reviewErrorParseFailed": {},
  "reviewErrorServer": "Network or server error. Please retry.",
  "@reviewErrorServer": {},
  "batchExportMenuLabel": "Export as Markdown",
  "@batchExportMenuLabel": {},
  "batchExportConfirmTitle": "Export notes",
  "@batchExportConfirmTitle": {},
  "batchExportConfirmMessage": "Will export {count} books' notes to a folder of your choice.",
  "@batchExportConfirmMessage": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "batchExportNoNotesTitle": "Nothing to export",
  "@batchExportNoNotesTitle": {},
  "batchExportNoNotesMessage": "No notes yet. Add highlights or annotations first.",
  "@batchExportNoNotesMessage": {},
  "batchExportProgress": "Exporting {current}/{total}: {title}",
  "@batchExportProgress": {
    "placeholders": {
      "current": { "type": "int" },
      "total": { "type": "int" },
      "title": { "type": "String" }
    }
  },
  "batchExportSuccess": "Exported {count} books to {path}",
  "@batchExportSuccess": {
    "placeholders": {
      "count": { "type": "int" },
      "path": { "type": "String" }
    }
  },
  "batchExportPartialFailure": "Exported {success}/{total}, {failed} failed",
  "@batchExportPartialFailure": {
    "placeholders": {
      "success": { "type": "int" },
      "total": { "type": "int" },
      "failed": { "type": "int" }
    }
  },
  "batchExportCancelled": "Cancelled, exported {success}/{total}",
  "@batchExportCancelled": {
    "placeholders": {
      "success": { "type": "int" },
      "total": { "type": "int" }
    }
  },
  "batchExportOpenFolder": "Open folder",
  "@batchExportOpenFolder": {},
```

- [ ] **Step 3: Regen localizations**

Run: `/c/flutter/bin/flutter.bat gen-l10n`

Expected: 退出码 0；`app/lib/gen_l10n/app_localizations*.dart` 文件被更新（新增 25 个 getter）。

- [ ] **Step 4: Smoke test - 跑现有测试套件确认无回归**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1`

Expected: 全部通过（716 + 2 skipped）。

- [ ] **Step 5: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add app/lib/gen_l10n/app_localizations_zh.arb app/lib/gen_l10n/app_localizations_en.arb app/lib/gen_l10n/app_localizations.dart app/lib/gen_l10n/app_localizations_zh.dart app/lib/gen_l10n/app_localizations_en.dart
```

```bash
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m2.1/t1): add 25 i18n keys for chapter review + batch export

Review: 15 keys (button, sheet title, status, error variants).
Batch export: 10 keys (menu, confirm, progress, success/cancel/failure).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: ReviewOutputParser（纯函数 JSON 解析）

**Files:**
- Create: `app/lib/services/ai/review_output_parser.dart`
- Test: `app/test/services/ai/review_output_parser_test.dart`

- [ ] **Step 1: 写 RED 测试**

创建 `app/test/services/ai/review_output_parser_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/ai/review_output_parser.dart';

void main() {
  group('ReviewOutputParser', () {
    test('parses valid JSON with summary + takeaways', () {
      const raw = '{"summary":"abc","keyTakeaways":["x","y","z"]}';
      final out = ReviewOutputParser.parse(raw);
      expect(out, isNotNull);
      expect(out!.summary, 'abc');
      expect(out.keyTakeaways, ['x', 'y', 'z']);
    });

    test('strips ```json fenced blocks', () {
      const raw = '```json\n{"summary":"hi","keyTakeaways":["a"]}\n```';
      final out = ReviewOutputParser.parse(raw);
      expect(out, isNotNull);
      expect(out!.summary, 'hi');
      expect(out.keyTakeaways, ['a']);
    });

    test('strips ``` fenced blocks without json label', () {
      const raw = '```\n{"summary":"hi","keyTakeaways":[]}\n```';
      final out = ReviewOutputParser.parse(raw);
      expect(out, isNotNull);
      expect(out!.summary, 'hi');
      expect(out.keyTakeaways, isEmpty);
    });

    test('returns null when summary field missing', () {
      const raw = '{"keyTakeaways":["x"]}';
      expect(ReviewOutputParser.parse(raw), isNull);
    });

    test('returns null when top-level is not an object', () {
      const raw = '["summary","keyTakeaways"]';
      expect(ReviewOutputParser.parse(raw), isNull);
    });

    test('filters non-String elements in keyTakeaways', () {
      const raw = '{"summary":"s","keyTakeaways":["ok",42,null,true]}';
      final out = ReviewOutputParser.parse(raw);
      expect(out, isNotNull);
      expect(out!.keyTakeaways, ['ok']);
    });

    test('returns null for unparseable garbage', () {
      const raw = '抱歉，无法完成';
      expect(ReviewOutputParser.parse(raw), isNull);
    });

    test('handles leading/trailing whitespace', () {
      const raw = '\n  {"summary":"s","keyTakeaways":["a"]}  \n';
      final out = ReviewOutputParser.parse(raw);
      expect(out, isNotNull);
      expect(out!.summary, 's');
    });
  });
}
```

- [ ] **Step 2: 跑测试确认 FAIL**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/services/ai/review_output_parser_test.dart`

Expected: FAIL（"library not found" 或 "ReviewOutputParser not defined"）

- [ ] **Step 3: 写实现**

创建 `app/lib/services/ai/review_output_parser.dart`：

```dart
import 'dart:convert';

/// Parsed review output from LLM JSON response.
class ReviewOutput {
  const ReviewOutput({required this.summary, required this.keyTakeaways});
  final String summary;
  final List<String> keyTakeaways;
}

/// Parses the LLM's review-mode JSON response.
///
/// Tolerates:
/// - Leading/trailing whitespace
/// - ```json ... ``` or ``` ... ``` fences (some LLMs ignore "no fences" instruction)
/// - Non-String elements in keyTakeaways (silently filtered)
///
/// Returns null if:
/// - JSON unparseable after fence stripping
/// - Top-level not an object
/// - `summary` field missing or not a String
/// - `keyTakeaways` missing or not a List
class ReviewOutputParser {
  const ReviewOutputParser._();

  static ReviewOutput? parse(String raw) {
    final trimmed = raw.trim();
    final unfenced = _stripFence(trimmed);
    final decoded = _tryDecode(unfenced);
    if (decoded == null) return null;
    if (decoded is! Map<String, dynamic>) return null;
    final summary = decoded['summary'];
    if (summary is! String) return null;
    final takeaways = decoded['keyTakeaways'];
    if (takeaways is! List) return null;
    final filtered =
        takeaways.whereType<String>().where((s) => s.isNotEmpty).toList();
    return ReviewOutput(summary: summary, keyTakeaways: filtered);
  }

  /// Strips one layer of ``` or ```json fencing if present.
  static String _stripFence(String s) {
    if (!s.startsWith('```')) return s;
    final firstNewline = s.indexOf('\n');
    if (firstNewline < 0) return s;
    var body = s.substring(firstNewline + 1);
    if (body.endsWith('```')) {
      body = body.substring(0, body.length - 3);
    }
    return body.trim();
  }

  static Object? _tryDecode(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 4: 跑测试确认 PASS**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/services/ai/review_output_parser_test.dart`

Expected: PASS（8 个测试全绿）

- [ ] **Step 5: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add app/lib/services/ai/review_output_parser.dart app/test/services/ai/review_output_parser_test.dart
```

```bash
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m2.1/t2): ReviewOutputParser for LLM JSON responses

Tolerates ```json fences + filters non-String takeaway elements.
Returns null on malformed input so caller can surface parseError.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: PromptBuilder.review + bump promptVersion

**Files:**
- Modify: `app/lib/services/ai/prompt_builder.dart`
- Test: `app/test/services/ai/prompt_builder_test.dart`（已有，追加用例）

- [ ] **Step 1: 追加 RED 测试**

打开 `app/test/services/ai/prompt_builder_test.dart`（若不存在则创建），追加：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/services/ai/prompt_builder.dart';

void main() {
  group('PromptBuilder.review', () {
    test('includes book title, chapter ordinal, and highlights block', () {
      final p = PromptBuilder.review(
        bookTitle: '量子力学讲义',
        chapterOrdinal: 3,
        chapterTitle: '态叠加原理',
        truncatedChapterText: '本章正文…',
        highlightsBlock: '> 高亮1\n> 高亮2',
      );
      expect(p, contains('《量子力学讲义》'));
      expect(p, contains('第3章'));
      expect(p, contains('态叠加原理'));
      expect(p, contains('本章正文…'));
      expect(p, contains('> 高亮1'));
      expect(p, contains('"summary"'));
      expect(p, contains('"keyTakeaways"'));
    });

    test('uses fallback hint when highlightsBlock is empty', () {
      final p = PromptBuilder.review(
        bookTitle: 'T',
        chapterOrdinal: 1,
        chapterTitle: null,
        truncatedChapterText: 'text',
        highlightsBlock: '',
      );
      expect(p, contains('（读者未做高亮'));
      expect(p, contains('第1章'));
      // No "· " when chapterTitle is null.
      expect(p, isNot(contains('· ')));
    });
  });

  test('promptVersion is 2 (bumped from 1 for review mode)', () {
    expect(PromptBuilder.promptVersion, 2);
  });
}
```

- [ ] **Step 2: 跑测试确认 FAIL**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/services/ai/prompt_builder_test.dart`

Expected: FAIL（`PromptBuilder.review` 不存在）

- [ ] **Step 3: 修改 PromptBuilder**

打开 `app/lib/services/ai/prompt_builder.dart`，把 `promptVersion` 改为 2，并在类中追加 `review` 静态方法：

```dart
// 把这行
static const int promptVersion = 1;
// 改成
static const int promptVersion = 2;
```

然后在 `selection` 方法后追加：

```dart
  /// Prompt for chapter learning review. Asks LLM to produce a JSON object
  /// with summary + keyTakeaways, grounded in chapter text and reader's
  /// highlights.
  ///
  /// [chapterOrdinal] is 1-based. [highlightsBlock] is the pre-formatted
  /// multi-line string of reader's highlights in this chapter; pass '' to
  /// trigger the no-highlights fallback branch.
  static String review({
    required String bookTitle,
    required int chapterOrdinal,
    required String? chapterTitle,
    required String truncatedChapterText,
    required String highlightsBlock,
  }) {
    final titleLine = chapterTitle == null || chapterTitle.isEmpty
        ? '第$chapterOrdinal章'
        : '第$chapterOrdinal章 · $chapterTitle';
    final highlightsSection = highlightsBlock.isEmpty
        ? '（读者未做高亮，请基于本章正文做通用回顾）'
        : highlightsBlock;
    return '你是一位学习导师，帮读者回顾刚读完的章节。\n\n'
        '## 本章信息\n'
        '书名：《$bookTitle》\n'
        '章节：$titleLine\n\n'
        '## 本章正文（节选）\n'
        '$truncatedChapterText\n\n'
        '## 读者在本章的高亮与笔记\n'
        '$highlightsSection\n\n'
        '## 任务\n'
        '1. 写一段 100-200 字的本章核心摘要，聚焦读者通过高亮关注的部分\n'
        '2. 提炼 3-5 条可执行/可记忆的要点，每条一句话\n\n'
        '## 输出格式（严格遵守，输出纯 JSON，不要 Markdown 围栏）\n'
        '{\n'
        '  "summary": "...",\n'
        '  "keyTakeaways": ["...", "..."]\n'
        '}';
  }
```

- [ ] **Step 4: 跑测试确认 PASS**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/services/ai/prompt_builder_test.dart`

Expected: PASS

- [ ] **Step 5: 跑全量测试确认 promptVersion bump 无回归**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1`

Expected: 全部通过。**注意**：promptVersion bump 1→2 不会让现有 ai_summaries 缓存失效，因为现有缓存的 `mode` 是 'full'/'chapter'/'selection'，不会被 review mode 查询命中。但如果担心，可以查 grep 是否有硬编码 promptVersion=1 的测试。

- [ ] **Step 6: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add app/lib/services/ai/prompt_builder.dart app/test/services/ai/prompt_builder_test.dart
```

```bash
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m2.1/t3): PromptBuilder.review + bump promptVersion 1->2

New review() prompt template: ch-text + highlights -> JSON output.
promptVersion bump signals cache-key change for any future prompt edits.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: NotesRepository.applyChapterReview（幂等保存）

**Files:**
- Modify: `app/lib/data/repositories/notes_repository.dart`
- Modify: `app/lib/data/repositories/local_notes_repository.dart`
- Test: `app/test/data/repositories/local_notes_repository_test.dart`（已有，追加用例）

- [ ] **Step 1: 追加 RED 测试**

打开 `app/test/data/repositories/local_notes_repository_test.dart`（若不存在则参考 `app/test/data/repositories/` 下其他 repo 测试结构创建），追加：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book_note.dart';
// 其他必要 imports 视 test 文件现有 setup 而定

void main() {
  group('NotesRepository.applyChapterReview', () {
    // 假设已有 helper: Future<LocalBookRepository> setupRepo();

    test('creates note if not exist, then writes summary + takeaways', () async {
      final repo = await setupRepo(bookId: 'b1', bookTitle: '书 A');
      await repo.applyChapterReview(
        bookId: 'b1',
        bookTitle: '书 A',
        chapterIndex: 2,
        chapterTitle: '三章',
        summary: '本章讲了 XYZ',
        keyTakeaways: ['要点1', '要点2'],
      );
      final note = await repo.getNoteByBook('b1');
      expect(note, isNotNull);
      expect(note!.summary, contains('本章讲了 XYZ'));
      expect(note.summary, contains('第 3 章'));
      expect(note.keyTakeaways, [
        '【第3章】 要点1',
        '【第3章】 要点2',
      ]);
    });

    test('re-reviewing same chapter replaces old bullets, no duplication',
        () async {
      final repo = await setupRepo(bookId: 'b1', bookTitle: '书 A');
      await repo.applyChapterReview(
        bookId: 'b1',
        bookTitle: '书 A',
        chapterIndex: 2,
        chapterTitle: '三章',
        summary: '旧摘要',
        keyTakeaways: ['旧要点'],
      );
      await repo.applyChapterReview(
        bookId: 'b1',
        bookTitle: '书 A',
        chapterIndex: 2,
        chapterTitle: '三章',
        summary: '新摘要',
        keyTakeaways: ['新要点1', '新要点2'],
      );
      final note = await repo.getNoteByBook('b1');
      expect(note!.keyTakeaways, ['【第3章】 新要点1', '【第3章】 新要点2']);
      expect(note.summary, isNot(contains('旧摘要')));
      expect(note.summary, contains('新摘要'));
    });

    test('different chapters accumulate independently', () async {
      final repo = await setupRepo(bookId: 'b1', bookTitle: '书 A');
      await repo.applyChapterReview(
        bookId: 'b1', bookTitle: 'A', chapterIndex: 0, chapterTitle: '一',
        summary: 's1', keyTakeaways: ['a']);
      await repo.applyChapterReview(
        bookId: 'b1', bookTitle: 'A', chapterIndex: 1, chapterTitle: '二',
        summary: 's2', keyTakeaways: ['b']);
      final note = await repo.getNoteByBook('b1');
      expect(note!.keyTakeaways, ['【第1章】 a', '【第2章】 b']);
      expect(note.summary, contains('s1'));
      expect(note.summary, contains('s2'));
    });

    test('chapterTitle null produces prefix without "·"', () async {
      final repo = await setupRepo(bookId: 'b1', bookTitle: 'A');
      await repo.applyChapterReview(
        bookId: 'b1', bookTitle: 'A', chapterIndex: 4,
        chapterTitle: null, summary: 's', keyTakeaways: ['x']);
      final note = await repo.getNoteByBook('b1');
      expect(note!.summary, contains('第 5 章\n'));
      expect(note.summary, isNot(contains('· ')));
    });

    test('preserves user-added non-prefixed takeaways', () async {
      final repo = await setupRepo(bookId: 'b1', bookTitle: 'A');
      // 用户先手动加了一条不带前缀的 takeaway
      final empty = await repo.createEmptyNote(
          id: 'n1', bookId: 'b1', bookTitle: 'A');
      await repo.updateNote(empty.copyWith(
        keyTakeaways: ['我的手动要点'],
      ));
      // 然后回顾第 2 章
      await repo.applyChapterReview(
        bookId: 'b1', bookTitle: 'A', chapterIndex: 1,
        chapterTitle: '二', summary: 's', keyTakeaways: ['AI 要点']);
      final note = await repo.getNoteByBook('b1');
      expect(note!.keyTakeaways, ['我的手动要点', '【第2章】 AI 要点']);
    });
  });
}
```

**注意**：`setupRepo` helper 的实现要看现有 test 文件结构。如果不存在，参考同目录 `book_repository_test.dart` 的内存数据库 setup 模式（通常是 `NativeDatabase.memory()` + DAOs 直接构造）。

- [ ] **Step 2: 跑测试确认 FAIL**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/data/repositories/local_notes_repository_test.dart`

Expected: FAIL（`applyChapterReview` 方法不存在）

- [ ] **Step 3: 修改抽象接口**

打开 `app/lib/data/repositories/notes_repository.dart`，在 `searchAnnotations` 方法后追加：

```dart
  /// 用 AI 生成的回顾结果替换该章节的旧回顾内容。
  ///
  /// 幂等性：keyTakeaways 中 【第N章】 前缀的旧条目先删后加；
  ///        summary 中 ## 第 N 章 段落先删后加。
  ///        用户手动添加的不带前缀的内容保留。
  /// BookNote 不存在则先 createEmptyNote。
  Future<void> applyChapterReview({
    required String bookId,
    required String bookTitle,
    required int chapterIndex,
    required String? chapterTitle,
    required String summary,
    required List<String> keyTakeaways,
  });
```

- [ ] **Step 4: 实现 LocalNotesRepository**

打开 `app/lib/data/repositories/local_notes_repository.dart`，在文件末尾（私有 helpers 之前）追加：

```dart
  @override
  Future<void> applyChapterReview({
    required String bookId,
    required String bookTitle,
    required int chapterIndex,
    required String? chapterTitle,
    required String summary,
    required List<String> keyTakeaways,
  }) async {
    var note = await getNoteByBook(bookId);
    if (note == null) {
      note = await createEmptyNote(
        id: 'note_$bookId',
        bookId: bookId,
        bookTitle: bookTitle,
      );
    }

    final ordinal = chapterIndex + 1;
    final prefix = '【第$ordinal章】 ';
    final sentinelStart = '## 第 $ordinal 章';
    final sentinelTitle = (chapterTitle == null || chapterTitle.isEmpty)
        ? sentinelStart
        : '$sentinelStart · $chapterTitle';

    // --- keyTakeaways: 删旧加新 ---
    final existingTakeaways =
        note.keyTakeaways.where((t) => !t.startsWith(prefix)).toList();
    final newTakeaways = keyTakeaways.map((t) => '$prefix$t').toList();
    final mergedTakeaways = [...existingTakeaways, ...newTakeaways];

    // --- summary: 删旧加新 ---
    final cleanedSummary = _stripChapterSection(note.summary, sentinelStart);
    final newSection = StringBuffer()
      ..writeln(sentinelTitle)
      ..writeln()
      ..writeln(summary)
      ..writeln();
    final mergedSummary = cleanedSummary.isEmpty
        ? newSection.toString()
        : '${cleanedSummary.trimRight()}\n\n$newSection';

    await updateNote(note.copyWith(
      summary: mergedSummary,
      keyTakeaways: mergedTakeaways,
      updatedAt: DateTime.now(),
    ));
  }

  /// 删除 summary 中从 `## 第 N 章` 行起到下一个 `## ` 或字符串末尾的段落。
  String _stripChapterSection(String summary, String sentinelStart) {
    if (sentinelStart.isEmpty) return summary;
    if (!summary.contains(sentinelStart)) return summary;
    final sections = <String>[];
    final lines = summary.split('\n');
    var skipping = false;
    for (final line in lines) {
      if (line.startsWith('## ')) {
        skipping = line.startsWith(sentinelStart);
        if (!skipping) sections.add(line);
        continue;
      }
      if (!skipping) sections.add(line);
    }
    return sections.join('\n');
  }
```

- [ ] **Step 5: 跑测试确认 PASS**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/data/repositories/local_notes_repository_test.dart`

Expected: PASS（5 个新测试全绿）

- [ ] **Step 6: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add app/lib/data/repositories/notes_repository.dart app/lib/data/repositories/local_notes_repository.dart app/test/data/repositories/local_notes_repository_test.dart
```

```bash
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m2.1/t4): NotesRepository.applyChapterReview idempotent write

Per-chapter prefix convention 【第N章】 on keyTakeaways; ## 第 N 章
sentinel on summary. Re-review replaces old chapter section, preserves
user-added non-prefixed content. No schema migration.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: BookReviewer 服务（独立 stream pipeline）

**Files:**
- Create: `app/lib/services/ai/book_reviewer.dart`
- Test: `app/test/services/ai/book_reviewer_test.dart`

- [ ] **Step 1: 写 RED 测试**

创建 `app/test/services/ai/book_reviewer_test.dart`：

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/ai_summaries_dao.dart';
import 'package:zhiyue/data/local/database.dart' as db;
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/data/repositories/notes_repository.dart';
import 'package:zhiyue/services/ai/api_key_store.dart';
import 'package:zhiyue/services/ai/book_reviewer.dart';
import 'package:zhiyue/services/ai/chapter_text_provider.dart';
import 'package:zhiyue/services/ai/open_ai_compatible_client.dart';

// Helpers 同 book_preprocessor_test.dart 的模式（FakeAiSummariesDao、
// FakeChapterTextProvider、FakeApiKeyStore、FakeNotesRepository、
// FakeOpenAiClient）。具体实现参考已有测试文件。

void main() {
  group('BookReviewer', () {
    test('emits authFailed when no API key', () async {
      final reviewer = BookReviewer(
        chapterTextProviderFor: (_) => FakeChapterTextProvider(text: 'ch text'),
        notesRepository: FakeNotesRepository(notes: {}),
        apiKeys: FakeApiKeyStore(creds: null),
        aiSummariesDao: FakeAiSummariesDao(),
        clientFactory: ({required baseUrl, required apiKey, required model}) =>
            throw StateError('should not be called'),
      );
      final events = await reviewer
          .run(book: _testBook(), chapterIndex: 0)
          .toList();
      expect(events, [isA<ReviewErrorEvent>()]);
      expect((events[0] as ReviewErrorEvent).error, ReviewError.authFailed);
    });

    test('returns cached review without LLM call when cache hits', () async {
      final cachedJson =
          '{"summary":"cached summary","keyTakeaways":["cached point"]}';
      final dao = FakeAiSummariesDao(seed: {
        'b1::review::${_hashFor('ch text', '')}::2': cachedJson,
      });
      var clientCalled = 0;
      final reviewer = BookReviewer(
        chapterTextProviderFor: (_) => FakeChapterTextProvider(text: 'ch text'),
        notesRepository: FakeNotesRepository(notes: {}),
        apiKeys: FakeApiKeyStore(creds: _creds()),
        aiSummariesDao: dao,
        clientFactory: ({required baseUrl, required apiKey, required model}) {
          clientCalled++;
          return FakeOpenAiClient(chunks: const []);
        },
      );
      final events =
          await reviewer.run(book: _testBook(), chapterIndex: 0).toList();
      expect(clientCalled, 0);
      expect(events.last, isA<ReviewCompleteEvent>());
      final complete = events.last as ReviewCompleteEvent;
      expect(complete.summary, 'cached summary');
      expect(complete.keyTakeaways, ['cached point']);
    });

    test('streams chunks then complete on cache miss', () async {
      final fullJson =
          '{"summary":"s","keyTakeaways":["a","b"]}';
      final reviewer = BookReviewer(
        chapterTextProviderFor: (_) => FakeChapterTextProvider(text: 'ch text'),
        notesRepository: FakeNotesRepository(notes: {}),
        apiKeys: FakeApiKeyStore(creds: _creds()),
        aiSummariesDao: FakeAiSummariesDao(),
        clientFactory: ({required baseUrl, required apiKey, required model}) =>
            FakeOpenAiClient(chunks: [fullJson.substring(0, 10), fullJson.substring(10)]),
      );
      final events =
          await reviewer.run(book: _testBook(), chapterIndex: 0).toList();
      // 至少一个 chunk event + 末尾 complete event
      expect(events.whereType<ReviewChunkEvent>().length, greaterThanOrEqualTo(1));
      expect(events.last, isA<ReviewCompleteEvent>());
      final complete = events.last as ReviewCompleteEvent;
      expect(complete.summary, 's');
      expect(complete.keyTakeaways, ['a', 'b']);
    });

    test('emits parseError when LLM output is malformed', () async {
      final reviewer = BookReviewer(
        chapterTextProviderFor: (_) => FakeChapterTextProvider(text: 'ch text'),
        notesRepository: FakeNotesRepository(notes: {}),
        apiKeys: FakeApiKeyStore(creds: _creds()),
        aiSummariesDao: FakeAiSummariesDao(),
        clientFactory: ({required baseUrl, required apiKey, required model}) =>
            FakeOpenAiClient(chunks: const ['抱歉，无法完成']),
      );
      final events =
          await reviewer.run(book: _testBook(), chapterIndex: 0).toList();
      expect(events.last, isA<ReviewErrorEvent>());
      expect((events.last as ReviewErrorEvent).error, ReviewError.parseError);
    });

    test('emits authFailed when client throws AiAuthException', () async {
      final reviewer = BookReviewer(
        chapterTextProviderFor: (_) => FakeChapterTextProvider(text: 'ch text'),
        notesRepository: FakeNotesRepository(notes: {}),
        apiKeys: FakeApiKeyStore(creds: _creds()),
        aiSummariesDao: FakeAiSummariesDao(),
        clientFactory: ({required baseUrl, required apiKey, required model}) =>
            FakeOpenAiClient(streamError: AiAuthException('bad key')),
      );
      final events =
          await reviewer.run(book: _testBook(), chapterIndex: 0).toList();
      expect(events.last, isA<ReviewErrorEvent>());
      expect((events.last as ReviewErrorEvent).error, ReviewError.authFailed);
    });

    test('includes user highlights in sourceHash', () async {
      final dao = FakeAiSummariesDao();
      final notesRepo = FakeNotesRepository(notes: {
        'b1': _noteWithHighlights(['high1']),
      });
      final reviewer = BookReviewer(
        chapterTextProviderFor: (_) => FakeChapterTextProvider(text: 'ch text'),
        notesRepository: notesRepo,
        apiKeys: FakeApiKeyStore(creds: _creds()),
        aiSummariesDao: dao,
        clientFactory: ({required baseUrl, required apiKey, required model}) =>
            FakeOpenAiClient(chunks: [
              jsonEncode({'summary': 's', 'keyTakeaways': ['t']}),
            ]),
      );
      await reviewer.run(book: _testBook(), chapterIndex: 0).toList();
      // 验证写入缓存的 hash 包含 highlights
      expect(dao.inserted.length, 1);
      final inserted = dao.inserted.single;
      expect(inserted.sourceHash, _hashFor('ch text', 'high1'));
    });
  });
}

Book _testBook() => Book(
      id: 'b1',
      title: '测试书',
      author: null,
      format: BookFormat.epub,
      filePath: '/tmp/test.epub',
      fileHash: null,
      fileSizeBytes: 0,
      coverPath: null,
      addedAt: DateTime(2026, 1, 1),
    );

ApiKeyCredentials _creds() => ApiKeyCredentials(
      baseUrl: 'https://api.example.com/v1',
      apiKey: 'sk-test',
      model: 'test-model',
    );

BookNote _noteWithHighlights(List<String> quotes) {
  // 构造一个 BookNote 含本章 (chapterIndex=0) 的 annotations。
  // 具体 Annotation 构造参考已有测试模式。
  // 略 — 实施者按现有 _chapterIndexOf=0 的 EpubCfiLocator 模式构造。
  throw UnimplementedError('see existing annotation_test.dart patterns');
}

String _hashFor(String text, String highlight) {
  // 与 BookReviewer._computeSourceHash 一致：sha256(text + '::' + highlightHash)
  throw UnimplementedError('use crypto.sha256 in test');
}
```

**实施者注意**：上面的 `_noteWithHighlights` 和 `_hashFor` 是占位，实际构造方式参考 `app/test/services/ai/book_preprocessor_test.dart` 中已有的 Fake/seed 模式（特别是 Annotation + EpubCfiLocator + sha256 的构造方式）。本计划的 RED 测试必须能编译并失败，所以你需要先把这些 helper 实现完整。

- [ ] **Step 2: 跑测试确认 FAIL**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/services/ai/book_reviewer_test.dart`

Expected: FAIL（"BookReviewer class not found"）

- [ ] **Step 3: 写实现**

创建 `app/lib/services/ai/book_reviewer.dart`：

```dart
import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../data/local/daos/ai_summaries_dao.dart';
import '../../data/models/annotation.dart';
import '../../data/models/book.dart';
import '../../data/models/book_note.dart';
import '../../data/repositories/notes_repository.dart';
import 'api_key_store.dart';
import 'chapter_text_provider.dart';
import 'open_ai_compatible_client.dart';
import 'prompt_builder.dart';
import 'review_output_parser.dart';
import 'token_truncator.dart';

enum ReviewError { authFailed, rateLimited, parseError, serverError }

sealed class ReviewEvent {}

class ReviewChunkEvent extends ReviewEvent {
  ReviewChunkEvent(this.chunk);
  final String chunk;
}

class ReviewCompleteEvent extends ReviewEvent {
  ReviewCompleteEvent({required this.summary, required this.keyTakeaways});
  final String summary;
  final List<String> keyTakeaways;
}

class ReviewErrorEvent extends ReviewEvent {
  ReviewErrorEvent(this.error);
  final ReviewError error;
}

/// Factory signature for [OpenAiCompatibleClient], abstracted so tests can
/// inject a fake without constructing real credentials.
typedef ReviewAiClientFactory = OpenAiCompatibleClient Function({
  required String baseUrl,
  required String apiKey,
  required String model,
});

/// Test-friendly interface so [ReviewController] can be constructed in
/// tests with a fake stream (mirrors BookPreprocessorLike pattern).
abstract class BookReviewerLike {
  Stream<ReviewEvent> run({required Book book, required int chapterIndex});
}

/// Standalone chapter-review service.
///
/// Mirrors AiGuide's pipeline (cache lookup → stream → persist) but with
/// review-specific sourceHash that includes user highlights — AiGuide's
/// hash is text-only and would incorrectly hit cache when highlights change.
class BookReviewer implements BookReviewerLike {
  BookReviewer({
    required this.chapterTextProviderFor,
    required this.notesRepository,
    required this.apiKeys,
    required this.aiSummariesDao,
    required this.clientFactory,
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  final ChapterTextProvider Function(Book) chapterTextProviderFor;
  final NotesRepository notesRepository;
  final ApiKeyStoreLike apiKeys;
  final AiSummariesDao aiSummariesDao;
  final ReviewAiClientFactory clientFactory;
  final http.Client? _httpClient;

  static const String _modeKey = 'review';

  Stream<ReviewEvent> run({
    required Book book,
    required int chapterIndex,
  }) async* {
    final creds = await apiKeys.load();
    if (creds == null) {
      yield ReviewErrorEvent(ReviewError.authFailed);
      return;
    }

    final provider = chapterTextProviderFor(book);
    final rawText = await provider.get(book.filePath, chapterIndex);
    if (rawText == null || rawText.trim().isEmpty) {
      yield ReviewErrorEvent(ReviewError.parseError);
      return;
    }
    final truncated =
        TokenTruncator.truncateToTokens(rawText, TokenTruncator.defaultBudget);

    final highlights = await _loadChapterHighlights(book.id, chapterIndex);
    final highlightsSignature = _highlightsSignature(highlights);
    final sourceHash = _computeSourceHash(truncated, highlightsSignature);
    final chapterTitle = await provider.title(book.filePath, chapterIndex);

    // Cache lookup
    final cached = await aiSummariesDao.find(
      bookId: book.id,
      mode: _modeKey,
      sourceHash: sourceHash,
      promptVersion: PromptBuilder.promptVersion,
    );
    if (cached != null) {
      final parsed = ReviewOutputParser.parse(cached.summaryText);
      if (parsed != null) {
        yield ReviewCompleteEvent(
          summary: parsed.summary,
          keyTakeaways: parsed.keyTakeaways,
        );
        return;
      }
      // Cached but unparseable: fall through and re-call LLM.
    }

    // Build prompt
    final prompt = PromptBuilder.review(
      bookTitle: book.title,
      chapterOrdinal: chapterIndex + 1,
      chapterTitle: chapterTitle,
      truncatedChapterText: truncated,
      highlightsBlock: _formatHighlights(highlights),
    );

    final client = clientFactory(
      baseUrl: creds.baseUrl,
      apiKey: creds.apiKey,
      model: creds.model,
    );

    final accumulated = StringBuffer();
    try {
      try {
        await for (final chunk in client.streamChat(prompt: prompt)) {
          accumulated.write(chunk);
          yield ReviewChunkEvent(chunk);
        }
      } on AiAuthException {
        yield ReviewErrorEvent(ReviewError.authFailed);
        return;
      } on AiRateLimitException {
        yield ReviewErrorEvent(ReviewError.rateLimited);
        return;
      } on AiServerException {
        yield ReviewErrorEvent(ReviewError.serverError);
        return;
      }

      final parsed = ReviewOutputParser.parse(accumulated.toString());
      if (parsed == null) {
        yield ReviewErrorEvent(ReviewError.parseError);
        return;
      }

      // Persist to cache
      await aiSummariesDao.insert(
        bookId: book.id,
        mode: _modeKey,
        sourceHash: sourceHash,
        summaryText: accumulated.toString(),
        modelName: creds.model,
        baseUrl: creds.baseUrl,
        promptVersion: PromptBuilder.promptVersion,
      );

      yield ReviewCompleteEvent(
        summary: parsed.summary,
        keyTakeaways: parsed.keyTakeaways,
      );
    } finally {
      client.close();
    }
  }

  Future<List<Annotation>> _loadChapterHighlights(
      String bookId, int chapterIndex) async {
    final note = await notesRepository.getNoteByBook(bookId);
    if (note == null) return const [];
    return note.annotations.where((a) {
      final loc = a.locator;
      if (loc is EpubRangeLocator) return loc.chapterIndex == chapterIndex;
      if (loc is EpubCfiLocator) return loc.chapterIndex == chapterIndex;
      if (loc is PdfRangeLocator) return loc.page == chapterIndex;
      return false;
    }).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  static String _formatHighlights(List<Annotation> highlights) {
    if (highlights.isEmpty) return '';
    final buf = StringBuffer();
    for (final h in highlights) {
      buf.writeln('> ${h.quote}');
      if (h.hasNote) {
        buf.writeln('  💬 ${h.note}');
      }
    }
    return buf.toString().trimRight();
  }

  static String _highlightsSignature(List<Annotation> highlights) {
    if (highlights.isEmpty) return '';
    final joined = highlights.map((h) => h.quote).join('\n');
    return sha256.convert(utf8.encode(joined)).toString();
  }

  static String _computeSourceHash(
      String truncatedText, String highlightsSignature) {
    return sha256
        .convert(utf8.encode('$truncatedText::$highlightsSignature'))
        .toString();
  }
}
```

**实施者注意**：上面 `_loadChapterHighlights` 中的 `EpubRangeLocator` / `EpubCfiLocator` / `PdfRangeLocator` 是 `core/locator.dart` 中的已有类型，导入路径需要查项目实际位置（grep `class EpubCfiLocator`）。

- [ ] **Step 4: 跑测试确认 PASS**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/services/ai/book_reviewer_test.dart`

Expected: PASS（6 个测试全绿）

- [ ] **Step 5: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add app/lib/services/ai/book_reviewer.dart app/test/services/ai/book_reviewer_test.dart
```

```bash
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m2.1/t5): BookReviewer standalone stream service

Cache lookup -> stream -> persist pipeline mirroring AiGuide, but with
review-specific sourceHash that includes user highlights (so adding a
highlight triggers re-review). Reuses OpenAiCompatibleClient directly.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: ReviewController + provider

**Files:**
- Create: `app/lib/features/ai/providers/review_controller.dart`
- Test: `app/test/features/ai/providers/review_controller_test.dart`

- [ ] **Step 1: 写 RED 测试**

创建 `app/test/features/ai/providers/review_controller_test.dart`：

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/ai/providers/review_controller.dart';
import 'package:zhiyue/services/ai/book_reviewer.dart';
import 'package:zhiyue/data/models/book.dart';

class _FakeReviewer implements BookReviewerLike {
  _FakeReviewer(this._events);
  final List<ReviewEvent> _events;
  int startCalls = 0;

  @override
  Stream<ReviewEvent> run({required Book book, required int chapterIndex}) async* {
    startCalls++;
    for (final e in _events) {
      yield e;
    }
  }
}

void main() {
  group('ReviewController', () {
    test('initial state is idle', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final state = container.read(reviewControllerProvider('b1'));
      expect(state.status, ReviewStatus.idle);
    });

    test('start transitions idle -> loading -> streaming -> done', () async {
      final reviewer = _FakeReviewer([
        ReviewChunkEvent('part 1'),
        ReviewChunkEvent('part 2'),
        ReviewCompleteEvent(summary: 's', keyTakeaways: ['a', 'b']),
      ]);
      final container = ProviderContainer(overrides: [
        reviewControllerProvider('b1').overrideWith((ref) {
          return ReviewController.forTest(reviewer);
        }),
      ]);
      addTearDown(container.dispose);
      final listener = container.listen(
          reviewControllerProvider('b1'), (_, __) {});
      // ignore: unused_local_variable
      final sub = container.listen(reviewControllerProvider('b1'), (before, after) {}, fireImmediately: true);

      container.read(reviewControllerProvider('b1').notifier).start(
            book: _testBook(),
            chapterIndex: 0,
          );
      // loading 立刻
      expect(container.read(reviewControllerProvider('b1')).status,
          ReviewStatus.loading);
      // 等流结束
      await Future.delayed(Duration.zero);
      expect(reviewer.startCalls, 1);
      final finalState = container.read(reviewControllerProvider('b1'));
      expect(finalState.status, ReviewStatus.done);
      expect(finalState.summary, 's');
      expect(finalState.keyTakeaways, ['a', 'b']);
      expect(finalState.rawText, 'part 1part 2');
    });

    test('error event transitions to error state', () async {
      final reviewer = _FakeReviewer([
        ReviewErrorEvent(ReviewError.authFailed),
      ]);
      final container = ProviderContainer(overrides: [
        reviewControllerProvider('b1').overrideWith((ref) =>
            ReviewController.forTest(reviewer)),
      ]);
      addTearDown(container.dispose);
      container.read(reviewControllerProvider('b1').notifier).start(
            book: _testBook(),
            chapterIndex: 0,
          );
      await Future.delayed(Duration.zero);
      final state = container.read(reviewControllerProvider('b1'));
      expect(state.status, ReviewStatus.error);
      expect(state.error, ReviewError.authFailed);
    });

    test('reset returns to idle', () async {
      final reviewer = _FakeReviewer([
        ReviewCompleteEvent(summary: 's', keyTakeaways: []),
      ]);
      final container = ProviderContainer(overrides: [
        reviewControllerProvider('b1').overrideWith((ref) =>
            ReviewController.forTest(reviewer)),
      ]);
      addTearDown(container.dispose);
      container.read(reviewControllerProvider('b1').notifier).start(
            book: _testBook(),
            chapterIndex: 0,
          );
      await Future.delayed(Duration.zero);
      container.read(reviewControllerProvider('b1').notifier).reset();
      expect(container.read(reviewControllerProvider('b1')).status,
          ReviewStatus.idle);
    });
  });
}

Book _testBook() => Book(
      id: 'b1', title: 't', author: null, format: BookFormat.epub,
      filePath: '/t.epub', fileHash: null, fileSizeBytes: 0,
      coverPath: null, addedAt: DateTime(2026, 1, 1),
    );

// 注：测试通过 ReviewController.forTest(reviewer) 构造，无需自定义子类。
```

- [ ] **Step 2: 跑测试确认 FAIL**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/ai/providers/review_controller_test.dart`

Expected: FAIL（`ReviewController` 不存在）

- [ ] **Step 3: 写实现**

创建 `app/lib/features/ai/providers/review_controller.dart`：

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/book.dart';
import '../../../services/ai/book_reviewer.dart';

enum ReviewStatus { idle, loading, streaming, done, error }

class ReviewState {
  const ReviewState({
    this.status = ReviewStatus.idle,
    this.rawText = '',
    this.summary,
    this.keyTakeaways = const [],
    this.error,
  });

  final ReviewStatus status;
  final String rawText;
  final String? summary;
  final List<String> keyTakeaways;
  final ReviewError? error;

  ReviewState copyWith({
    ReviewStatus? status,
    String? rawText,
    String? summary,
    List<String>? keyTakeaways,
    ReviewError? error,
    bool clearError = false,
  }) {
    return ReviewState(
      status: status ?? this.status,
      rawText: rawText ?? this.rawText,
      summary: summary ?? this.summary,
      keyTakeaways: keyTakeaways ?? this.keyTakeaways,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ReviewController extends StateNotifier<ReviewState> {
  ReviewController(this._reviewer) : super(const ReviewState());

  /// Test-only constructor that takes a [BookReviewerLike] directly (e.g.,
  /// a fake). Production uses the default constructor with a concrete
  /// [BookReviewer] wired via provider override.
  @visibleForTesting
  ReviewController.forTest(BookReviewerLike reviewer) : this._(reviewer);

  ReviewController._(this._reviewer) : super(const ReviewState());

  final BookReviewerLike _reviewer;
  StreamSubscription<ReviewEvent>? _sub;

  // ---- @visibleForTesting helpers (used by ReviewPreviewSheet widget tests) ----

  @visibleForTesting
  void startLoadingForTest() {
    state = const ReviewState(status: ReviewStatus.loading);
  }

  @visibleForTesting
  void setDoneForTest(
      {required String summary, required List<String> keyTakeaways}) {
    state = ReviewState(
      status: ReviewStatus.done,
      summary: summary,
      keyTakeaways: keyTakeaways,
    );
  }

  @visibleForTesting
  void setErrorForTest(ReviewError error) {
    state = ReviewState(status: ReviewStatus.error, error: error);
  }

  void start({required Book book, required int chapterIndex}) {
    _sub?.cancel();
    state = const ReviewState(status: ReviewStatus.loading);
    _sub = _reviewer.run(book: book, chapterIndex: chapterIndex).listen(
      _onEvent,
      onError: (Object e) {
        state = state.copyWith(
          status: ReviewStatus.error,
          error: ReviewError.serverError,
        );
      },
      onDone: () {
        // Auto-promote to done only if no events observed.
        if (state.status == ReviewStatus.loading) {
          state = state.copyWith(status: ReviewStatus.done);
        }
      },
      cancelOnError: true,
    );
  }

  void reset() {
    _sub?.cancel();
    _sub = null;
    state = const ReviewState();
  }

  void _onEvent(ReviewEvent event) {
    switch (event) {
      case ReviewChunkEvent(:final chunk):
        state = state.copyWith(
          status: ReviewStatus.streaming,
          rawText: state.rawText + chunk,
        );
      case ReviewCompleteEvent(:final summary, :final keyTakeaways):
        state = state.copyWith(
          status: ReviewStatus.done,
          summary: summary,
          keyTakeaways: keyTakeaways,
          clearError: true,
        );
      case ReviewErrorEvent(:final error):
        state = state.copyWith(status: ReviewStatus.error, error: error);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// autoDispose: controller reclaimed when review sheet closes.
/// family: state keyed by bookId.
///
/// Default is a NoOp that immediately emits serverError, so widget tests
/// that pump ReviewPreviewSheet (which reads this provider) function
/// without each test overriding. Mirrors QaController's NoOp pattern.
final reviewControllerProvider = StateNotifierProvider.autoDispose
    .family<ReviewController, ReviewState, String>((ref, bookId) {
  return ReviewController(_NoOpBookReviewer());
});

class _NoOpBookReviewer implements BookReviewerLike {
  @override
  Stream<ReviewEvent> run({required Book book, required int chapterIndex}) async* {
    yield ReviewErrorEvent(ReviewError.serverError);
  }
}
```

**注意**：T5 已经在 `book_reviewer.dart` 中定义了 `abstract class BookReviewerLike` 并让 `BookReviewer implements BookReviewerLike`。本任务直接 import 使用，无需在 controller 一侧重新定义。

`ReviewControllerForTest`（用于 widget test 注入 fake reviewer）通过 review_controller.dart 暴露的 `@visibleForTesting` 构造 `ReviewController._forTest` 实现。本任务的测试需要这个构造；在 `ReviewController` 类中追加：

```dart
@visibleForTesting
ReviewController.forTest(BookReviewerLike reviewer) : this._(reviewer);

ReviewController._(this._reviewer) : super(const ReviewState());
```

（如果 T5 没有提供该 test 构造，在 T6 这一步追加；和 T7 widget test 的 `setDoneForTest` 等 helper 一起放在同一个 commit 里也可以。）

- [ ] **Step 4: 跑测试确认 PASS**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/ai/providers/review_controller_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add app/lib/features/ai/providers/review_controller.dart app/lib/services/ai/book_reviewer.dart app/test/features/ai/providers/review_controller_test.dart
```

```bash
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m2.1/t6): ReviewController + provider

StateNotifier mirroring QaController: idle/loading/streaming/done/error.
autoDispose.family by bookId; NoOp default for widget tests.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: ReviewPreviewSheet widget

**Files:**
- Create: `app/lib/features/ai/widgets/review_preview_sheet.dart`
- Test: `app/test/features/ai/widgets/review_preview_sheet_test.dart`

- [ ] **Step 1: 写 RED 测试**

创建 `app/test/features/ai/widgets/review_preview_sheet_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/ai/providers/review_controller.dart';
import 'package:zhiyue/features/ai/widgets/review_preview_sheet.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

void main() {
  testWidgets('renders loading view when state is loading', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(reviewControllerProvider('b1').notifier);
    // Force loading state
    container.read(reviewControllerProvider('b1').notifier).startLoadingForTest();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReviewPreviewSheet(bookId: 'b1', chapterIndex: 0, chapterTitle: 'X'),
        ),
      ),
    ));
    await tester.pump();
    // LoadingView 默认显示 loadingDefaultMessage
    expect(find.textContaining('AI'), findsWidgets);
  });

  testWidgets('renders summary + takeaways when state is done', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(reviewControllerProvider('b1').notifier).setDoneForTest(
          summary: '本章核心摘要',
          keyTakeaways: ['要点1', '要点2'],
        );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReviewPreviewSheet(bookId: 'b1', chapterIndex: 0, chapterTitle: 'X'),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('本章核心摘要'), findsOneWidget);
    expect(find.text('要点1'), findsOneWidget);
    expect(find.text('要点2'), findsOneWidget);
    expect(find.text('保存到读书笔记'), findsOneWidget);
  });

  testWidgets('save button calls onSaved callback', (tester) async {
    var saved = false;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(reviewControllerProvider('b1').notifier).setDoneForTest(
          summary: 's', keyTakeaways: ['t']);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReviewPreviewSheet(
            bookId: 'b1', chapterIndex: 0, chapterTitle: 'X',
            onSaved: () => saved = true,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('保存到读书笔记'));
    await tester.pump();
    expect(saved, isTrue);
  });

  testWidgets('renders error view with retry when state is error', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(reviewControllerProvider('b1').notifier).setErrorForTest(
          ReviewError.authFailed);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReviewPreviewSheet(bookId: 'b1', chapterIndex: 0, chapterTitle: 'X'),
        ),
      ),
    ));
    await tester.pump();
    expect(find.textContaining('API 密钥'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 跑测试确认 FAIL**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/ai/widgets/review_preview_sheet_test.dart`

Expected: FAIL（`ReviewPreviewSheet` 不存在）

- [ ] **Step 3: 写实现**

创建 `app/lib/features/ai/widgets/review_preview_sheet.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../notes/widgets/annotation_context_sheet.dart' show _NoOp;  // 仅占位，实际不需要
import '../providers/review_controller.dart';

/// Modal bottom sheet that previews an AI-generated chapter review.
///
/// State is read from [reviewControllerProvider]. The caller is responsible
/// for invoking `controller.start(...)` before showing this sheet.
///
/// [onSaved] is invoked after the user taps "save" — the caller does the
/// actual persistence (calling `applyChapterReview` on the notes repo).
class ReviewPreviewSheet extends ConsumerWidget {
  const ReviewPreviewSheet({
    super.key,
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    this.onSaved,
  });

  final String bookId;
  final int chapterIndex;
  final String? chapterTitle;
  final VoidCallback? onSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(reviewControllerProvider(bookId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reviewSheetTitle(chapterIndex + 1,
            chapterTitle ?? l10n.reviewEmptyHighlightsHint)),
      ),
      body: _body(context, ref, l10n, state),
      bottomNavigationBar: _bottomBar(context, ref, l10n, state),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, AppLocalizations l10n,
      ReviewState state) {
    switch (state.status) {
      case ReviewStatus.idle:
      case ReviewStatus.loading:
        return LoadingView(message: l10n.reviewStatusLoading);
      case ReviewStatus.streaming:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.reviewStatusStreaming,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Text(state.rawText),
          ],
        );
      case ReviewStatus.done:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.reviewSummarySection,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(state.summary ?? ''),
            const SizedBox(height: 24),
            Text(l10n.reviewTakeawaysSection,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final t in state.keyTakeaways) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('• '),
                Expanded(child: Text(t)),
              ]),
              const SizedBox(height: 4),
            ],
          ],
        );
      case ReviewStatus.error:
        final msg = _errorMessage(l10n, state.error);
        return ErrorView(
          message: msg,
          onRetry: () => ref
              .read(reviewControllerProvider(bookId).notifier)
              .reset(),
        );
    }
  }

  Widget _bottomBar(BuildContext context, WidgetRef ref, AppLocalizations l10n,
      ReviewState state) {
    if (state.status == ReviewStatus.error) {
      return SafeArea(
        child: ButtonBar(
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l10n.reviewCancelButton),
            ),
            FilledButton(
              onPressed: () => ref
                  .read(reviewControllerProvider(bookId).notifier)
                  .reset(),
              child: Text(l10n.reviewRetryButton),
            ),
          ],
        ),
      );
    }
    final canSave = state.status == ReviewStatus.done;
    return SafeArea(
      child: ButtonBar(
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l10n.reviewCancelButton),
          ),
          FilledButton(
            onPressed: canSave
                ? () {
                    onSaved?.call();
                    Navigator.of(context).maybePop();
                  }
                : null,
            child: Text(l10n.reviewSaveButton),
          ),
        ],
      ),
    );
  }

  String _errorMessage(AppLocalizations l10n, ReviewError? error) {
    switch (error) {
      case ReviewError.authFailed:
        return l10n.reviewErrorAuthFailed;
      case ReviewError.parseError:
        return l10n.reviewErrorParseFailed;
      case ReviewError.serverError:
      case ReviewError.rateLimited:
      case null:
        return l10n.reviewErrorServer;
    }
  }
}
```

**测试辅助方法**：要让测试 `setDoneForTest` / `setErrorForTest` / `startLoadingForTest` 工作，在 `ReviewController` 中加 test-only helpers（用 `@visibleForTesting` 标注）：

```dart
// 在 ReviewController 类中追加：
@visibleForTesting
void startLoadingForTest() {
  state = const ReviewState(status: ReviewStatus.loading);
}

@visibleForTesting
void setDoneForTest({required String summary, required List<String> keyTakeaways}) {
  state = ReviewState(
    status: ReviewStatus.done,
    summary: summary,
    keyTakeaways: keyTakeaways,
  );
}

@visibleForTesting
void setErrorForTest(ReviewError error) {
  state = ReviewState(status: ReviewStatus.error, error: error);
}
```

加 `import 'package:flutter/foundation.dart';` 以用 `@visibleForTesting`。

**删除 import 占位**：上面 `import '../../notes/widgets/annotation_context_sheet.dart' show _NoOp;` 是占位提示，实际不需要；删除该行。

- [ ] **Step 4: 跑测试确认 PASS**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/ai/widgets/review_preview_sheet_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add app/lib/features/ai/widgets/review_preview_sheet.dart app/lib/features/ai/providers/review_controller.dart app/test/features/ai/widgets/review_preview_sheet_test.dart
```

```bash
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m2.1/t7): ReviewPreviewSheet modal widget

Bottom sheet that streams AI output, shows parsed summary + takeaways
on done, error view with retry on failure. @visibleForTesting helpers
on ReviewController enable widget tests without real LLM.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: TOC 抽屉接入回顾按钮

**Files:**
- Modify: `app/lib/features/reader/widgets/toc_drawer.dart`
- Test: `app/test/features/reader/widgets/toc_drawer_review_button_test.dart`（新建）

- [ ] **Step 1: 写 RED 测试**

创建 `app/test/features/reader/widgets/toc_drawer_review_button_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/navigation/toc.dart';
import 'package:zhiyue/features/ai/providers/book_preprocess_controller.dart';
import 'package:zhiyue/features/reader/widgets/toc_drawer.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

TocEntry _entry(int i, String title) => TocEntry(
      title: title,
      locator: EpubCfiLocator(cfi: '/${i + 6}', chapterIndex: i),
      children: const [],
    );

void main() {
  testWidgets('renders review icon button per chapter when preprocessed',
      (tester) async {
    const state = PreprocessState(
      status: PreprocessStatus.done,
      currentChapter: 3,
      totalChapters: 3,
      summarizedChapters: <int>{0, 1, 2},
    );
    var tappedChapter = -1;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TocDrawer(
          toc: TableOfContents(entries: [_entry(0, 'Ch0'), _entry(1, 'Ch1')]),
          onSelect: (_) {},
          preprocessState: state,
          chapterIndexResolver: defaultTocChapterIndex,
          onReviewChapter: (idx) => tappedChapter = idx,
        ),
      ),
    ));
    await tester.pump();
    // 两个 review icon buttons (rate_review_outlined)
    expect(find.byIcon(Icons.rate_review_outlined), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.rate_review_outlined).first);
    await tester.pump();
    expect(tappedChapter, 0);
  });

  testWidgets('disables review button for unsummarized chapters',
      (tester) async {
    const state = PreprocessState(
      status: PreprocessStatus.done,
      currentChapter: 2,
      totalChapters: 2,
      summarizedChapters: <int>{0},  // 只有 ch0 完成
    );
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TocDrawer(
          toc: TableOfContents(entries: [_entry(0, 'Ch0'), _entry(1, 'Ch1')]),
          onSelect: (_) {},
          preprocessState: state,
          chapterIndexResolver: defaultTocChapterIndex,
        ),
      ),
    ));
    await tester.pump();
    final buttons = find.byType(IconButton);
    // ch0 button enabled, ch1 button disabled
    final IconButton ch1Button = tester.widget<IconButton>(
      find.descendant(of: find.text('Ch1'), matching: buttons).first,
    );
    expect(ch1Button.onPressed, isNull);
  });
}
```

- [ ] **Step 2: 跑测试确认 FAIL**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/reader/widgets/toc_drawer_review_button_test.dart`

Expected: FAIL（`onReviewChapter` 参数不存在 / 找不到 review icon）

- [ ] **Step 3: 修改 toc_drawer.dart**

打开 `app/lib/features/reader/widgets/toc_drawer.dart`，在 `TocDrawer` 构造函数加 `onReviewChapter` 参数（可空 `ValueChanged<int>?`），在每行 trailing 区加 `IconButton`：

```dart
// 在 TocDrawer 字段中追加：
final ValueChanged<int>? onReviewChapter;

// 在构造函数参数中追加（注意默认 null）：
this.onReviewChapter,

// 在每行 ListTile 后（或 actions slot 中）追加：
if (onReviewChapter != null)
  IconButton(
    icon: const Icon(Icons.rate_review_outlined, size: 20),
    tooltip: l10n.reviewButtonLabel,
    onPressed: isChapterPreprocessed
        ? () => onReviewChapter!(chapterIndex)
        : null,
  )
```

**实施者注意**：`isChapterPreprocessed` 来自 `preprocessState.summarizedChapters.contains(chapterIndex)`；具体如何取 `chapterIndex` 要看现有 TocDrawer 的渲染逻辑。在每行 build 时计算一次。

由于 TocDrawer 现有结构未知（grep `class TocDrawer` 看源码），实施者需要：
1. 读取 `app/lib/features/reader/widgets/toc_drawer.dart` 全文
2. 找到每行 TocEntry 的渲染处（通常是 `ListView.builder` + `ListTile` 或自定义 widget）
3. 在 trailing 区域加 IconButton，逻辑如上
4. 加 `import '../../../gen_l10n/app_localizations.dart';` 如果文件还没引

- [ ] **Step 4: 跑测试确认 PASS**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/reader/widgets/toc_drawer_review_button_test.dart`

Expected: PASS

- [ ] **Step 5: 跑已有 toc_drawer 测试确认无回归**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/reader/widgets/toc_drawer_progressive_test.dart`

Expected: PASS（M1.6 T6 既有的 4 个测试）

- [ ] **Step 6: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add app/lib/features/reader/widgets/toc_drawer.dart app/test/features/reader/widgets/toc_drawer_review_button_test.dart
```

```bash
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m2.1/t8): TOC drawer per-chapter review button

Adds rate_review icon per TOC entry. Disabled for unsummarized chapters.
onReviewChapter callback invoked with chapterIndex when tapped.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: 阅读器顶栏溢出菜单接入

**Files:**
- Modify: `app/lib/features/reader/pages/reader_body.dart`
- Test: `app/test/features/reader/pages/reader_body_review_menu_test.dart`（新建）

- [ ] **Step 1: 写 RED 测试**

创建 `app/test/features/reader/pages/reader_body_review_menu_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

// 实施者需要参考 reader_body_test.dart 已有的 widget pump 模式
// （通常需要 mock ReaderEngine、BookProvider、Navigation 等）

void main() {
  testWidgets('reader overflow menu contains "review this chapter" item',
      (tester) async {
    // Setup 同 reader_body 现有测试（mock 必要 provider）
    // ... 略 ...
    await tester.pumpWidget(/* ProviderScope + MaterialApp + ReaderBody */);
    await tester.pump();

    // 打开溢出菜单
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('回顾本章'), findsOneWidget);
  });

  testWidgets('review menu item does not render for PDF books',
      (tester) async {
    // Setup with BookFormat.pdf
    // ... 略 ...
    await tester.pumpWidget(/* ... */);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('回顾本章'), findsNothing);
  });
}
```

**实施者注意**：reader_body 是 M1.6 T8 拆分后的文件，已有较复杂的测试 setup。实施者需要：
1. 读 `app/lib/features/reader/pages/reader_body.dart` 找到现有 PopupMenuButton / AppBar
2. 读 `app/test/features/reader/pages/` 下已有的 reader_body test，复用其 setup helper

- [ ] **Step 2: 跑测试确认 FAIL**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/reader/pages/reader_body_review_menu_test.dart`

Expected: FAIL

- [ ] **Step 3: 修改 reader_body.dart**

打开 `app/lib/features/reader/pages/reader_body.dart`，找到现有 `PopupMenuButton` （通常是顶栏 AppBar 的 actions），追加一个 `PopupMenuItem<String>`：

```dart
// 在现有 PopupMenuButton items 列表中追加：
if (book.format != BookFormat.pdf)
  PopupMenuItem<String>(
    value: 'review_current',
    child: ListTile(
      leading: Icon(Icons.rate_review_outlined),
      title: Text(AppLocalizations.of(context)!.reviewCurrentChapterMenuLabel),
      contentPadding: EdgeInsets.zero,
      dense: true,
    ),
  ),
```

在 `onSelected` 处理中追加分支：

```dart
if (value == 'review_current') {
  _openReview(engine.currentChapterIndex);
}
```

并在 `_ReaderBodyState` 中加 `_openReview` 方法：

```dart
void _openReview(int chapterIndex) {
  final book = _book;  // 现有字段；若没有则 ref.read(bookProvider(...))
  if (book == null || book.format == BookFormat.pdf) return;
  ref.read(reviewControllerProvider(book.id).notifier).start(
        book: book,
        chapterIndex: chapterIndex,
      );
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => ReviewPreviewSheet(
      bookId: book.id,
      chapterIndex: chapterIndex,
      chapterTitle: null,  // 可选：从 engine 取当前章节标题
      onSaved: () async {
        final state = ref.read(reviewControllerProvider(book.id));
        if (state.summary == null) return;
        await ref.read(notesRepositoryProvider).applyChapterReview(
              bookId: book.id,
              bookTitle: book.title,
              chapterIndex: chapterIndex,
              chapterTitle: null,
              summary: state.summary!,
              keyTakeaways: state.keyTakeaways,
            );
      },
    ),
  );
}
```

加必要 imports：
```dart
import '../../../gen_l10n/app_localizations.dart';
import '../../ai/providers/review_controller.dart';
import '../../ai/widgets/review_preview_sheet.dart';
import '../../../data/repositories/notes_repository.dart';  // 已有 notesRepositoryProvider
```

**实施者注意**：`_book` 字段名和 `engine.currentChapterIndex` 实际名称要看 reader_body.dart 现有源码（M1.6 T8 已有 `_currentChapterIndex()` 方法可复用）。

- [ ] **Step 4: 跑测试确认 PASS**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/reader/pages/reader_body_review_menu_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add app/lib/features/reader/pages/reader_body.dart app/test/features/reader/pages/reader_body_review_menu_test.dart
```

```bash
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m2.1/t9): reader overflow menu "review this chapter"

Adds menu item that opens ReviewPreviewSheet for current chapterIndex.
PDF books skip the item. onSaved persists via applyChapterReview.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: TOC 抽屉 onReviewChapter 接到 reader

**Files:**
- Modify: `app/lib/features/reader/pages/reader_body.dart`（继续 T9 的修改）

这个 task 把 T8 加的 `onReviewChapter` callback 在 reader_body 里接到 `_openReview` 上，让 TOC 抽屉里的回顾按钮真的能触发回顾。

- [ ] **Step 1: 找到 reader_body 中渲染 TocDrawer 的位置**

打开 `app/lib/features/reader/pages/reader_body.dart`，grep `TocDrawer(` 找到调用处。

- [ ] **Step 2: 给 TocDrawer 传入 onReviewChapter**

修改该调用：

```dart
TocDrawer(
  toc: toc,
  onSelect: (locator) => _onTocTap(locator),
  preprocessState: preprocessState,
  chapterIndexResolver: defaultTocChapterIndex,
  onReviewChapter: (idx) => _openReview(idx),  // 新增
)
```

- [ ] **Step 3: 手动验证（无新测试，逻辑很短）**

由于 `_openReview` 在 T9 已被测，这里只是把 TocDrawer 的 callback 接上，没有新逻辑。跑现有 reader 测试确认无回归：

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/reader/`

Expected: PASS

- [ ] **Step 4: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add app/lib/features/reader/pages/reader_body.dart
```

```bash
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m2.1/t10): wire TOC drawer review button to _openReview

Connects T8's onReviewChapter callback to the existing _openReview
method from T9. No new logic.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: app_providers 注入生产 BookReviewer

**Files:**
- Modify: `app/lib/core/app_providers.dart` 或 `app/lib/main.dart`（找到 reviewControllerProvider override 的注入点）

- [ ] **Step 1: 找到现有 provider 集中地**

Run: `grep -rn "bookPreprocessControllerProvider.overrideWith\|qaControllerProvider.overrideWith" app/lib/`

Expected: 找到 `app_providers.dart` 或类似文件中的 override 列表。

- [ ] **Step 2: 加 ReviewController override**

打开找到的文件，在 `qaControllerProvider.overrideWith(...)` 旁边追加：

```dart
// 加必要 imports
import '../services/ai/book_reviewer.dart';
import '../features/ai/providers/review_controller.dart';

// 在 providers override 列表中追加：
reviewControllerProvider.overrideWith((ref) {
  return ReviewController(BookReviewer(
    chapterTextProviderFor: /* 同 BookPreprocessor 用的 provider */,
    notesRepository: ref.watch(notesRepositoryProvider),
    apiKeys: ref.watch(apiKeyStoreProvider),
    aiSummariesDao: /* 同 BookPreprocessor 用的 dao */,
    clientFactory: ({required baseUrl, required apiKey, required model}) =>
        OpenAiCompatibleClient(
            baseUrl: baseUrl, apiKey: apiKey, model: model),
  ));
}),
```

**实施者注意**：`chapterTextProviderFor` 和 `aiSummariesDao` 的具体获取方式要看 BookPreprocessor 在 app_providers 中怎么 wire 的——直接照抄那个模式。

- [ ] **Step 3: 跑全套测试确认无回归**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1`

Expected: 全部通过（widget test 默认不挂生产 override，所以仍走 NoOp）

- [ ] **Step 4: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add app/lib/core/app_providers.dart
```

```bash
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m2.1/t11): wire production BookReviewer override

Production ReviewController now uses real BookReviewer with OpenAiCompatibleClient. Tests default to NoOp (un-overridden).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: VaultExporter 服务

**Files:**
- Create: `app/lib/features/notes/services/vault_exporter.dart`
- Test: `app/test/features/notes/services/vault_exporter_test.dart`

- [ ] **Step 1: 写 RED 测试**

创建 `app/test/features/notes/services/vault_exporter_test.dart`：

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/features/notes/services/vault_exporter.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('vault_exporter_test');
  });
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('VaultExporter.export', () {
    test('writes one md per book + index.md', () async {
      final books = [_book('b1', 'Book A'), _book('b2', 'Book B')];
      final notes = {
        'b1': _note('b1', 'Book A', summary: 's1', takeaways: ['t1']),
        'b2': _note('b2', 'Book B', annotations: [_annotation('quote')]),
      };
      final result = await VaultExporter.export(
        books: books,
        notesByBookId: notes,
        targetDir: tempDir,
        now: DateTime(2026, 6, 30, 14, 32, 0),
      );
      expect(result.booksExported, 2);
      expect(result.writtenFiles.length, 3); // 2 books + index.md
      expect(result.writtenFiles, contains('index.md'));
      expect(result.writtenFiles, contains('Book A - 读书笔记.md'));
      expect(result.writtenFiles, contains('Book B - 读书笔记.md'));
      expect(result.failures, isEmpty);
    });

    test('filters out books without notes', () async {
      final books = [_book('b1', 'A'), _book('b2', 'B')];
      final notes = {'b1': _note('b1', 'A', summary: 's')};
      final result = await VaultExporter.export(
        books: books,
        notesByBookId: notes,
        targetDir: tempDir,
        now: DateTime(2026, 6, 30),
      );
      expect(result.booksExported, 1);
    });

    test('filters out notes with empty content', () async {
      final books = [_book('b1', 'A')];
      final notes = {'b1': _note('b1', 'A')};  // empty note
      final result = await VaultExporter.export(
        books: books,
        notesByBookId: notes,
        targetDir: tempDir,
        now: DateTime(2026, 6, 30),
      );
      expect(result.booksExported, 0);
      // index.md still written? — spec says yes (with 0 books)
      expect(result.writtenFiles, contains('index.md'));
    });

    test('sorts books by title', () async {
      final books = [_book('b1', 'Zebra'), _book('b2', 'Apple')];
      final notes = {
        'b1': _note('b1', 'Zebra', summary: 's'),
        'b2': _note('b2', 'Apple', summary: 's'),
      };
      final order = <String>[];
      await VaultExporter.export(
        books: books,
        notesByBookId: notes,
        targetDir: tempDir,
        now: DateTime(2026, 6, 30),
        onProgress: (current, total, title) => order.add(title),
      );
      expect(order, ['Apple', 'Zebra']);
    });

    test('overwrites existing file at same path', () async {
      final targetFile = File(p.join(tempDir.path, 'Book A - 读书笔记.md'));
      await targetFile.writeAsString('OLD CONTENT');
      final books = [_book('b1', 'Book A')];
      final notes = {'b1': _note('b1', 'Book A', summary: 'NEW')};
      await VaultExporter.export(
        books: books,
        notesByBookId: notes,
        targetDir: tempDir,
        now: DateTime(2026, 6, 30),
      );
      final content = await targetFile.readAsString();
      expect(content, isNot(contains('OLD CONTENT')));
      expect(content, contains('NEW'));
    });

    test('records failure but continues on write error', () async {
      // Make targetDir read-only to force write failure
      // Windows: 略 — 这个测试在 Windows 上可能不稳定，可改用非可写目录 mock
      // Simplification: pass a non-existent subdirectory
      final badDir = Directory(p.join(tempDir.path, 'no_such'));
      // 不要先创建 badDir
      final books = [_book('b1', 'A'), _book('b2', 'B')];
      final notes = {
        'b1': _note('b1', 'A', summary: 's'),
        'b2': _note('b2', 'B', summary: 's'),
      };
      // 注意：badDir 不存在时 writeAsString 会抛 PathNotFoundException，
      // 但 Dart 的 File.writeAsString 会自动创建父目录？不会。
      // 此测试需要让"其中一本失败"，实施者可能需要 mock FileSaver。
      // 简化：跳过此测试，改为下面 "all success" 测试。
    }, skip: 'mock setup TODO - implement with file system mock');

    test('index.md contains frontmatter + wiki-links', () async {
      final books = [_book('b1', '量子')];
      final notes = {'b1': _note('b1', '量子', summary: 's', tags: ['物理'])};
      await VaultExporter.export(
        books: books,
        notesByBookId: notes,
        targetDir: tempDir,
        now: DateTime(2026, 6, 30, 14, 32, 0),
      );
      final indexContent =
          await File(p.join(tempDir.path, 'index.md')).readAsString();
      expect(indexContent, contains('type: zhiyue-vault-index'));
      expect(indexContent, contains('exported_at: 2026-06-30T14:32:00'));
      expect(indexContent, contains('book_count: 1'));
      expect(indexContent, contains('[[《量子》 - 读书笔记|《量子》]]'));
      expect(indexContent, contains('#物理'));
    });

    test('omits tag cloud when no tags', () async {
      final books = [_book('b1', 'A')];
      final notes = {'b1': _note('b1', 'A', summary: 's')};
      await VaultExporter.export(
        books: books,
        notesByBookId: notes,
        targetDir: tempDir,
        now: DateTime(2026, 6, 30),
      );
      final indexContent =
          await File(p.join(tempDir.path, 'index.md')).readAsString();
      expect(indexContent, isNot(contains('## 标签云')));
    });

    test('progress callback receives 1-based current', () async {
      final books = [_book('b1', 'A'), _book('b2', 'B'), _book('b3', 'C')];
      final notes = {
        'b1': _note('b1', 'A', summary: 's'),
        'b2': _note('b2', 'B', summary: 's'),
        'b3': _note('b3', 'C', summary: 's'),
      };
      final calls = <(int, int, String)>[];
      await VaultExporter.export(
        books: books,
        notesByBookId: notes,
        targetDir: tempDir,
        now: DateTime(2026, 6, 30),
        onProgress: (c, t, title) => calls.add((c, t, title)),
      );
      expect(calls[0], (1, 3, 'A'));
      expect(calls[1], (2, 3, 'B'));
      expect(calls[2], (3, 3, 'C'));
    });
  });
}

Book _book(String id, String title) => Book(
      id: id, title: title, author: null, format: BookFormat.epub,
      filePath: '/$id.epub', fileHash: null, fileSizeBytes: 0,
      coverPath: null, addedAt: DateTime(2026, 1, 1),
    );

BookNote _note(String bookId, String bookTitle,
    {String summary = '',
    List<String> takeaways = const [],
    List<Annotation> annotations = const [],
    List<String> tags = const []}) {
  // 构造带 tags 的 annotation（合并到第一个 annotation 上以简化测试）
  final annWithTags = annotations.isEmpty && tags.isNotEmpty
      ? [_annotation('placeholder', tags: tags)]
      : annotations;
  return BookNote(
    id: 'note_$bookId',
    bookId: bookId,
    title: '《$bookTitle》读书笔记',
    summary: summary,
    keyTakeaways: takeaways,
    annotations: annWithTags,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 30),
  );
}

Annotation _annotation(String quote, {List<String> tags = const []}) {
  // 实施者参考已有 annotation_test.dart 构造方式
  // 简化版：
  return Annotation(
    id: 'a_${quote.hashCode}',
    bookNoteId: 'note_x',
    locator: EpubCfiLocator(cfi: '/6', chapterIndex: 0),
    quote: quote,
    note: '',
    color: HighlightColor.yellow,
    tags: tags,
    source: AnnotationSource.manual,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );
}
```

- [ ] **Step 2: 跑测试确认 FAIL**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/notes/services/vault_exporter_test.dart`

Expected: FAIL（`VaultExporter` 不存在）

- [ ] **Step 3: 写实现**

创建 `app/lib/features/notes/services/vault_exporter.dart`：

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../data/models/annotation.dart';
import '../../../data/models/book.dart';
import '../../../data/models/book_note.dart';
import 'markdown_exporter.dart';
import 'note_file_writer.dart';

class VaultExportResult {
  const VaultExportResult({
    required this.booksExported,
    required this.totalHighlights,
    required this.totalNotes,
    required this.writtenFiles,
    required this.failures,
  });

  final int booksExported;
  final int totalHighlights;
  final int totalNotes;
  final List<String> writtenFiles; // relative paths
  final List<VaultExportFailure> failures;
}

class VaultExportFailure {
  const VaultExportFailure({
    required this.bookId,
    required this.bookTitle,
    required this.error,
  });
  final String bookId;
  final String bookTitle;
  final Object error;
}

class VaultExporter {
  /// Writes one .md per book (using existing [MarkdownExporter]) + an
  /// index.md with wiki-links. Files at the same paths are overwritten.
  ///
  /// Books without notes / with empty notes are skipped. The index.md is
  /// always written (even if zero books pass the filter) so the vault root
  /// always has a stable entry point.
  static Future<VaultExportResult> export({
    required List<Book> books,
    required Map<String, BookNote> notesByBookId,
    required Directory targetDir,
    required DateTime now,
    void Function(int current, int total, String bookTitle)? onProgress,
  }) async {
    final filtered = books.where((b) {
      final n = notesByBookId[b.id];
      if (n == null) return false;
      final hasContent = n.summary.isNotEmpty ||
          n.keyTakeaways.isNotEmpty ||
          n.annotations.isNotEmpty;
      return hasContent;
    }).toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final writtenFiles = <String>[];
    final failures = <VaultExportFailure>[];
    var totalHighlights = 0;
    var totalNotes = 0;
    final allTags = <String>{};

    for (var i = 0; i < filtered.length; i++) {
      final book = filtered[i];
      final note = notesByBookId[book.id]!;
      try {
        final markdown = MarkdownExporter.export(
          book: book,
          bookNote: note,
          now: now,
        );
        final filename =
            '${NoteFileWriter.sanitizeForFilename(book.title)} - 读书笔记.md';
        final filePath = p.join(targetDir.path, filename);
        await File(filePath).writeAsString(markdown);
        writtenFiles.add(filename);
        totalHighlights += note.annotations.length;
        totalNotes += note.annotations.where((a) => a.hasNote).length;
        for (final a in note.annotations) {
          allTags.addAll(a.tags);
        }
      } catch (e) {
        failures.add(VaultExportFailure(
            bookId: book.id, bookTitle: book.title, error: e));
      }
      onProgress?.call(i + 1, filtered.length, book.title);
    }

    // Write index.md
    final indexContent = _buildIndex(
      filtered: filtered,
      notesByBookId: notesByBookId,
      now: now,
      totalHighlights: totalHighlights,
      totalNotes: totalNotes,
      allTags: allTags,
    );
    final indexPath = p.join(targetDir.path, 'index.md');
    await File(indexPath).writeAsString(indexContent);
    writtenFiles.add('index.md');

    return VaultExportResult(
      booksExported: filtered.length,
      totalHighlights: totalHighlights,
      totalNotes: totalNotes,
      writtenFiles: writtenFiles,
      failures: failures,
    );
  }

  static String _buildIndex({
    required List<Book> filtered,
    required Map<String, BookNote> notesByBookId,
    required DateTime now,
    required int totalHighlights,
    required int totalNotes,
    required Set<String> allTags,
  }) {
    final iso =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'
        'T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final buf = StringBuffer()
      ..writeln('---')
      ..writeln('type: zhiyue-vault-index')
      ..writeln('exported_at: $iso')
      ..writeln('book_count: ${filtered.length}')
      ..writeln('total_highlights: $totalHighlights')
      ..writeln('total_notes: $totalNotes')
      ..writeln('---')
      ..writeln()
      ..writeln('# 我的智阅书架')
      ..writeln()
      ..writeln('> 共 ${filtered.length} 本书 · $totalHighlights 条高亮 · $totalNotes 条笔记')
      ..writeln('> 导出时间：$dateStr')
      ..writeln()
      ..writeln('## 书目')
      ..writeln();

    for (final book in filtered) {
      final note = notesByBookId[book.id]!;
      final highlights = note.annotations.length;
      final notes = note.annotations.where((a) => a.hasNote).length;
      final fileBaseName =
          '${NoteFileWriter.sanitizeForFilename(book.title)} - 读书笔记';
      final tagsStr = note.annotations
          .expand((a) => a.tags)
          .toSet()
          .map((t) => '#$t')
          .join(' ');
      final suffix = tagsStr.isEmpty ? '' : ' · $tagsStr';
      final noteLabel = highlights == 0 && notes == 0
          ? '（仅含 AI 回顾）'
          : '$highlights 高亮 / $notes 笔记';
      buf.writeln('- [[$fileBaseName|《${book.title}》]] — $noteLabel$suffix');
    }

    if (allTags.isNotEmpty) {
      final sortedTags = allTags.toList()..sort();
      buf
        ..writeln()
        ..writeln('## 标签云')
        ..writeln()
        ..writeln(sortedTags.map((t) => '#$t').join(' '));
    }

    return buf.toString();
  }
}
```

- [ ] **Step 4: 跑测试确认 PASS**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/notes/services/vault_exporter_test.dart`

Expected: PASS（7 个测试全绿，1 个 skip）

- [ ] **Step 5: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add app/lib/features/notes/services/vault_exporter.dart app/test/features/notes/services/vault_exporter_test.dart
```

```bash
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m2.1/t12): VaultExporter service

Writes per-book .md via existing MarkdownExporter + index.md with
Obsidian wiki-links + frontmatter. Filters empty notes, sorts by title,
overwrites existing files, collects failures without aborting.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: BatchExportDialog widget

**Files:**
- Create: `app/lib/features/library/widgets/batch_export_dialog.dart`
- Test: `app/test/features/library/widgets/batch_export_dialog_test.dart`

- [ ] **Step 1: 写 RED 测试**

创建 `app/test/features/library/widgets/batch_export_dialog_test.dart`：

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/library/widgets/batch_export_dialog.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';

void main() {
  late Directory tempDir;
  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('batch_export_test');
  });
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('shows progress bar and current title during export',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BatchExportDialog(
          targetDirPath: tempDir.path,
          books: [],  // 实施者需构造 test books
          notesByBookId: const {},
          onCompleted: (_) {},
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });

  testWidgets('cancel button stops export and pops with partial result',
      (tester) async {
    var completed = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BatchExportDialog(
          targetDirPath: tempDir.path,
          books: [],
          notesByBookId: const {},
          onCompleted: (_) => completed = true,
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    // After cancel, dialog should call onCompleted with whatever was exported
    expect(completed, isTrue);
  });
}
```

- [ ] **Step 2: 跑测试确认 FAIL**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/library/widgets/batch_export_dialog_test.dart`

Expected: FAIL

- [ ] **Step 3: 写实现**

创建 `app/lib/features/library/widgets/batch_export_dialog.dart`：

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../data/models/book.dart';
import '../../../data/models/book_note.dart';
import '../../../gen_l10n/app_localizations.dart';
import '../../notes/services/vault_exporter.dart';

/// Modal progress dialog that runs [VaultExporter.export] and reports
/// progress. User can cancel mid-export; already-written files are kept.
class BatchExportDialog extends StatefulWidget {
  const BatchExportDialog({
    super.key,
    required this.targetDirPath,
    required this.books,
    required this.notesByBookId,
    required this.onCompleted,
  });

  final String targetDirPath;
  final List<Book> books;
  final Map<String, BookNote> notesByBookId;
  final ValueChanged<VaultExportResult> onCompleted;

  @override
  State<BatchExportDialog> createState() => _BatchExportDialogState();
}

class _BatchExportDialogState extends State<BatchExportDialog> {
  int _current = 0;
  int _total = 0;
  String _currentTitle = '';
  bool _cancelled = false;
  VaultExportResult? _result;

  @override
  void initState() {
    super.initState();
    _total = widget.books.length;
    _runExport();
  }

  Future<void> _runExport() async {
    try {
      final result = await VaultExporter.export(
        books: widget.books,
        notesByBookId: widget.notesByBookId,
        targetDir: Directory(widget.targetDirPath),
        now: DateTime.now(),
        onProgress: (current, total, title) {
          if (_cancelled) throw const _CancelledException();
          if (!mounted) return;
          setState(() {
            _current = current;
            _total = total;
            _currentTitle = title;
          });
        },
      );
      if (mounted) {
        setState(() => _result = result);
        widget.onCompleted(result);
      }
    } on _CancelledException {
      // Already partial; onCompleted will be called below.
      if (mounted) {
        final partial = VaultExportResult(
          booksExported: _current,
          totalHighlights: 0,
          totalNotes: 0,
          writtenFiles: const [],
          failures: const [],
        );
        setState(() => _result = partial);
        widget.onCompleted(partial);
      }
    } catch (e) {
      if (mounted) {
        // Unexpected error — surface as a 0-export result.
        widget.onCompleted(VaultExportResult(
          booksExported: 0,
          totalHighlights: 0,
          totalNotes: 0,
          writtenFiles: const [],
          failures: const [],
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.batchExportConfirmTitle),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        LinearProgressIndicator(
          value: _total == 0 ? null : _current / _total,
        ),
        const SizedBox(height: 12),
        Text(l10n.batchExportProgress(_current, _total, _currentTitle)),
      ]),
      actions: [
        TextButton(
          onPressed: () {
            setState(() => _cancelled = true);
          },
          child: Text(l10n.reviewCancelButton),
        ),
      ],
    );
  }
}

class _CancelledException implements Exception {
  const _CancelledException();
}
```

- [ ] **Step 4: 跑测试确认 PASS**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/library/widgets/batch_export_dialog_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add app/lib/features/library/widgets/batch_export_dialog.dart app/test/features/library/widgets/batch_export_dialog_test.dart
```

```bash
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m2.1/t13): BatchExportDialog progress widget

AlertDialog with LinearProgressIndicator; cancel button throws
_CancelledException to halt the export loop. Partial results preserved.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Library AppBar 接入批量导出

**Files:**
- Modify: `app/lib/features/library/pages/library_page.dart`
- Test: `app/test/features/library/pages/library_page_batch_export_test.dart`（新建）

- [ ] **Step 1: 写 RED 测试**

创建 `app/test/features/library/pages/library_page_batch_export_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/library/pages/library_page.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';
// 其他必要 imports 视现有 library_page_test.dart 而定

void main() {
  testWidgets('library appbar overflow contains "导出为 Markdown"',
      (tester) async {
    // Setup 同 library_page 现有测试
    await tester.pumpWidget(/* ProviderScope + MaterialApp + LibraryPage */);
    await tester.pump();

    // 打开 AppBar 溢出菜单
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('导出为 Markdown'), findsOneWidget);
  });

  testWidgets('clicking export shows confirm dialog', (tester) async {
    // Setup 同上
    await tester.pumpWidget(/* ... */);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出为 Markdown'));
    await tester.pumpAndSettle();
    expect(find.text('导出读书笔记'), findsOneWidget);
  });
}
```

**实施者注意**：参考 `app/test/features/library/pages/library_page_test.dart` 已有的 setup helper（如果存在）。

- [ ] **Step 2: 跑测试确认 FAIL**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/library/pages/library_page_batch_export_test.dart`

Expected: FAIL

- [ ] **Step 3: 修改 library_page.dart**

打开 `app/lib/features/library/pages/library_page.dart`，找到 `LibraryAppBar`（grep `class LibraryAppBar`）的 `actions:`，在现有 `PopupMenuButton` items 中追加：

```dart
// 在 PopupMenuButton items 列表追加：
PopupMenuItem<String>(
  value: 'batch_export',
  child: Row(children: [
    const Icon(Icons.folder_zip_outlined),
    const SizedBox(width: 8),
    Text(AppLocalizations.of(context)!.batchExportMenuLabel),
  ]),
),
```

在 `onSelected` 处理中追加分支：

```dart
if (value == 'batch_export') {
  _startBatchExport(context, ref);
}
```

并在 `_LibraryPageState` 或对应的 controller widget 中加 `_startBatchExport` 方法：

```dart
Future<void> _startBatchExport(BuildContext context, WidgetRef ref) async {
  final books = await ref.read(bookRepositoryProvider).getAll();
  // Pre-load notes for all books in parallel
  final notesByBookId = <String, BookNote>{};
  for (final book in books) {
    final note = await ref.read(notesRepositoryProvider).getNoteByBook(book.id);
    if (note != null) notesByBookId[book.id] = note;
  }
  if (!context.mounted) return;

  final l10n = AppLocalizations.of(context)!;
  final exportableCount = books
      .where((b) => notesByBookId.containsKey(b.id))
      .length;

  if (exportableCount == 0) {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.batchExportNoNotesTitle),
        content: Text(l10n.batchExportNoNotesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(l10n.batchExportConfirmTitle),
      content: Text(l10n.batchExportConfirmMessage(notesByBookId.length)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.reviewCancelButton),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('选择文件夹'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final dirPath = await FilePicker.platform.getDirectoryPath();
  if (dirPath == null) return;
  if (!context.mounted) return;

  VaultExportResult? result;
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => BatchExportDialog(
      targetDirPath: dirPath,
      books: books,
      notesByBookId: notesByBookId,
      onCompleted: (r) {
        result = r;
        Navigator.of(context).pop();
      },
    ),
  );
  if (!context.mounted || result == null) return;

  final snack = SnackBar(
    content: Text(_summarizeResult(l10n, result!, dirPath)),
    action: SnackBarAction(
      label: l10n.batchExportOpenFolder,
      onPressed: () => _openFolder(dirPath),
    ),
  );
  ScaffoldMessenger.of(context).showSnackBar(snack);
}

String _summarizeResult(
    AppLocalizations l10n, VaultExportResult result, String path) {
  if (result.failures.isEmpty) {
    return l10n.batchExportSuccess(result.booksExported, path);
  }
  return l10n.batchExportPartialFailure(
    result.booksExported,
    result.booksExported + result.failures.length,
    result.failures.length,
  );
}

Future<void> _openFolder(String path) async {
  // 复用 notes_page.dart 中已有的 _openFolder 逻辑（M3.4 T13）
  // 或抽出为公共 helper。
  try {
    if (Platform.isWindows) {
      await Process.run('explorer', [path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
  } catch (_) {}
}
```

加 imports：

```dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:zhiyue/features/library/widgets/batch_export_dialog.dart';
import 'package:zhiyue/features/notes/services/vault_exporter.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/data/repositories/notes_repository.dart';
```

**实施者注意**：上述代码可能有 `_LibraryPageState` vs ConsumerWidget 的结构差异。要看 library_page.dart 实际结构（M3.1 之后可能有重构）。

- [ ] **Step 4: 跑测试确认 PASS**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1 test/features/library/pages/library_page_batch_export_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add app/lib/features/library/pages/library_page.dart app/test/features/library/pages/library_page_batch_export_test.dart
```

```bash
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
feat(m2.1/t14): library appbar batch export entry

Adds "export to Markdown" menu item -> confirm dialog -> folder picker
-> BatchExportDialog -> snack with open-folder action.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: 全量测试 + analyze + fixups

**Files:** 全部

- [ ] **Step 1: 跑全量测试**

Run: `/c/flutter/bin/flutter.bat test --concurrency=1`

Expected: 全部通过（约 760 个测试，2 skipped）。如有失败，记下失败列表。

- [ ] **Step 2: 跑 dart analyze**

Run: `/c/flutter/bin/dart.bat analyze`

Expected: 0 warnings / 0 errors。如有，逐一修复。

- [ ] **Step 3: 修复发现的任何失败/警告**

针对每个失败/警告：
- 修改对应文件
- 重跑该测试/analyze 确认修复

- [ ] **Step 4: Commit fixups（如有）**

```bash
git -C "H:/projiect/电子书阅读平台" add <changed files>
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
fix(m2.1/t15): address test/analyze findings

<具体修复内容>

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

如果没有 fixup，跳过此 step。

- [ ] **Step 5: Push 全部 commits**

```bash
git -C "H:/projiect/电子书阅读平台" push origin master
```

---

## Task 16: Runbook 更新

**Files:**
- Modify: `docs/maintainers-runbook.md`

- [ ] **Step 1: 加 M2.1 章节**

打开 `docs/maintainers-runbook.md`，在 §8 Common Bugs 后追加新章节 §9.x（如果 §9 是 Performance Baseline，则加在 §10 之前）：

```markdown
## §X M2.1 章节回顾 + 批量导出

### X.1 BookReviewer 缓存命中规则

`ai_summaries` 表中 `mode='review'` 的行的 sourceHash = `sha256(truncatedChapterText + '::' + highlightsSignature)`。highlightsSignature 是本章所有高亮 quote 按 createdAt 升序拼接后的 sha256。

**调试技巧**：如果用户报告"加了高亮但回顾没变"，检查 highlightsSignature 是否正确包含新加的 quote。

### X.2 幂等保存前缀

`book_notes.keyTakeaways` 中 AI 写入的条目格式：`【第N章】 <内容>`。
`book_notes.summary` 中 AI 写入的段落 sentinel：`## 第 N 章 · <标题>`。

重复回顾同章时，先删后加；用户手动添加的不带前缀内容永远保留。

### X.3 批量导出文件命名

`<sanitizeForFilename(book.title)> - 读书笔记.md`。同名文件**直接覆盖**（与单书导出 `NoteFileWriter.saveMarkdownFile` 的 collision avoidance 行为不同——单书导出避免覆盖，批量导出强制覆盖以保证 vault 一致性）。

### X.4 PDF 书不支持回顾

按 M4 Page-as-Chapter，PDF "章"就是页，回顾单页意义不大。TOC 抽屉 + 阅读器溢出菜单在 PDF 书上都禁用回顾入口。
```

- [ ] **Step 2: Commit**

```bash
git -C "H:/projiect/电子书阅读平台" add docs/maintainers-runbook.md
```

```bash
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
docs(m2.1/t16): runbook sections for review cache + idempotent prefix

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 17: v1.1.0-alpha 发布

**Files:**
- Modify: `app/pubspec.yaml` (version bump)
- Modify: `CHANGELOG.md`
- Create: `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_m2_1_complete.md`
- Modify: `C:\Users\1\.claude\projects\H--projiect--------\memory\MEMORY.md`

- [ ] **Step 1: pubspec.yaml 版本号**

打开 `app/pubspec.yaml`，把 `version: 1.0.0+0` 改为 `version: 1.1.0-alpha+0`。

- [ ] **Step 2: CHANGELOG.md**

打开 `CHANGELOG.md`，在顶部追加：

```markdown
## [1.1.0-alpha] - 2026-06-30

### Added
- **章节学习回顾**（MVP 2.0）：TOC 抽屉按章节 + 阅读器溢出菜单"回顾本章"。AI 用本章正文 + 用户高亮生成 summary + keyTakeaways，写入读书笔记。模态预览 + 保存/取消。
- **Markdown 批量导出**（MVP 2.0）：库 AppBar 溢出菜单"导出为 Markdown"。选文件夹，每本书一份 .md + 一个 index.md（Obsidian vault 兼容）。
- 25 个 i18n key。

### Changed
- `PromptBuilder.promptVersion` 1 → 2（review 模式新 cache key）。

### Technical
- 新增 `BookReviewer` 独立服务（不复用 AiGuide，因 review 缓存 hash 必须包含用户高亮）。
- 新增 `VaultExporter` 纯逻辑 + 文件 I/O 服务。
- 新增 `ReviewController` + `ReviewPreviewSheet` + `BatchExportDialog`。
- `NotesRepository.applyChapterReview` 幂等写入（前缀约定）。
- 0 数据库迁移；0 同步逻辑改动。
```

- [ ] **Step 3: Commit + tag**

```bash
git -C "H:/projiect/电子书阅读平台" add app/pubspec.yaml CHANGELOG.md
git -C "H:/projiect/电子书阅读平台" commit -m "$(cat <<'EOF'
chore(m2.1): v1.1.0-alpha release

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

```bash
git -C "H:/projiect/电子书阅读平台" tag -a m2.1-complete -m "M2.1 complete: chapter review + batch export"
git -C "H:/projiect/电子书阅读平台" tag -a v1.1.0-alpha -m "v1.1.0-alpha: AI chapter review + Markdown batch export"
```

- [ ] **Step 4: Push tags**

```bash
git -C "H:/projiect/电子书阅读平台" push origin master --tags
```

- [ ] **Step 5: 写 memory 文件**

创建 `C:\Users\1\.claude\projects\H--projiect--------\memory\project_zhiyue_m2_1_complete.md`：

```markdown
---
name: zhiyue-m2-1-complete
description: 智阅 M2.1 章节学习回顾 + Markdown 批量导出完整交付
metadata:
  type: project
---

2026-06-30 交付。tag `m2.1-complete` + `v1.1.0-alpha`。

**新增功能**：
- 章节回顾（手动按钮：TOC 抽屉按章节 + 阅读器溢出菜单）。AI 输入 = 本章正文 + 用户本章高亮 → 输出 JSON {summary, keyTakeaways}。模态预览 + 保存/取消。
- Markdown 批量导出：库 AppBar 溢出菜单 → 选文件夹 → 多 .md + index.md。

**关键决策**：
- BookReviewer 独立不复用 AiGuide（spec 偏差）：因 AiGuide sourceHash 只 hash 文本，无法感知用户高亮变化，会导致缓存命中错误。BookReviewer 自己计算 `sha256(truncatedText + '::' + highlightsSignature)`。
- 复用 book_notes.summary/keyTakeaways，无 schema 迁移。
- 幂等：`【第N章】` 前缀 + `## 第 N 章` sentinel，先删后加。

**交付数据**：
- 17 tasks + ~43 新测试（总 760+）
- 10 新 lib + 8 修改文件
- 0 DB 迁移；0 同步改动
- promptVersion 1→2

**遗留**：
- 自动章节结束提示（用户选了手动触发）→ 推 M2.2 或更晚
- 批量导出范围筛选（按 tag / 时间）→ 推 M2.3
- OCR / Zotero / 知识图谱 → MVP 3.0+

链接：[[zhiyue-m1-6-complete]]（前一 milestone）、[[zhiyue-design-context]]（路线图）。
```

- [ ] **Step 6: 更新 MEMORY.md 索引**

打开 `C:\Users\1\.claude\projects\H--projiect--------\memory\MEMORY.md`，在 m1.6_complete 那行后追加：

```
- [智阅 M2.1 完整交付](project_zhiyue_m2_1_complete.md) — 2026-06-30 17 tasks，tag m2.1-complete + v1.1.0-alpha；章节学习回顾 + Markdown 批量导出；BookReviewer 独立不复用 AiGuide（缓存 hash 须含高亮）
```

- [ ] **Step 7: 最终验证**

```bash
git -C "H:/projiect/电子书阅读平台" log --oneline m1.6-polish-sweep..HEAD | wc -l
```

Expected: 约 17-20 个 commits。

```bash
git -C "H:/projiect/电子书阅读平台" tag --list | grep -E "m2.1|v1.1"
```

Expected: 看到 `m2.1-complete` + `v1.1.0-alpha` 两个 tag。

---

## Self-Review 检查

实施者在执行本计划前应自查：

**1. Spec coverage**：
- ✅ §3.1 数据流 → T2-T10（Reviewer + Controller + Sheet + 接入）
- ✅ §3.2 数据流 → T11-T14（VaultExporter + Dialog + 接入）
- ✅ §4 Prompt → T3
- ✅ §4.3 缓存 → T5（BookReviewer 自管 sourceHash）
- ✅ §4.7 幂等保存 → T4
- ✅ §5.2 VaultExporter 算法 → T12
- ✅ §5.3 index.md → T12
- ✅ §5.4 文件夹 UX → T13 + T14
- ✅ §6.2 i18n 25 key → T1
- ✅ §7.1 验收 13 条 → T7-T14 覆盖
- ✅ §9 文件清单 → 全部对应

**2. 偏差记录**：
- T5 BookReviewer **独立**不复用 AiGuide（spec §4.4 提议用 AiGuide，但实施前发现缓存 hash 问题，本计划让 BookReviewer 独立处理）
- T11 不修改 `ai_guide.dart`（spec §9.2 列了，本计划不需要）

**3. 已知 plan 待补全**（实施者按需展开）：
- T5 测试中的 `_noteWithHighlights` / `_hashFor` helper
- T9/T14 widget test 的 setup helper（参考已有 reader_body_test / library_page_test）
- T8 的 IconButton 在 TocDrawer 中的具体插入位置（看现有 build 结构）

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-30-m2-1-chapter-review-batch-export.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - 每个 task 派遣新 subagent + 两阶段评审（spec compliance → code quality）

**2. Inline Execution** - 当前会话执行 executing-plans，批量执行 + checkpoint 评审

**Which approach?**
