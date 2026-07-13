# v1.11.5-alpha

**发布日期**：2026-07-13
**类型**：hotfix
**上一版本**：v1.11.4-alpha

## 摘要

修复用户报告的《老子道德经-老子》EPUB 目录跳转失效问题。点击任何目录
条目都没有反应，且该书「似乎没有分章节」。

根因：Calibre 生成的 EPUB 采用 `#fileposNNNNN` 锚点约定——所有章节
塞进单个 html 文件，靠 `<p id="fileposNNNNN">` 元素区分章节边界。
渲染器两层缺陷导致锚点 TOC 失效。

## 根因

### Calibre EPUB 的目录约定

Calibre（一款流行的开源 EPUB 编辑器）生成的 EPUB 不一定每个章节
一个 html 文件。对于章节多但每章短的书（如《道德经》81 章），Calibre
倾向把所有章节合并到少数几个 html 文件（如 `index_split_001.html`），
然后用 NCX 里的 `<navPoint>` 列出每章的标题 + 锚点：

```xml
<navPoint id="np1" playOrder="1">
  <navLabel><text>前言</text></navLabel>
  <content src="index_split_001.html#filepos10737"/>
</navPoint>
<navPoint id="np2" playOrder="2">
  <navLabel><text>道经</text></navLabel>
  <content src="index_split_001.html#filepos16682"/>
</navPoint>
<navPoint id="np3" playOrder="3">
  <navLabel><text>第一章 众妙之门</text></navLabel>
  <content src="index_split_001.html#filepos16764"/>
</navPoint>
...
```

对应 html 文件：

```html
<p id="filepos10737">前言内容</p>
<p id="filepos16682">道经标题</p>
<p id="filepos16764">第一章 众妙之门</p>
<p>第一章正文</p>
```

### 渲染器两层缺陷

**缺陷 1**：epubx 解析 NCX 时把每个 navPoint 当独立章节（带
`ContentFileName = 'index_split_001.html'` + `Anchor = 'filepos16682'`）。
渲染器原样信任，把同一 html 文件加载到 `_chapters` 80+ 次——既浪费
内存，也让 `chapterCount` 严重虚高（用户感知「没有分章节」其实是因为
所有虚章节共享同一 html，翻页内容不变）。

**缺陷 2**：`_chaptersToToc` 给每个 navPoint 生成 locator 时只用
flat index + charOffset 0：

```dart
EpubCfiLocator(cfi: encode(flatIdx, 0), chapterIndex: flatIdx)
```

`Anchor` 字段完全被忽略。locator 永远是 `'N:0'`——`gotoLocator`
跳到「虚拟章节 N 的字符 0」，但所有虚拟章节内容相同，结果都是章首。

## 修复（3 层）

### T1：PlainTextUtils.anchorToPlainOffset

`reader_engine_epub_view/lib/plain_text_utils.dart` 新增静态方法：

```dart
static int? anchorToPlainOffset(String html, String anchor) {
  // 1. 正则找 id="anchor" 或 name="anchor"（case-insensitive）
  // 2. lastIndexOf('<', attrStart) 定位元素起始
  // 3. htmlToPlainWithOffsets(html) 拿到 offsets 数组
  // 4. 二分查找 ≤ htmlOffset 的最大 plain index + 1
}
```

返回值与 `cfi_codec` 的 `charOffset` 同坐标系。

### T2：EpubxRenderer 章节去重

`reader_engine_epub_view/lib/epubx_renderer.dart` 新增：

```dart
Map<String, int> _contentFileToChapterIndex = {};

List<HtmlChapterSource> _buildDedupedChaptersAndMap(
  List<EpubChapter> flat,
  EpubImageInliner? inliner,
) {
  // 按 ContentFileName 去重，第一个出现的 file 保留为新章节
  // 反查 map：file → 新章节的 index
}
```

`openFile` / `bookForTesting` / `openChapters` 都调此 helper。80 个共享
`index_split_001.html` 的 navPoints → 1 个 `_chapters` 条目。

### T3：_chaptersToToc 改写

```dart
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

TOC 条目「第一章 众妙之门」（`#filepos16764`）的 locator 变成
`0:8`（去重章 0 的字符偏移 8）。`gotoLocator` 滚动到正确位置。

## 决策

### 为何在渲染器层去重而非改 epubx

epubx 把每个 navPoint 解析为 `EpubChapter`（带 `Anchor` 字段）是
正确的——保留 NCX 的完整层级与标题。问题在渲染器没正确处理
「共享 ContentFile」语义。

修复在渲染器层：
- 保留 epubx 输出的所有 `EpubChapter`（标题不丢）
- 渲染层按 `ContentFileName` 去重（避免重复加载）
- TOC 层保留所有 navPoint（每个有独立 locator）
- locator 用 dedupedIdx + anchor charOffset（点击跳到正确位置）

这样既能渲染（去重章节），又能 TOC 跳转（每条独立位置）。

### 为何 anchorToPlainOffset 用 regex 而非 HTML AST

考虑过用 `package:html` 解析 html 后 walk DOM 找 id/name。但：

1. **性能**：`package:html` 解析 50KB+ html 比 regex 慢 10-100x
2. **EPUB html 已是合法 XML**（OPF 规范要求），不需要错误恢复
3. **锚点 id 是字面字符串**：`filepos16764` 没有特殊字符（不需要
   HTML entity 解码、不需要命名空间处理）
4. **已有 `htmlToPlainWithOffsets`** 用 regex 处理，一致风格

regex + lastIndexOf('<') + 二分查找的方案对 Calibre 锚点约定足够。

**已知限制**：锚点 id 出现在 HTML 注释 `<!-- -->` 或 `<script>` 字符串
里会误匹配。Calibre EPUB 不存在此问题。记入 docstring。

### 为何 dedupedIdx ?? 0 而非 throw

如果 `ContentFileName` 不在 map 中（test fixture 异常情况、未来
epubx 输出变体），fallback 到 dedupedIdx = 0 + charOffset = 0。
不 crash，TOC 跳到第一章节首——可预测的降级行为。

## 测试

新增 14 个测试：

| 任务 | 测试数 | 文件 | 覆盖 |
|---|---|---|---|
| T1 | 6 | `plain_text_utils_test.dart` | null / 0 / 中间 / 空格 / Calibre 文件位置 / 单引号 |
| T2 | 2 | `epubx_renderer_test.dart` | 3 navPoints 共享 html → 1 章节 / 不同文件 → 2 章节 |
| T3 | 6 | `epubx_renderer_anchor_toc_test.dart`（新文件） | 共享文件 dedup / null anchor / 锚点解析 / 缺失锚点回退 / gotoLocator 不 crash |

T3 测试 fixture 精确模拟《道德经》Calibre 结构：3 navPoints 共享
`index_split_001.html` + `#filepos16682` / `#filepos16764` 锚点。

**总测试**：
- renderer 包：206 pass + 8 skip + 15 baseline fail
- app 包：1449 pass + 14 skip + 10 baseline fail

baseline fail 全部 pre-existing（paged/dual-mode widget 测试 + reader_page
chrome 编译错误），与本次改动无关。

## 已知限制

- **HTML 注释/CDATA 误报**：`anchorToPlainOffset` regex 不解析 HTML
  AST。如果锚点 id 出现在注释或 script 字符串里，会误匹配。Calibre
  EPUB 不存在此问题。记入 docstring 限制部分。
- **属性值含 `<`**：继承自 `htmlToPlainWithOffsets` 的限制。
- **paged 模式跳转精度**：scroll 模式按 charOffset / totalChars ×
  maxScrollExtent 比例跳转，精确。paged 模式跳到包含该 offset 的页——
  章内页边界可能差 1 页（pre-existing paged 限制）。

## 升级指引

直接覆盖安装即可。无 schema 变更，无配置变更。

打开 v1.11.5-alpha 后：

- **Calibre 风格 EPUB 目录正常跳转**：《道德经》《论语》等单 html 多
  锚点 EPUB 点击目录条目跳到对应位置（不再卡在章首）。
- **其他 EPUB/PDF/MD/TXT 不受影响**：标准 EPUB（每章独立 html 文件）
  去重后 chapterIndex 与原一致；PDF/MD/TXT 不走 epubx 路径。
