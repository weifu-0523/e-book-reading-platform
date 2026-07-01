# 智阅 M2.2 — 自动章节结束提示 设计文档

> **版本**：1.0
> **创建日期**：2026-07-01
> **前置**：v1.1.0-alpha（tag `v1.1.0-alpha`，含 M2.1 章节回顾 + 批量导出）
> **后续 tag**：`m2.2-complete` + `v1.2.0-alpha`
> **协议**：AGPLv3
> **状态**：设计已与用户确认，待写实施 plan

---

## 1. 背景

M2.1 已交付"手动章节回顾"（TOC 抽屉 + 阅读器溢出菜单触发 `ReviewController.start` → `ReviewPreviewSheet`）。用户读完一章后必须主动找按钮，导致回顾功能实际使用率低。

设计文档 §11.x 把 MVP 2.0 列为"章节学习回顾 + 知识点提炼"。M2.1 已完成"回顾"动作本身，M2.2 补齐"**何时回顾**"的引导：用户翻到一章末页时自动弹出 SnackBar，提供「回顾本章 / 下一章 / 关闭」三个动作。

### 1.1 用户场景

读者用 paged 模式翻完第 5 章最后一页 → SnackBar 弹出："本章已读完？"

- 点【回顾本章】→ 复用 M2.1 ReviewController.start → ReviewPreviewSheet 模态
- 点【下一章】→ engine.nextSpine()
- 点【关闭】或滑动消失 → 仅本次会话不再提示本章

PDF 书也提示，但只显示【下一章 / 关闭】（PDF 单页回顾意义不大）。

## 2. 范围与非目标

### 2.1 范围

- **检测层**：reader_engine 新增 page-level "chapter end" 事件流（paged + scroll 两种模式）
- **去重**：app-side 进程内 `Set<String>` 去重（key = `$bookId:$chapterIdx`）
- **设置**：Settings 页新增「章节结束提示」开关；首次启动时根据 `apiKey != null` 写入默认值
- **UI**：非阻塞 SnackBar（不是模态对话框），三个动作按钮
- **PDF 兼容**：PdfReaderEngine 也发 chapter end 事件，但 UI 隐藏「回顾本章」按钮

### 2.2 非目标（明确不做）

- **跨会话去重**：v1 用内存 Set；用户反馈烦人再加 DB 持久化
- **进度统计卡片**：用户选了 SnackBar，进度卡片留待后续
- **自动连续回顾**（读完一章自动回顾下一章）：YAGNI
- **API key 缺失时的引导 UI**：复用 M2.1 既有错误处理（点"回顾本章"会触发 ReviewError.authFailed）
- **章节切换进行中的提示**：`chapterSwitchSettled` 未完成时忽略事件
- **跨书去重**：换一本书后允许同一章节索引再次提示（不影响）
- **后台触发回顾**：仅在用户当前在 reader 页时触发
- **滚动模式精确"接近底部"阈值调优**：v1 用 `pixels >= maxScrollExtent - 64` 固定阈值
- **Mac 端验证**

## 3. 总体架构

新增 1 个 reader_engine 事件 + 1 个 detector + 1 个 controller + 1 个 widget + 1 个 Settings 项。**零数据库 schema 迁移、零同步逻辑改动**（设置项是 reader 偏好，phase 2 sync 不覆盖）。

```
reader_engine                                app
─────────────                                ───
ReaderEngine (EPUB)                          ChapterEndDetector (service)
  ├─ pageController (paged)                    ├─ subscribe engine.chapterEndEvents
  ├─ scrollController (scroll)                 ├─ dedup Set<String>
  └─ emit ChapterEndEvent ────────────────►  └─ emit PromptRequest
                                                    │
PdfReaderEngine (PDF)                               ▼
  └─ emit ChapterEndEvent ──────────────►  ChapterEndPromptController (provider)
                                                    ├─ read settings.chapter_end_prompt_enabled
                                                    ├─ state: { visible, bookId, chapterIdx, hasReview, hasNext }
                                                    ▼
                                              reader_body watches controller
                                                    ├─ on visible=true → ScaffoldMessenger.showSnackBar
                                                    └─ ChapterEndPromptSnackBar
                                                         ├─ 回顾本章 (hasReview) → ReviewController.start + ReviewPreviewSheet
                                                         ├─ 下一章 (hasNext)    → engine.nextSpine()
                                                         └─ 关闭                → controller.dismiss()
```

## 4. 详细设计

### 4.1 reader_engine 新增 API

**新文件**：`reader_engine/lib/engine/chapter_end_event.dart`

```dart
class ChapterEndEvent {
  const ChapterEndEvent({
    required this.bookId,
    required this.chapterIndex,
    required this.isLastChapter,
  });

  final String bookId;
  final int chapterIndex;
  final bool isLastChapter;
}
```

**修改 `ReaderEngine`** (`reader_engine/lib/engine/reader_engine.dart`)：

新增公开 getter：

```dart
/// Emits a [ChapterEndEvent] when the reader reaches the last page of the
/// current chapter (paged mode) or scrolls to within 64px of the bottom
/// (scroll mode). Fires at most once per chapter visit (debounced internally
/// until the user leaves to a different chapter).
///
/// Listeners are responsible for their own dedup across chapter re-visits.
Stream<ChapterEndEvent> get chapterEndEvents => _chapterEndController.stream;
final StreamController<ChapterEndEvent> _chapterEndController =
    StreamController<ChapterEndEvent>.broadcast();
```

**触发逻辑**（在既有的 `_onPageChanged` / `_onScroll` 钩子尾部）：

```dart
// paged 模式
if (paginationMode == PaginationMode.paged) {
  final breaks = currentChapterPageBreaks;
  if (breaks != null && pageController.page != null) {
    final isLastPage = pageController.page!.round() >= breaks.length - 1;
    if (isLastPage && !_chapterEndFiredForCurrentChapter) {
      _chapterEndFiredForCurrentChapter = true;
      _chapterEndController.add(ChapterEndEvent(
        bookId: bookId,
        chapterIndex: currentChapterIndex,
        isLastChapter: currentChapterIndex >= spine.length - 1,
      ));
    }
  }
}
// scroll 模式
else {
  final pos = scrollController.position;
  if (pos.pixels >= pos.maxScrollExtent - 64 &&
      !_chapterEndFiredForCurrentChapter) {
    _chapterEndFiredForCurrentChapter = true;
    _chapterEndController.add(ChapterEndEvent(...));
  }
}
```

**章节切换时重置内部 flag**（在 `chapterSwitchSettled` 监听器里）：

```dart
chapterSwitchSettled.listen((_) {
  _chapterEndFiredForCurrentChapter = false;
});
```

> **flag 作用**：engine 内部确保**同一次到章末**只 emit 一次（避免 scroll 抖动重复 emit）。app-side `ChapterEndDetector` 的 Set 负责**跨章节访问**去重（用户离开再回来是否再提示）。

**修改 `PdfReaderEngine`** (`reader_engine_pdf_view/lib/pdf_reader_engine.dart`)：

```dart
Stream<ChapterEndEvent> get chapterEndEvents => _chapterEndController.stream;
// 在 onPageChanged 里：当 page == totalPages - 1 时 emit
```

PDF 的 chapter 概念见 M4 设计：每页即一章（Page-as-Chapter）。`chapterIndex = currentPage`，`isLastChapter = currentPage == totalPages - 1`。

### 4.2 ChapterEndDetector 服务

**新文件**：`app/lib/features/reader/services/chapter_end_detector.dart`

```dart
/// Per-session dedup wrapper around [ReaderEngine.chapterEndEvents].
///
/// First visit to a (bookId, chapterIndex) pair emits a [PromptRequest];
/// subsequent visits in the same app session are suppressed. The Set is
/// process-lifetime (cleared on app restart, not on book close).
class ChapterEndDetector {
  ChapterEndDetector(this._engine);

  final ReaderEngine _engine;
  final Set<String> _shownKeys = {};
  final StreamController<PromptRequest> _controller =
      StreamController<PromptRequest>.broadcast();

  Stream<PromptRequest> get promptRequests => _controller.stream;

  void listen() {
    _engine.chapterEndEvents.listen((event) {
      final key = '${event.bookId}:${event.chapterIndex}';
      if (_shownKeys.contains(key)) return;
      _shownKeys.add(key);
      _controller.add(PromptRequest(
        bookId: event.bookId,
        chapterIndex: event.chapterIndex,
        hasReview: _engine is! PdfReaderEngine,
        hasNext: !event.isLastChapter,
      ));
    });
  }

  void dispose() {
    _controller.close();
  }
}

class PromptRequest {
  const PromptRequest({
    required this.bookId,
    required this.chapterIndex,
    required this.hasReview,
    required this.hasNext,
  });

  final String bookId;
  final int chapterIndex;
  final bool hasReview;
  final bool hasNext;
}
```

> **检测 PDF**：通过 `_engine is! PdfReaderEngine` 类型判定（M4 中 PDF 用单独的 engine 类型）。这避免了把 `format` 字段塞进 `ChapterEndEvent`。

### 4.3 ChapterEndPromptController

**新文件**：`app/lib/features/reader/providers/chapter_end_prompt_controller.dart`

```dart
enum ChapterEndPromptVisibility { hidden, visible }

class ChapterEndPromptState {
  const ChapterEndPromptState({
    this.visibility = ChapterEndPromptVisibility.hidden,
    this.bookId = '',
    this.chapterIndex = 0,
    this.hasReview = false,
    this.hasNext = false,
  });

  final ChapterEndPromptVisibility visibility;
  final String bookId;
  final int chapterIndex;
  final bool hasReview;
  final bool hasNext;

  ChapterEndPromptState copyWith({...}) => ...;
}

class ChapterEndPromptController extends StateNotifier<ChapterEndPromptState> {
  ChapterEndPromptController(this._ref, this._engine, this._bookId)
      : super(const ChapterEndPromptState()) {
    _detector = ChapterEndDetector(_engine)..listen();
    _sub = _detector.promptRequests.listen(_onPromptRequest);
  }

  final Ref _ref;
  final ReaderEngine _engine;
  final String _bookId;
  late final ChapterEndDetector _detector;
  late final StreamSubscription<PromptRequest> _sub;

  void _onPromptRequest(PromptRequest req) {
    final enabled = _ref.read(settingsRepositoryProvider
        .get<bool>('chapter_end_prompt_enabled'));
    if (!enabled) return;
    state = ChapterEndPromptState(
      visibility: ChapterEndPromptVisibility.visible,
      bookId: req.bookId,
      chapterIndex: req.chapterIndex,
      hasReview: req.hasReview,
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

> **provider 签名**：family on `(ReaderEngine engine, String bookId)`，因为 detector 与 engine 生命周期绑定。

### 4.4 ChapterEndPromptSnackBar widget

**新文件**：`app/lib/features/reader/widgets/chapter_end_prompt_snackbar.dart`

```dart
class ChapterEndPromptSnackBar extends SnackBar {
  ChapterEndPromptSnackBar({
    super.key,
    required BuildContext context,
    required bool hasReview,
    required bool hasNext,
    required VoidCallback onReview,
    required VoidCallback onNext,
    required VoidCallback onDismiss,
  }) : super(
          content: Text(AppLocalizations.of(context)!.chapterEndPromptMessage),
          duration: const Duration(seconds: 12),
          action: (hasReview && hasNext)
              ? SnackBarAction(label: ..., onPressed: onReview)  // 主 action
              : null,
          behavior: SnackBarBehavior.floating,
        );
}
```

> **3 个按钮的限制**：`SnackBar` 只支持单个 `action`。设计调整为：
> - 文案行：「本章已读完？」
> - 主 action：回顾本章（仅 EPUB）
> - 末尾追加内联按钮行（用 Row 包装）：[下一章] [关闭]
> - 实际 widget 用 `Wrap` + 多个 TextButton，避开 SnackBarAction 限制
>
> 实施时用 `SnackBar(content: Row(children: [Text, Spacer, ...buttons]))` 自定义。

### 4.5 Settings 开关

**修改 `app/lib/features/settings/pages/settings_page.dart`**：

在"阅读"section 末尾加 `SwitchListTile`：

```dart
SwitchListTile(
  title: Text(l10n.settingsChapterEndPrompt),
  subtitle: Text(l10n.settingsChapterEndPromptSubtitle),
  value: settingsAsync.maybeWhen(
    data: (s) => s['chapter_end_prompt_enabled'] as bool? ?? _defaultEnabled,
    orElse: () => _defaultEnabled,
  ),
  onChanged: (v) => ref.read(settingsRepositoryProvider).upsert(
    'chapter_end_prompt_enabled', v,
  ),
)
```

**默认值算法**（在 SettingsRepository 启动初始化里）：

```dart
Future<void> ensureDefaults() async {
  final existing = await getOrNull('chapter_end_prompt_enabled');
  if (existing == null) {
    final hasApiKey = (await _apiKeyStore.get()) != null;
    await upsert('chapter_end_prompt_enabled', hasApiKey);
  }
}
```

### 4.6 reader_body 接线

**修改 `app/lib/features/reader/pages/reader_body.dart`**：

```dart
// 1. 在 build 里 watch prompt controller
final promptState = ref.watch(chapterEndPromptControllerProvider(engine, bookId));

// 2. 用 ref.listen 监听 visible 状态变化 → 弹 SnackBar
ref.listen<ChapterEndPromptState>(
  chapterEndPromptControllerProvider(engine, bookId),
  (prev, next) {
    if (next.visibility == ChapterEndPromptVisibility.visible &&
        (prev?.visibility ?? ChapterEndPromptVisibility.hidden) ==
            ChapterEndPromptVisibility.hidden) {
      _showChapterEndPrompt(next);
    }
  },
);

// 3. _showChapterEndPrompt 实现
void _showChapterEndPrompt(ChapterEndPromptState s) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(ChapterEndPromptSnackBar(
      context: context,
      hasReview: s.hasReview,
      hasNext: s.hasNext,
      onReview: () {
        ref.read(chapterEndPromptControllerProvider(engine, bookId).notifier)
            .dismiss();
        _onOpenReview(s.chapterIndex);  // 复用 M2.1 既有方法
      },
      onNext: () {
        ref.read(chapterEndPromptControllerProvider(engine, bookId).notifier)
            .dismiss();
        engine.nextSpine();
      },
      onDismiss: () {
        ref.read(chapterEndPromptControllerProvider(engine, bookId).notifier)
            .dismiss();
      },
    ));
}
```

> **复用 `_onOpenReview`**：M2.1 已有的方法（在 TOC drawer "回顾本章"和溢出菜单"回顾本章"中共用），M2.2 不重写。

## 5. 数据流

```
1. 用户翻到一章最后一页（paged）或滚到底部（scroll）
2. ReaderEngine 检测 → 内部 flag 已置位 → emit ChapterEndEvent
3. ChapterEndDetector 接收
   ├─ 计算 key = "$bookId:$chapterIdx"
   ├─ Set 已包含 → 直接 return（不 emit）
   └─ Set 不含 → 加入 Set → emit PromptRequest
4. ChapterEndPromptController._onPromptRequest 接收
   ├─ 读 settings.chapter_end_prompt_enabled
   ├─ disabled → return
   └─ enabled → state.visibility = visible + 元数据
5. reader_body ref.listen 触发 → ScaffoldMessenger.showSnackBar
6. 用户操作：
   - 回顾本章 → controller.dismiss() + _onOpenReview(chapterIdx) (M2.1)
   - 下一章   → controller.dismiss() + engine.nextSpine()
   - 关闭     → controller.dismiss()
   - 12 秒超时 → SnackBar 自动消失（state 仍是 visible，但用户已不可见）
                下次进同一章 detector 已记录，不会再触发
```

## 6. 错误与边界

| 场景 | 处理 |
|---|---|
| **设置读取失败** | `SettingsRepository.get<T>(key, defaultValue)` 已有容错，返回 defaultValue |
| **API key 临时失效**（用户清空了 key） | SnackBar 仍弹；点"回顾本章"触发 ReviewError.authFailed（M2.1 既有处理） |
| **engine 未就绪** | detector 在 controller 构造时 listen；engine ready 是 ReaderEngine 构造前提，不会出现"未就绪" |
| **chapter switch 进行中** | engine 内部 flag 在 `chapterSwitchSettled` 时重置；settled 之前不会 emit |
| **同章多次到末页**（用户来回翻） | engine 内部 flag 一次访问内只 emit 一次 |
| **用户离开再回来**（同一章） | app-side Set 已记录，本次会话不再提示；下次启动可再提示 |
| **PDF 最后一页** | emit event；hasReview=false；SnackBar 只显示【下一章】+【关闭】；isLastChapter=true 时 hasNext=false → SnackBar 不显示（无事可做） |
| **EPUB 最后一章最后一页** | isLastChapter=true, hasNext=false；hasReview=true → SnackBar 显示【回顾本章】+【关闭】 |
| **同时多个提示竞争** | 不可能：page-level 检测每次只在一章末触发一次 |
| **SnackBar 已显示，新事件又来**（理论不可能，但防御） | `ScaffoldMessenger.hideCurrentSnackBar()` 先隐藏再 show |
| **用户在 SnackBar 显示期间切章** | controller.dismiss() 不一定被调用；下次 emit 时 ref.listen 触发新 SnackBar，旧的自然消失 |
| **设置切换** | 立即生效：当前会话后续事件按新设置走；已显示的 SnackBar 不强制消失（用户主动 dismiss） |

## 7. 测试策略

| 层 | 测试 | 数量 |
|---|---|---|
| **reader_engine** | ChapterEndEvent 数据类 | 1 |
| | paged 模式翻到最后一页 emit 一次 | 1 |
| | paged 模式中间页不 emit | 1 |
| | scroll 模式到底部 emit 一次 | 1 |
| | scroll 模式中间不 emit | 1 |
| | 同次访问多次到末页只 emit 一次（flag） | 1 |
| | chapterSwitchSettled 后 flag 重置 | 1 |
| | PdfReaderEngine 末页 emit | 1 |
| **ChapterEndDetector** | 首次接收 emit PromptRequest | 1 |
| | 同 (book, chapter) 二次接收 return（不 emit） | 1 |
| | 不同 chapter emit | 1 |
| | PDF engine → hasReview=false | 1 |
| | EPUB engine → hasReview=true | 1 |
| | isLastChapter → hasNext=false | 1 |
| **ChapterEndPromptController** | disabled 设置 → 不更新 state | 1 |
| | enabled → state.visibility=visible | 1 |
| | dismiss → state.visibility=hidden | 1 |
| **widget** | EPUB 显示 3 按钮（回顾/下一章/关闭） | 1 |
| | PDF 显示 2 按钮（下一章/关闭） | 1 |
| | 最后一章 EPUB 显示 2 按钮（回顾/关闭） | 1 |
| | 按钮点击回调正确 | 3（每个按钮 1） |
| **integration** | 翻到末页 → SnackBar 弹出 → 点回顾 → ReviewPreviewSheet 显示 | 1 |
| | 翻到末页 → SnackBar → 点下一章 → 切章 | 1 |
| | Settings 关闭 → 翻到末页 → 不弹 | 1 |

**预计新增 ~25 测试。** 无既有测试需要修改（reader_engine API 纯新增，detector/controller 是新文件）。

## 8. 文件清单

| 操作 | 文件 | 行数估算 | 责任 |
|---|---|---|---|
| 新增 | `reader_engine/lib/engine/chapter_end_event.dart` | ~25 | ChapterEndEvent 数据类 |
| 修改 | `reader_engine/lib/engine/reader_engine.dart` | +40 | emit signal + 内部 flag + chapterSwitchSettled 重置 |
| 修改 | `reader_engine/lib/engine/reader_engine.dart` 导出 | +1 | barrel 文件加导出 |
| 修改 | `reader_engine_pdf_view/lib/pdf_reader_engine.dart` | +20 | emit signal |
| 新增 | `app/lib/features/reader/services/chapter_end_detector.dart` | ~70 | per-session dedup + PromptRequest |
| 新增 | `app/lib/features/reader/providers/chapter_end_prompt_controller.dart` | ~90 | StateNotifier + settings gate |
| 新增 | `app/lib/features/reader/widgets/chapter_end_prompt_snackbar.dart` | ~90 | 自定义 SnackBar content |
| 修改 | `app/lib/features/reader/pages/reader_body.dart` | +25 | ref.listen + showSnackBar + 复用 _onOpenReview |
| 修改 | `app/lib/features/settings/pages/settings_page.dart` | +20 | SwitchListTile |
| 修改 | `app/lib/services/storage/settings_repository.dart` | +15 | ensureDefaults 启动初始化 |
| 修改 | `app/lib/l10n/app_zh.arb` | +6 | 6 个新 key |
| 修改 | `app/lib/l10n/app_en.arb` | +6 | 6 个新 key |
| 新增 | `reader_engine/test/chapter_end_event_test.dart` | ~120 | 7 个 engine 测试 |
| 新增 | `app/test/features/reader/services/chapter_end_detector_test.dart` | ~100 | 6 个 detector 测试 |
| 新增 | `app/test/features/reader/providers/chapter_end_prompt_controller_test.dart` | ~80 | 3 个 controller 测试 |
| 新增 | `app/test/features/reader/widgets/chapter_end_prompt_snackbar_test.dart` | ~120 | 6 个 widget 测试 |
| 新增 | `app/test/features/reader/chapter_end_prompt_integration_test.dart` | ~120 | 3 个 integration 测试 |

**总计：5 个新文件（lib）+ 4 个新文件（test）+ 6 个修改文件 + ~22 测试**

## 9. i18n key 清单

新增到 `app_zh.arb` + `app_en.arb`：

```json
"chapterEndPromptMessage": "本章已读完？",
"chapterEndPromptReview": "回顾本章",
"chapterEndPromptNext": "下一章",
"chapterEndPromptDismiss": "关闭",
"settingsChapterEndPrompt": "章节结束提示",
"settingsChapterEndPromptSubtitle": "翻到一章末页时提示回顾"
```

## 10. 开放问题

无。所有设计决策已通过 brainstorming 阶段确认：

1. **触发动作**：回顾本章 + 下一章（双选）
2. **检测层**：page-level（reader_engine 新增事件）
3. **去重**：per-chapter 会话内 Set
4. **默认状态**：API key 存在时默认开
5. **设置位置**：Settings 页
6. **PDF 处理**：提示但只显示「下一章」
7. **提示 UI**：SnackBar
8. **回顾路径**：直接调起 ReviewController + ReviewPreviewSheet（无 Confirm dialog）

## 11. 实施顺序（plan 任务拆分参考）

1. **Task 1**：reader_engine 新增 `ChapterEndEvent` 类 + barrel 导出 + 测试
2. **Task 2**：ReaderEngine emit signal（paged + scroll + flag + settled 重置）+ 测试
3. **Task 3**：PdfReaderEngine emit signal + 测试
4. **Task 4**：ChapterEndDetector service + 测试
5. **Task 5**：ChapterEndPromptController + 测试
6. **Task 6**：ChapterEndPromptSnackBar widget + 测试
7. **Task 7**：i18n key + Settings 开关 + SettingsRepository.ensureDefaults + 测试
8. **Task 8**：reader_body 接线 + integration 测试
9. **Task 9**：M2.2 完成验证（全量测试 + analyze + 手测）+ tag

## 12. 验收标准

- [ ] 全量测试通过（既有 762 + 新增 ~22 = ~784 passed）
- [ ] `dart analyze` 0 errors / 0 warnings
- [ ] paged + scroll 两模式翻到末页均能弹出 SnackBar
- [ ] PDF 末页 SnackBar 隐藏"回顾本章"按钮
- [ ] 最后一章 SnackBar 隐藏"下一章"按钮
- [ ] 同一章二次访问本次会话不再弹
- [ ] Settings 关闭后立即生效（下次到末页不弹）
- [ ] API key 未配置时首次启动默认 OFF
- [ ] API key 已配置时首次启动默认 ON
- [ ] 点"回顾本章"复用 M2.1 ReviewPreviewSheet
- [ ] 点"下一章"调 engine.nextSpine()
- [ ] commit message 遵循 `feat(m2.2/tN): ...` 格式
- [ ] 每个 commit 都推送到 gitee
- [ ] 完成时打 tag `m2.2-complete` + `v1.2.0-alpha`

---

> **依赖**：M2.1（ReviewController、ReviewPreviewSheet、_onOpenReview、BookReviewer）必须已交付。已确认（v1.1.0-alpha 已 tag）。
>
> **风险**：reader_engine 内部 flag 重置依赖 `chapterSwitchSettled` 正确触发；既有 M3.x 已验证此信号稳定。
>
> **回滚**：纯新增代码，回滚仅需 revert commit；无 schema 迁移、无持久化数据依赖。
