# M2.4 v1.4.0-alpha Release Hygiene Sweep — Design Spec

**日期**：2026-07-01
**作者**：Claude（项目主开发助手）
**前置**：M2.3 (`m2.3-complete` + `v1.3.0-alpha`) 已交付；项目级 review (`docs/reviews/2026-07-01-project-review.md`) §6 Top 5 中 #4 截图 + Gitee Release、#5 reader_body 拆分仍 pending
**目标 tag**：`m2.4-complete` + `v1.4.0-alpha`

---

## 1. 目标

把 Phase 3+ 之前的所有遗留任务一次性解决，让用户可以开始真实使用测试。具体范围：

1. **Code 工作**（Claude 驱动）：
   - `reader_body.dart` 644 行 minimal split（抽 2 个零依赖子系统）
   - 49 个 info lint 清理（`dart fix --apply` + 残留手工）
   - 性能 baseline 文档化（runbook §9.4 加 v1.4 复测决策）

2. **Release housekeeping**（Claude 驱动）：
   - `release-procedure.md` 步骤 1/12 同步
   - `CHANGELOG.md` 加 `[1.4.0-alpha]` + `release-notes-v1.4.0-alpha.md` 草稿

3. **手动项交互式指导**（用户跑命令，Claude 解读）：
   - 3 张 release 截图（library / pdf_reader / notes）
   - 4 个 Gitee Release 页面（v1.0.0 / v1.1.0-alpha / v1.2.0-alpha / v1.3.0-alpha）
   - 真实 DeepSeek key 烟测
   - 两台 Windows sync 端到端验证

**不在范围**（推后 v1.5+）：
- `library_page.dart` 443 行 / `ai_guide_sheet.dart` 372 行 / `book_detail_page.dart` 362 行拆分
- iOS / Mac 端、跨书 AI 伴读、Zotero/Obsidian 双向同步、知识图谱

---

## 2. 架构

8 个 task，分 3 个 phase 顺序执行：

```
Phase 1 (Code)             Phase 2 (Docs)            Phase 3 (Manual)
─────────────              ─────────────             ────────────────
T1 reader_body split  →    T4 release-procedure  →   T6 screenshots
T2 dart fix --apply   →    T5 CHANGELOG + relnotes  → T7 Gitee Release pages
T3 runbook §9 perf    →                              T8 DeepSeek smoke + sync E2E
                                                       ↓
                                                    tag m2.4-complete + v1.4.0-alpha
```

**Phase 顺序的理由**：
- Code 必须先于 Docs（CHANGELOG 需反映 code 改动）
- Docs 必须先于 Manual（manual 用户需要 release notes 草稿）
- Manual 完成后才 tag（tag 后不能改 commit）

**T1 顺序在 T2 之前的理由**：T1 可能引入新 lint（widget 拆分时 import 重排），T2 一次性清理。

---

## 3. 组件设计

### 3.1 T1 — `reader_body.dart` minimal split

新增 2 个文件，`reader_body.dart` 从 644 → ~470 行（orchestrator only）：

#### 文件 1：`app/lib/features/reader/widgets/reader_chapter_end_prompt.dart`

```dart
/// Listener widget that owns [ChapterEndPromptController] lifecycle.
/// Renders nothing (SizedBox.shrink); side effect is SnackBar emission
/// via ScaffoldMessenger when source stream emits visible events.
///
/// EPUB-only: caller (ReaderBody) inserts this widget into Stack only
/// when `engine is ConcreteEpubReaderEngine`. The required engine type
/// enforces this at compile time — no runtime assert needed.
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

class _ReaderChapterEndPromptState extends ConsumerState<ReaderChapterEndPrompt> {
  late final ChapterEndPromptController _controller;
  ChapterEndPromptVisibility _lastVisibility = ChapterEndPromptVisibility.hidden;

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
      ..showSnackBar(ChapterEndPromptSnackBar(
        context: context,
        hasNext: s.hasNext,
        onReview: () { _controller.dismiss(); widget.onReview(s.chapterIndex); },
        onNext: () { _controller.dismiss(); widget.onNext(); },
        onDismiss: () { _controller.dismiss(); },
      ));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

**关键决策**：
- **ConsumerStatefulWidget**：与项目惯例一致（其他 reader widget 也用 ConsumerWidget），通过 `ref.read(settingsRepositoryProvider)` 直接拿 repo，避免 prop drilling
- **EPUB-only 由类型系统保证**：构造函数 `required this.engine` 类型即 `ConcreteEpubReaderEngine`，编译期拒绝 PdfReaderEngine。ReaderBody 在 build 时按 engine 类型条件插入 widget
- **Listener 触发 SnackBar 时 mounted 检查**：与现有 `_showChapterEndPrompt` 行为一致
- **`late final _controller`**：initState 立刻初始化，dispose 时直接 `_controller.dispose()`（非 null-check）

#### 文件 2：`app/lib/features/reader/widgets/reader_selection_toolbar.dart`

```dart
/// Floating selection toolbar overlay. Renders nothing when selection
/// is null or empty; otherwise renders [HighlightSelectionControls] in
/// a [Positioned] at top of the reader body.
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
    if (sel == null || sel.plainText.isEmpty) return const SizedBox.shrink();
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

**关键决策**：
- **返回 SizedBox.shrink() 而非 null**：Flutter widget tree 不允许 null，shrink 是 zero-size 占位，对 Stack layout 无影响。
- **Positioned 在 widget 内部**：调用方 Stack 直接 `children: [..., ReaderSelectionToolbar(...)]`，不需要外面再包 Positioned。

#### `reader_body.dart` 改动

**删除字段**：
- `_chapterEndPromptController`
- `_lastPromptVisibility`

**删除方法**：
- `_onPromptStateChanged`
- `_showChapterEndPrompt`

**修改 initState**：删除 EPUB path lazy-init 注释 + 相关 listener 注册（lazy-init 移到 ReaderChapterEndPrompt）

**修改 dispose**：删除 `_chapterEndPromptController?.dispose()`

**修改 build**：
- 删除 `_chapterEndPromptController == null && engine is ConcreteEpubReaderEngine` lazy-init block
- Stack children 内新增（条件插入）：
  ```dart
  if (engine is ConcreteEpubReaderEngine)
    ReaderChapterEndPrompt(
      engine: engine as ConcreteEpubReaderEngine,
      bookId: widget.bookId,
      onReview: _onOpenReview,
      onNext: () => engine.nextSpine(),
    ),
  ```
- 把 `if (_selection != null && _selection!.plainText.isNotEmpty) Positioned(...)` 替换为：
  ```dart
  ReaderSelectionToolbar(
    selection: _selection,
    onHighlight: _onToolbarHighlight,
    onNote: _onToolbarNote,
    onCopy: _onCopySelection,
    onAiComment: _onAiComment,
  ),
  ```

**保持不变**：
- `_selection` 字段（State 持有）
- 所有 `_onXxx` 回调方法（仍在 State）
- `_onPdfHighlight` / `_onOpenAiGuide` / `_onOpenReview` / `_onOpenQa` 等

### 3.2 T2 — Lint 清理

```bash
cd /h/projiect/电子书阅读平台/app
/c/flutter/bin/dart.bat fix --dry-run   # 先看清单
/c/flutter/bin/dart.bat fix --apply
```

预计自动修：~30 个 cascade + 4 quote + 1 interpolation。

**残留手工处理**：
- `no_leading_underscores_for_local_identifiers`（4 个 test 文件中的 `_previousPlatform` 等）→ rename 去掉前缀下划线
- 个别 `cascade_invocations` receiver 是 await 表达式（不能转）→ `// ignore: cascade_invocations` 行内注释

目标：analyze info 数从 49 → ≤ 10。

### 3.3 T3 — `maintainers-runbook.md §9.4` v1.4 复测决策

在 §9.4 表后追加 §9.4.1 段落（见 §5 design 中的 draft），说明 v1.3→v1.4 无重大渲染/DB/sync 改动，沿用 v1.0.0 baseline；下次强制复测触发条件（v1.5 跨书 AI 伴读 / reader_engine 重构 / 用户报告卡顿）。

### 3.4 T4 — `release-procedure.md` 同步

- 步骤 1 期望值：`1.1.0-alpha+0` → `1.3.0-alpha+0`（或加注释"以当前发布版本为准"）
- 步骤 12 AGPLv3 头检查阈值：`应 ≤ 17` → `应 = 0`（M1.5bc-review-fixups 后所有源文件都有头）
- 步骤 2 期望测试数：`≥ 762` → `≥ 812`

### 3.5 T5 — CHANGELOG + release notes

- `CHANGELOG.md` 加 `[1.4.0-alpha]` 段落，复用 v1.3.0-alpha 模板
- `docs/releases/release-notes-v1.4.0-alpha.md` 草稿：列 reader_body 拆分 + lint 清理 + runbook 完备性 + 性能 baseline 决策；注意不夸大（" polish, no user-facing feature changes"）

### 3.6 T6-T8 — 手动项交互式指导

详见 §4 数据流。Claude 在 Phase 3 开始时为每个 task 提供 step-by-step 命令清单，用户跑命令 + 截图，Claude 验证 + commit + 解读结果。

---

## 4. 数据流与交互

### 4.1 Phase 3 启动条件

T1-T5 全部 commit + push；analyze + test 全绿；docs 同步到 v1.4 状态。

### 4.2 T6 截图流程

```
Claude: cp -r project → /c/dev/zhiyue-screenshots
Claude: flutter pub get + flutter run -d windows --release
User: 导入 ≥2 本书，Win+Shift+S 截 library → 告知 Claude
Claude: 验证文件存在 + 大小 > 10KB → commit "docs(v1.4): library screenshot"
(重复 pdf_reader / notes)
```

### 4.3 T7 Gitee Release 流程

**Claude 准备**：为 4 个 release 各生成 body markdown（从 CHANGELOG.md 对应段落 + 加"如何安装"段落）。

**用户操作**（每个 release）：
1. 浏览器开 https://gitee.com/weifu0523/e-book-reading-platform/releases/new
2. 选 tag
3. 粘贴 body
4. 上传 artifact（v1.3.0-alpha 必须，其他可选）
5. 发布

**Claude 验证**：每个 release URL 可访问 + 下载链接有效。

### 4.4 T8 烟测流程

**DeepSeek 烟测**：用户配 API key → 触发章节导读 → Claude 解读结果（成功 / 401 / 429 / timeout）。

**Sync E2E**：用户机器 A 配坚果云 + 高亮 → 机器 B 配同账号 + pull → Claude 解读结果（一致 / 冲突日志分析）。

---

## 5. 错误处理与回滚

### 5.1 T1 拆分破坏行为

**检测**：T1 完成后跑全量 widget test，任何 reader_body 相关测试 fail。

**回滚**：`git revert <T1-commit-sha>`，重新设计拆分边界。

### 5.2 T2 dart fix 误改

**检测**：T2 完成后跑全量测试，任何测试 fail。

**回滚**：`git checkout .`（T2 commit 前必须先 stash），逐项手工 lint 处理。

### 5.3 T6 截图失败

**检测**：release build 失败（中文路径）或截屏文件 < 10KB（空白图）。

**缓解**：
- 中文路径问题：`cp -r` 到 `/c/dev/zhiyue-screenshots` 已在流程内
- 空白图：让用户重新截，或用 debug mode fallback

### 5.4 T7 Gitee Release 上传失败

**缓解**：分批上传（每次 1 个 artifact）；网络问题等 1 小时重试。

### 5.5 T8 烟测失败

**DeepSeek 401**：API key 配错，让用户重新配。
**DeepSeek 429**：rate limit，等几分钟重试。
**Sync 冲突**：分析 ConflictSink 日志，若是 last-write-wins 正常路径，告知用户；若是真冲突（同 hightlight 同 mtime），记为 v1.5 改进项。

---

## 6. 测试策略

### 6.1 单元/widget 测试

- **T1 新增**：
  - `test/features/reader/widgets/reader_chapter_end_prompt_test.dart`：
    - EPUB engine 时创建 controller + 注册 listener
    - PDF engine 时不渲染（widget 不被插入 Stack）
    - listener hidden→visible edge 触发 SnackBar
    - dispose 时 controller.dispose() 被调用
    - rebuild 不重新创建 controller
  - `test/features/reader/widgets/reader_selection_toolbar_test.dart`：
    - null selection → 不渲染 HighlightSelectionControls
    - empty selection → 不渲染
    - non-empty → 渲染 + 4 个回调可触发
- **T1 复用**：既有 `chapter_end_prompt_snackbar_test.dart` / `chapter_end_prompt_controller_test.dart` 全 pass

### 6.2 集成测试

无需新增。T1 是 widget tree 重排，不涉及新流程。

### 6.3 回归测试

每个 task 完成后跑 `flutter test --concurrency=1`：
- T1 后：812+3 pass（拆分零行为变化）
- T2 后：812+3 pass（lint 清理语义不变）
- T3-T5 后：N/A（纯文档）
- T6-T8 后：N/A（手动验证）
- 收尾：812+3 pass + analyze info ≤ 10

---

## 7. 路线图对齐

本 sweep 完成 `docs/reviews/2026-07-01-project-review.md` §6 中：
- #4 截图 + Gitee Release（部分完成 — 4 张截图全到位，4 个 release 页面全建）
- #5 reader_body 拆分（部分完成 — minimal split，未达 ≤300 但减 27%）

review 中 #1-#3 已在 M1.5bc review-fixups / M2.2 / M2.3 中完成。

---

## 8. 验收标准

| 维度 | 验收 |
|---|---|
| Code 质量 | 0 errors / 0 warnings / info ≤ 10 |
| 测试 | 812+ pass + 3 skip 不退化；T1 新增 ≥ 6 个 widget test |
| 文档 | runbook §9.4.1 + release-procedure + CHANGELOG + release-notes-v1.4 全更新 |
| 截图 | 4/4 张 PNG 在 `docs/screenshots/`，README 表格无 broken image |
| Gitee Release | 4/4 个 release 页面可访问，v1.3.0-alpha 附 artifact |
| 烟测 | DeepSeek 章节导读返回非空 summary |
| Sync E2E | 两台机器高亮一致（或冲突日志可解释） |
| Tag | `m2.4-complete` + `v1.4.0-alpha` 推送 origin |
| Memory | `project_zhiyue_m2_4_complete.md` 写入；MEMORY.md 索引加新行 |
