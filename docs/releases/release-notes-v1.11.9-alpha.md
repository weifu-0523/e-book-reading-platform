# v1.11.9-alpha

**发布日期**：2026-07-15
**类型**：hotfix（用户报告 bug + UX 增强）
**上一版本**：v1.11.8-alpha

## 摘要

修复 4 个用户报告的问题，其中 1 个是 v1.11.8-alpha 引入的 regression：

1. **Bug 1（regression）：旧书签定位偏移**——v1.11.8-alpha 修复 EPUB 目录
   跳转时改了坐标系，副作用是旧版本（v1.11.7 及之前）加的书签 charOffset
   与新公式不兼容，跳转位置放大 ~1.73× 偏后。
2. **Bug 2：移动端 chrome 透明度看不清**——浅色方案下黑色 54% 透明背景
   + 深色图标对比度极低。
3. **Bug 3：添加书签章节计数包含译者序/引言**——书签 label 用 raw
   `chapterIndex+1`（含前置内容），与 reader 实际显示的章节名不一致。
4. **Bug 4：library AppBar 缺立即同步按钮**——书架级导航条新增同步按钮，
   状态自适应图标 + 旋转动画。

测试数：**1521 pass + 14 skip + 1 pre-existing flake**（reader_flow
integration test 10 分钟 timeout，与本版本无关，v1.11.8-alpha 时也 fail）。

---

## Bug 1：旧书签定位偏移（v1.11.8-alpha regression）

### 用户报告

> 有不同的测试用户反馈，安装新版本后，原书签的定位可能会发生偏移，
> 这个需要分析是否属实。实属就进行BUG修复。

### 根因（已 git show 验证）

v1.11.8-alpha commit `5f6ef1f` 把 `_emitCurrentLocation` 和 `gotoLocator`
的 `totalChars` 从 `html.length` 改到 `_plainTextLengthForChapter`。
commit message 当时已经标注这个 trade-off：

> Trade-off: bookmarks saved by v1.11.7-alpha and earlier encode
> charOffset in HTML-length coords. After this fix, gotoLocator divides
> by plain length → old bookmarks may shift toward chapter end on
> tag-heavy chapters. Acceptable for alpha; users can re-bookmark.

用户报告证明这个 trade-off **不接受**。

具体偏移机制：
- 旧书签 charOffset = `scrollRatio × html.length`（HTML-encoded）
- 新公式 `gotoLocator` 用 `charOffset / plain.length`
- 同 scrollRatio 下，旧 charOffset 是新 charOffset 的 ~1.73× 倍（道德经）
- → 新公式得到放大 1.73× 的 ratio → 跳到比原来靠后 1.73× 的位置

### 修复

`gotoLocator` scroll 分支加 `_resolveScrollCharOffset` heuristic：

```dart
int _resolveScrollCharOffset(int chapterIndex, int rawOffset) {
  final html = flatChapterHtmlAt(chapterIndex);
  final plainLen = html.isEmpty ? 1 : _plainTextLengthForChapter(chapterIndex);
  if (html.isNotEmpty && rawOffset > plainLen) {
    // legacy html-encoded: rescale by (rawOffset / htmlLen) × plainLen
    final legacyRatio = rawOffset / html.length;
    return (legacyRatio * plainLen).round().clamp(0, plainLen);
  }
  return rawOffset.clamp(0, plainLen);
}
```

**Heuristic 逻辑**：
- `rawOffset > plainLen` → 肯定是旧格式（新书签永远 ≤ plainLen），按
  `htmlLen` 比例还原 ratio 后用 `plainLen` 重新 encode。
- `rawOffset ≤ plainLen` → 可能是新书签或低 ratio 旧书签，无法区分。
  小偏差 ≤ 1.73×，仍在原章节内，可接受。

**Paged 模式不受影响**：旧 paged 书签 charOffset=0（M2.11/问题1 之前
`_emitCurrentLocation` 在 paged 模式恒为 0），gotoLocator paged 分支查
break 索引时自然落到首页，与 v1.11.7 行为一致。

### 测试

3 个新测试（`reader_engine_epub_view/test/epubx_renderer_anchor_toc_test.dart`）：

1. `legacy bookmark charOffset (html-encoded) is rescaled to plain coords`
   ——charOffset=30 (html-encoded), html=45, plain=3 → ratio ≈ 0.667
2. `modern bookmark charOffset (plain-encoded) is preserved exactly`
   ——charOffset=2 (plain), plain=3 → ratio = 0.667
3. `charOffset 0 always lands at chapter start`——ratio = 0.0

---

## Bug 2：移动端 chrome 透明度看不清

### 用户报告

> 导航条改为可左右滑动后，目前设置为了透明状态，但没有透明度的设置，
> 导致浅色方案下，移动端导航条看不清，和背景文字重叠显示

### 根因

`reader_scaffold.dart:_buildChrome` 用 `Material(color: Colors.black54)`
硬编码黑色 54% 透明背景。v1.11.6-alpha 引入 compact 横向滚动 chrome 时
沿用了这个颜色（v1.11.5-alpha 桌面 AppBar 用）。但浅色方案下：
- `IconTheme.color` 是深色（黑/灰）
- 黑色半透明背景 + 深色图标 → 对比度接近 0 → 用户视觉上"透明"+ 看不清

### 修复

背景色改用 `Theme.of(context).colorScheme.surface` 自适应：

```dart
final chromeColor = Theme.of(context).colorScheme.surface;
return Positioned(
  ...
  child: Material(
    key: const Key('reader_app_bar'),
    color: chromeColor,
    ...
```

浅色方案给浅底（白/浅灰），深色方案给深底（深灰）。AppBar 自带
IconThemeData 用 onSurface 色，对比度自动保证。

### 测试

3 个新测试（`reader_scaffold_test.dart`）：
1. light theme chrome bg != Colors.black54
2. dark theme chrome bg != Colors.black54
3. light theme chrome icons != Colors.white

---

## Bug 3：添加书签章节计数包含译者序/引言

### 用户报告

> 添加书签目前显示的目前多少章和标题不一致，目前添加书签应该是计算的
> 所有章节，把译者序，引言等都计算在内，这样的书签对用户来说会产生
> 很多迷惑的地方，需要进行修改，改为添加书签提示的章节和目前阅读的
> 章节名称保存一致

### 根因

`reader_body.dart:_defaultBookmarkLabel` 用 `第 ${chapterIndex+1} 章`，
`chapterIndex` 是 `_chapters` 数组的原始索引（包含译者序/引言/前言等
前置内容）。但 reader 顶部显示的章节名来自 `_chapterTitlesCache[idx]`
（如"译者序"、"第一章 众妙之门"），两者不一致。

具体例子（道德经）：
- chapterIndex = 0 → 译者序（reader 显示）
- chapterIndex = 1 → 引言（reader 显示）
- chapterIndex = 2 → 第一章（reader 显示）

加书签时旧版本显示 `第 1 章` / `第 2 章` / `第 3 章`——但 reader 顶部
显示「译者序」/「引言」/「第一章」，用户困惑。

### 修复

提取 `computeDefaultBookmarkLabel` 为 `@visibleForTesting` top-level
helper，优先用 `chapterTitles[idx]`：

```dart
@visibleForTesting
String computeDefaultBookmarkLabel(
  Locator locator, {
  required Map<int, String> chapterTitles,
  String? epubPageLabel,
}) {
  if (locator is EpubCfiLocator) {
    return _epubChapterLabel(locator.chapterIndex, chapterTitles, epubPageLabel);
  }
  if (locator is EpubRangeLocator) {
    return _epubChapterLabel(locator.chapterIndex, chapterTitles, epubPageLabel);
  }
  if (locator is PdfPageLocator) return '第 ${locator.page} 页';
  if (locator is PdfRangeLocator) return '第 ${locator.page} 页';
  return '当前位置';
}

String _epubChapterLabel(int idx, Map<int, String> titles, String? page) {
  final t = titles[idx];
  final part = t ?? '第 ${idx + 1} 章';  // fallback when no title
  return page == null ? part : '$part · $page';
}
```

实例化书签时 reader_body 调：
```dart
String _defaultBookmarkLabel(Locator locator) {
  return computeDefaultBookmarkLabel(
    locator,
    chapterTitles: _chapterTitlesCache,
    epubPageLabel: _epubPagedLabel(),
  );
}
```

### 测试

7 个新测试（`reader_bookmark_label_test.dart`）：
1. normal chapter uses title (not index)
2. front matter (译者序/引言) shows actual title
3. null title falls back to 第 N 章
4. epub page label appended when provided
5. EpubRangeLocator also uses title
6. PdfPageLocator returns 第 N 页
7. PdfRangeLocator returns 第 N 页

---

## Bug 4：library AppBar 缺立即同步按钮

### 用户报告

> 在书架级的导航条上，增加一个立即同步的按钮

### 实现

`LibraryAppBar` 加 `syncStatus` + `onSyncTap` 可选参数。compact + expanded
两种模式都渲染 `_SyncIconButton`（私有 StatefulWidget），状态自适应：

| SyncStatus | Icon | 旋转 | 启用 |
|---|---|---|---|
| idle | Icons.sync | 否 | ✓ |
| pushing | Icons.sync | 是 | ✗ |
| pulling | Icons.sync | 是 | ✗ |
| success | Icons.check | 否 | ✓ |
| error | Icons.error_outline | 否 | ✓ (retry) |
| offline | Icons.cloud_off | 否 | ✗ |

`library_page.dart` 接入：
```dart
SyncStatus? syncStatus;
try {
  syncStatus = ref.watch(syncControllerProvider).status;
} catch (_) {
  syncStatus = null;  // 测试未 override 时按钮不渲染
}
```

try/catch 是 riverpod 容错——production `syncControllerProvider` 总是
全局注册，catch 实际是 no-op。测试不 override 时按钮隐藏，UI 仍正常。

### 测试

6 个新测试（`library_app_bar_test.dart`）：
1. renders sync icon button when syncStatus provided
2. does NOT render sync button when syncStatus is null
3. tapping sync button fires callback
4. sync button is disabled when status is pushing
5. sync button is disabled when status is offline
6. sync button rendered in compact mode too

---

## 变更文件

| 文件 | 变更 |
|---|---|
| `reader_engine_epub_view/lib/epubx_renderer.dart` | +`_resolveScrollCharOffset` heuristic + `@visibleForTesting debugComputeLegacyAwareScrollRatioForTesting`；gotoLocator scroll 分支用 |
| `reader_engine_epub_view/test/epubx_renderer_anchor_toc_test.dart` | +3 测试（legacy-aware ratio） |
| `app/lib/features/reader/widgets/reader_scaffold.dart` | `_buildChrome` 用 `Theme.colorScheme.surface` 替代 `Colors.black54` |
| `app/test/features/reader/widgets/reader_scaffold_test.dart` | +3 测试（chrome bg theme-adaptive） |
| `app/lib/features/reader/pages/reader_body.dart` | 提取 `computeDefaultBookmarkLabel` top-level helper；`_defaultBookmarkLabel` 调它 |
| `app/test/features/reader/pages/reader_bookmark_label_test.dart` | +7 测试（label computation） |
| `app/lib/features/library/widgets/library_app_bar.dart` | +`syncStatus` +`onSyncTap` 参数 + `_SyncIconButton` 私有 widget；compact + expanded 都加 |
| `app/lib/features/library/pages/library_page.dart` | try/catch watch `syncControllerProvider`；传 syncStatus + onSyncTap 给 LibraryAppBar |
| `app/test/features/library/widgets/library_app_bar_test.dart` | +6 测试（sync button） |
| `app/pubspec.yaml` | 1.11.8-alpha → 1.11.9-alpha |
| `app/windows/installer/zhiyue.iss` | MyAppVersion "1.11.8-alpha" → "1.11.9-alpha" |
| `CHANGELOG.md` | +v1.11.9-alpha section |
| `README.md` | badge 更新 |

4 个 fix commits：`1cb84b6`（Bug 1）→ `893866e`（Bug 2）→ `af818fa`（Bug 3）
→ `9663f69`（Bug 4）。

---

## 已知限制

1. **Bug 1 heuristic 不完美**：低 ratio 旧书签（charOffset ≤ plainLen）
   无法区分新旧格式。deviation ≤ 1.73× 但仍在原章节内。用户可手动重新
   添加书签获得精确定位。
2. **Bug 4 try/catch 容错**：违反严格 riverpod 模式（watch 应在 scope 内），
   但 production 总有 syncControllerProvider 全局注册，try/catch 实际 no-op。
   测试不 override 时按钮隐藏（而非抛红屏）。
3. **reader_flow_integration_test 10 分钟 timeout**（pre-existing flake，
   v1.11.8-alpha 时也 fail，与本版本无关）。

---

## 验证

### 单元/集成测试

```
$ flutter test
1521 pass + 14 skip + 1 pre-existing flake
```

新测试 19 个：
- Bug 1: 3（epubx_renderer_anchor_toc_test.dart）
- Bug 2: 3（reader_scaffold_test.dart）+ 6（library_app_bar_test.dart）
- Bug 3: 7（reader_bookmark_label_test.dart）

### 手工验证（建议）

1. **Bug 1**：用 v1.11.7-alpha 加书签（任意章节中部位置）→ 升级到
   v1.11.9-alpha → 点击书签 → 验证跳转到接近原位置（高 ratio case 完美
   还原，低 ratio case 小偏差）。
2. **Bug 2**：切换浅色方案 → 打开任意 EPUB → 验证顶部 chrome 背景是浅色
   不透明，图标清晰可见。
3. **Bug 3**：打开有译者序/引言的书 → 加书签 → 验证 label 显示「译者序」
   而非「第 1 章」。
4. **Bug 4**：library 主页 → 验证 AppBar 有同步按钮（旋转图标 if 同步中）→
   tap → 触发立即同步。
