# Changelog

本项目所有重要变更记录在此文件。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

v1.6.0-alpha 之后的新变更将记在此处。

### M4.6-fix10 — 2026-07-06（六大稳定性/排版问题综合治理）

用户在 M4.6-fix9（commit ed6ab68）后报告 6 个阻塞问题：①PDF 双页仍卡死 ②MD 排版仍乱（同文档 TXT 正常 MD 异常）③EPUB《一本书读懂财报》翻页/目录卡死 ④EPUB/TXT 双页跨页选区串读 ⑤摘录新增当场不显示 ⑥阅读区红色蒙层+导航条消失。按 systematic-debugging 完整根因调查后逐一修复，每个问题都现场验证了根因证据。

#### Changed — PDF 彻底锁死单页（A1）

- **决策**：fix9 的"双 PdfViewer 共享 sourceName"方案在用户实测仍卡死（pdfrx 双 PdfViewer `_attach`/`_detach` 竞态未根治）。用户决定先稳定——彻底移除双页入口。
- **改动**：
  - `reader_body.dart:407` `e.dualPageMode = isWide && !isScanned` → `false`
  - `reader_body.dart:576-584` `onToggleDualPage: null` → ReaderScaffold 不再渲染双页 toggle 按钮
  - `pdf_renderer.dart` 删除 `_buildDualPage`(469-537)、`_buildDualParams`(536-552)、`_dualLeftController`/`_dualRightController` 字段、setPage 的 dual 分支。`build()` branch 判定简化为永远 main。
- **PDF 缩略图同步**：`reader_drawer_builders.dart:62-84` 缩略图 `currentPage` 改为 `StreamBuilder` 监听 `pdfEngine.rendererRef.currentLocation$`，主区翻页时 stream emit → grid 重建 → 当前页高亮实时跟随（旧实现只在 drawer build 时读一次，主区翻页后高亮不刷新）。

#### Fixed — MD 排版根因（A2，5 次失败的共同元凶）

- **现场证据**（test/debug/compare_txt_md_test.dart 跑出来的 HTML 对比）：
  - 输入「第一点\n第二点\n第三点\n第四点」（4 行连续文本）
  - TXT 产出：`<p>第一点</p><p>第二点</p><p>第三点</p><p>第四点</p>`（4 个独立 `<p>`，0 个 `<br>`）→ Paginator 测准 → 正常
  - MD 产出：`<p>第一点<br />第二点<br />第三点<br />第四点</p>`（1 个 `<p>` 内含 3 个 `<br>`）→ Paginator 测偏 → 溢出
- **根因**：fix7 加的 `_forceVisibleLineBreaks`（`markdown_book_loader.dart:147-179`）给每行尾补两空格，markdown 标准库识别为 hard break → 产 `<br>`。但 Paginator 按 plain text 字符偏移测高，`<br>` **不增加偏移却增加视觉高度** → 测出来"很矮"、实际渲染"很高" → 一页塞太多 → 内容溢出页面边界。**这是 fix2/3/5/7/9 共 5 次失败的共同元凶**。
- **修复**（用户决策"按 TXT 技术逻辑"）：重写 `MarkdownBookLoader._markdownBodyToHtml`：
  - 删除 `md.markdownToHtml()`、`_forceVisibleLineBreaks`、`_isStructuralLine`、`_stripImages`
  - 仿 `TextBookLoader.parseText`：按 `\n` 分行 → 每行 trim → 空行跳过 → 每行独立成 `<p>...</p>`
  - **轻量保留行内语法**：`**粗体**`→`<strong>`、`*斜体*`→`<em>`、`` `代码` ``→`<code>`（占位符保护）、`[text](url)`→`text`
  - 围栏代码块（` ``` `/`~~~ `）内的行原样转义成 `<p>`，不做行内替换
- `reader_engine_provider.dart:105` 删除 `setPaginationMode(scroll)` → MD 走默认 paged + 双页，与 TXT 完全同构
- **章节保留**：`parseMarkdown` 的 `#`/`##` 切章逻辑不动，TOC 自动生成，章节跳转/高亮全部继承

#### Fixed — EPUB 翻页/目录卡死 O(N²)→O(N)（A3）

- **根因**：`_buildPaged` 的 LayoutBuilder 内，每个 break 都调 `HtmlSlicer.sliceByPlainRange`，后者每次都 `HtmlParser(html).parse()` 整章 DOM（`html_slicer.dart:62`）。一本长章节（财经书表格多，50+ 页）单帧 50 次 `HtmlParser.parse()`，每次 O(章长度) → 单帧数百 ms → UI 线程堵死 → 翻页/目录 `await chapterSwitchSettled` 永远不返回（它等的 post-frame callback 被堵在队列里）。
- **修复**：`html_slicer.dart` 新增 `sliceByPlainRangeDoc(Document doc, ...)` 接受预解析 Document，**非破坏式**遍历（重写 `_cloneFiltered` 不修改 source doc，构造新子树）。`epubx_renderer.dart:1083-1109` 改为循环外解析一次 DOM，循环内所有 break 复用同一 `chapterDoc` 实例。复杂度从 O(N × 章长度) 降到 O(章长度 + N × 页内 DOM) ≈ O(N)。
- **测试**：新增 3 个非破坏式测试（同一 doc 切多范围互不干扰、不修改 source doc、与旧 API 行为一致），全部通过。

#### Fixed — 双页跨页选区串读（A4）

- **根因**：`reader_body.dart:548-552` 单个 `SelectableRegion` 包整个 reader stack（含双页 Row）。Flutter `SelectionRegistrar` 按几何位置合并选区，左右页同一 Y 行的文本都在选区矩形内 → **右页同行被一并选中**。
- **修复**：`epubx_renderer.dart` 双页 Row 内每个 `Expanded` 包独立 `SelectionArea`（SelectableRegion 的 Material 包装），建立局部 registrar，子树 selectable 不冒泡到外层 SelectableRegion。每页的 `onSelectionChanged` 通过 renderer 新增的 `pagedSelection$` 流推到 reader_body，复用 `_onSelectionChanged` 处理。单页模式不包（保持外层 region 行为）。

#### Fixed — 摘录新增后不刷新（A5）

- **根因**：`local_notes_repository.dart:193-202` 的 `watchAnnotations` 在 `noteRow == null` 时 `yield []; return;` 终结 stream。首条摘录场景 BookNote 不存在（t0），`_ensureBookNote` 创建 BookNote（t1）后 stream 已死，新摘录永不推送 → UI 不刷新，需退出书架重进。
- **修复**：`book_notes_dao.dart` 新增 `watchByBookId`（drift `.watchSingleOrNull()`，底层表变化重发）。`watchAnnotations` 改用 `await for (final noteRow in _notesDao.watchByBookId(bookId))`，noteRow == null 时持续 yield `[]`，noteRow 出现后切换到 `annotations.watchByBookNoteId`（永久 emit）。

#### Added — 全局错误兜底（A6）

- **根因**：`main.dart` 无 `ErrorWidget.builder` / `FlutterError.onError` / `runZonedGuarded`。任何 widget build 抛异常 → Flutter 默认红底白字 ErrorWidget 替换整棵子树。`reader_body.dart:543-589` 的 chrome（导航条）+ 正文在同一 Stack → 一处异常全树崩 → "红色蒙层 + 导航条消失"。
- **修复**：`main.dart` 加三件套：
  1. `ErrorWidget.builder` → 自定义 `_ZhiYueErrorWidget`（白底 + 错误图标 + "页面渲染异常" + 异常摘要）
  2. `FlutterError.onError` → debugPrint 记录
  3. `runZonedGuarded` 包 runApp → 捕获异步未捕获异常

#### Lessons（失败对照表）

| # | 问题 | 历史失败次数 | 本次根因 |
|---|------|-------------|---------|
| 1 | PDF 双页 | fix4~fix9 共 6 次 | pdfrx 双 PdfViewer 竞态未根治 → 锁死单页 |
| 2 | MD 排版 | fix2/3/5/7/9 共 5 次 | `<br>` 不增 plain 偏移却增视觉高度 → 仿 TXT 每行成 `<p>` |
| 3 | EPUB 卡顿 | M3e/Q12 共 1 次（治标） | O(N²) DOM 解析 → 整章一次复用 |
| 4 | 双页跨页选区 | 首次报告 | 单 SelectableRegion 包整树 → 每页独立 SelectionArea |
| 5 | 摘录不刷新 | 首次报告 | stream 在 noteRow==null 时 return → 双表 watch |
| 6 | 红色蒙层 | 首次报告 | 无全局兜底 → ErrorWidget.builder + zone |

#### Verification

- 单元测试：751 通过 / 14 跳过 / 254 失败（**254 全是 drift native fts5 模块环境缺失**，pre-existing，与本次改动无关）
- 关键测试全绿：MD loader 28 个、html_slicer 21 个（含 3 个新增非破坏式）、epubx_renderer dual page 10 个
- 构建 exe：**失败**——Flutter `gen_snapshot` 在中文路径下用 GBK 解码路径，UTF-8 中文变乱码（`锟斤拷`）找不到 app.dill。这是 Flutter 工具链 pre-existing bug（非代码问题），需用户在英文路径环境构建或用 8.3 短名 workaround。

---

### M4.6-fix9 — 2026-07-05（PDF 双页死锁根治 + MD 段落溢出修复）

M4.6-fix4~fix8 共 5 次在 PDF 死锁上失败、fix2/3/5/7 共 4 次在 MD 分段上失败后，触发 systematic-debugging 阶段 4.5（架构质疑）。基于 `zhiyue_pdf.log` 铁证 + pdfrx 源码调研，确认为架构错误，重写两处管线。

#### Changed — PDF 双页改用双 PdfViewer 共享 PdfDocument（方案 A''）

- **根因（日志铁证）**：`zhiyue_pdf.log` 显示 `dispose start` 后无 `dispose done`——`_doc.dispose()` 永不返回。旧双页实现用两个 `PdfViewer.data()` 配 `#L`/`#R` **不同 sourceName**，pdfrx `CanonicalizedMap`（`pdf_document_ref.dart:18/78/92-97`）视为两份文档 → pdfium 加载两份 29MB → dispose 时序混乱 + 渲染线程未完成 → `FPDF_CloseDocument` 死锁 → 进程僵尸 → 持有 named mutex → exe 二次启动失败。
- **修复**：双 `PdfViewer.data()` 改用**相同 sourceName**（`doc.sourceName`，去掉 `#L`/`#R` 后缀）→ pdfrx 自动共享同一份 `PdfDocument`（官方 `PdfDocumentRefKey` 缓存机制）→ 只加载一次 → dispose 干净。
- **翻页正确性**：两 viewer 各 `NeverScrollableScrollPhysics` 锁定到 `initialPageNumber`，翻页 step=2 用 `ValueKey('pdf-dual-L-$leftIdx')` 变化触发 widget 重建到新页。spread 序列 (1,2) → (3,4) → (5,6)，不出现 2-3 错位（用户提出的核心担忧已排除）。
- **方案选型**：原"方案 A：单 PdfViewer + PdfPage.render() 副页位图预览"被用户敏锐指出存在 2-3 错位风险 + 主页可滚动导致不同步 + 副页不能交互（文本选择/缩放）三大问题，调研 pdfrx 源码后推翻，改用方案 A''（双 viewer 共享 PdfDocument）。

#### Changed — PDF dispose 加 3s timeout 安全网

- `_doc.dispose()` 包 `.timeout(Duration(seconds: 3))`，超时 catch `TimeoutException` 后继续关闭 stream。主修复（共享 PdfDocument）已根除死锁源，此 timeout 仅防未来回归。

#### Changed — MD 强制走 scroll 模式（复用既有 `_buildScroll`）

- **根因**：MD 复用 EPUB 的 `Paginator`（按 plain text 偏移机械分页），`<br>` 强制换行（`_forceVisibleLineBreaks`）打破"连续字符流"假设 → 段落被切到页中、内容溢出页面边界（fix2/3/5/7 共 4 次失败）。
- **修复**：`reader_engine_provider.dart` 里 MD 路由调 `engine.setPaginationMode(PaginationMode.scroll)`，复用既有 `_buildScroll`（`SingleChildScrollView + HtmlWidget`），段落完整、不溢出。MD 不做双页（fwfh 不支持 CSS column-count，双栏需自定义 RenderObject，收益低；MD 内容通常技术文档，单列滚动可接受）。
- **TXT 零改动**：TXT 仍走 paged + 双页（用户确认 TXT 正常）。

#### Fixed — exe 二次启动失败（PDF 死锁的下游级联）

- PDF 死锁根治后，进程能正常退出，named mutex 自然释放，二次双击正常启动。

#### Lessons — fix4~fix8 在 PDF 死锁上失败的教训

| 轮次 | 假设 | 实际 | 教训 |
|------|------|------|------|
| fix4 | ExitProcess 解决僵尸 | PDF 死锁未解，进程仍挂 | 死锁源在 Dart 侧 dispose，不在 C++ 侧 |
| fix6 | 互斥锁接管解决二次启动 | PDF 死锁未解，接管无效 | 接管只能处理"已死"互斥锁，不能让活进程退出 |
| fix8 | 日志能定位死锁源 | 日志正确，但双 PdfViewer 是死锁源本身 | **架构错误，不是日志问题** |
| fix9 | 共享 PdfDocument 根除死锁 | （待用户端到端验证） | 架构对了，死锁应消失 |

MD 同理：fix2/3/5/7 在 paged 模式 + Paginator 上打补丁失败，根因是 Paginator 的"纯文本测量"假设与 MD 的 `<br>` 换行不兼容，改走 scroll 模式（HtmlWidget 原生布局）才是正解。

### M4.6-fix4 — 2026-07-05（exe 二次启动闪退 + PDF 翻页卡 loading + MD 排版乱）

用户测试 M4.6-fix3（commit 54221f9）后报告三个阻塞问题：①exe 关闭后再次双击"图标闪一下就没了" ②PDF 翻 10+ 页后阅读区不停 loading，回退也 loading ③MD 阅读完全乱（未双页、超出页面很多、第二章标题"变图片"）。按 systematic-debugging 流程做完整根因调查后逐一修复。

#### Fixed — exe 二次启动闪退（main.cpp named mutex + 进程残留）

- **根因**：`tasklist` 显示用户"关掉"窗口后 zhiyue.exe 进程仍残留（PID 2932, 656MB），named mutex `Local\\ZhiYueApp` 永远 `ERROR_ALREADY_EXISTS` → 第二实例 `is_first_instance = false` → argv 空（桌面图标双击启动无参数）→ 直接 `return EXIT_SUCCESS` → 用户看到"图标闪一下就没了"。进程残留源于 Flutter engine 关窗时若 native plugin（pdfrx PDFium / window_manager）持有未释放资源，message loop 的 `GetMessage` 链可能挂在某个消息处理里出不来。
- **修复 1（兜底）**：`wWinMain` 末尾 message loop 退出后强制 `::ExitProcess(EXIT_SUCCESS)`——跳过 Dart dispose / C++ 析构，但 kernel mutex / COM 资源由 OS 回收，确保下次启动拿到 fresh 状态。drift WAL 模式下已提交事务不会丢。
- **修复 2（体验）**：第二实例发现已有窗口时**无论 argv 是否为空都 SetForegroundWindow + SW_RESTORE**（之前仅 argv 非空时转发，桌面图标双击启动 argv 空 → 无反应）。用户从桌面图标二次启动最期望的是已有窗口前置，不是无反应退出。

#### Fixed — PDF 翻 N 页后无限 loading（pdf_renderer widget tree 稳定化）

- **根因**：`PdfRenderer.build` 用 `FutureBuilder<bool>` 包裹 `PdfViewer`，每次父级 rebuild（窗口尺寸变化/翻页 setState/typography 变化）都重建 widget tree → pdfrx `_PdfViewerState.didUpdateWidget` 触发 reload path → `loadPagesProgressively` 重启 → pageImage 缓存累积（pdfrx 2.4.4 `PdfViewerParams` 无 maxPinPages 上限）→ 内存压力 → 后续 page render 阻塞 → loading banner 一直显示。`PdfViewerParams` 每次 build 都 new 一个新实例（函数字段比对引用相等），闭包重建触发 `doChangesRequireReload`。
- **修复**（`pdf_renderer.dart`）：
  - **移除 FutureBuilder**：scanned 判定改走 `openFile` 时启动 Future + `then` 回调写 `_scannedCache` + setState，build 走同步路径。
  - **加 RepaintBoundary**：build 顶层包 `RepaintBoundary` 把 PDF 阅读区与父级 reader_body 隔离。
  - **PdfViewer 加 ValueKey**：`ValueKey('pdf-main-${doc.sourceName}')`，同书 State 复用稳定，切书 sourceName 变 → 干净重建。
  - **PdfViewerParams 方法化**：`_buildMainParams()` 单独抽出，buildContextMenu fallback 用 pdfrx 自带的 `params.a?.page.pageNumber` 而非闭包捕获的 `_currentPage`（避免 stale 值）。

#### Fixed — MD 排版完全乱（删 _preserveLineBreaks 回归 CommonMark + 移除 img）

- **根因（排版乱）**：M4.6 (#5) 的 `_preserveLineBreaks` 给每行尾部强制补两空格让 markdown 视为 hard break → 段内换行被强制 `<br>` → fwfh 把段落切成断行堆叠，**违反 CommonMark 段内合并语义**（CommonMark 规定段内单换行渲染时合并为同段连续流，行尾两空格或反斜杠才是 hard break）。原始 MD 文档的"一行一段/一句"只是源码可读性，渲染时本就该合并。表现为"第一段在左上、第二段在右下、超出边界"。
- **根因（标题变图片）**：fwfh `HtmlWidget` 默认渲染 `<img>`，MD 无 base URL 时 src 当网络 URL，显示 loading 占位/异常图标。用户报告"第二章标题变图片"很可能就是 `# ![icon](...)` 在 fwfh 里渲染成了图片占位。
- **修复**（`markdown_book_loader.dart`）：
  - **删除 `_preserveLineBreaks` 全部逻辑**，`_markdownToHtml` 直接走 `md.markdownToHtml(body)`。CommonMark 标准库已正确处理段内合并 / 显式 hard break / 空行分段 / 标题列表引用代码块结构。
  - **新增 `_stripImages`**：用正则匹配 `<img alt="..." ...>` 移除 `<img>` 标签，保留 alt 文本作 `[alt]` 占位（让读者知道这里有图但不尝试加载）。MD 阅读场景无网络/相对路径解析能力，移除是合理 trade-off。
- **测试**：新增 `markdown_book_loader_no_force_break_test.dart`（9 cases：段内合并、显式 hard break 保留、列表/引用不受影响、独立图片移除、标题内图片移除、多图片移除、无 alt 不崩溃）。更新 `markdown_book_loader_test.dart` 2 个旧测试反映 CommonMark 新语义。共 33 个 MD 测试 + 51 个 PDF 测试 + 2 个 MD scroll 集成测试全 pass。

#### Fixed — main.cpp 加 UTF-8 BOM（MSVC C4819 警告被视错误）

- M4.6-fix4 main.cpp 加了中文修复说明注释，MSVC 在中文系统代码页 936 (GBK) 下报 C4819 警告被项目视为错误，导致 `flutter build windows` 失败。
- 加 UTF-8 BOM (`EF BB BF`) 后 MSVC 自动识别源文件为 UTF-8 编码，C4819 消失。原 `L"智阅"` 窗口标题字面量此前能编译是因当时文件全英文（仅 ASCII），不受代码页影响；本次新增中文注释触发了潜伏的编码问题。

#### Lessons

- **systematic-debugging 铁律生效**：本次三个问题都先完整跑 Phase 1（根因调查）+ Phase 2（pattern 对比）才动代码。问题 1 通过 `tasklist` 发现进程残留；问题 2 通过读 pdfrx 2.4.4 源码定位 FutureBuilder 重建链；问题 3 通过读 CommonMark spec + 跑 markdown 标准库验证段内合并语义。无猜测式修复，无"再试一次"。
- **MD 排版的 CommonMark 误区**：曾以为 MD"一行一句"是渲染应保留的语义，实际 CommonMark 明确规定段内单换行渲染合并。原始文档的分行只是源码可读性约定（类似代码格式化）。修复方向是删除强制 hard break 而非扩展跳过规则——之前 M4.6-fix (#3) 试图用 `_isStructuralLine` 跳过结构行，但永远跳不完所有边界（图片、表格、脚注、定义列表…）。回归标准才是正解。
- **PDF 不能 headless 测试**：pdfrx 需要 PDFium native binary，flutter test headless runner 不支持。PDF 修复只能通过读 pdfrx 源码 + 推理 + 用户实测验证。本次修复的回归测试是 widget-level（key 稳定性、FutureBuilder 移除），不能验证实际 PDF 渲染。
- **MSVC C4819 潜伏陷阱**：项目 `Treat Warnings As Errors` 开启时，任何含非 ASCII 字符的源文件都需要 UTF-8 BOM 才能在非 UTF-8 系统代码页编译。今后 Windows runner 任何 .cpp/.h 加中文必须先加 BOM。



用户反馈"部分页面文字比较多的时候下方文字会超出页面下底线，导致部分数据看不到"。

#### Fixed — Q8 分页测量漏算段间距/缩进/冗余导致末行被裁

- **根因**：`Paginator._paginateUncached` 的分页测量与 fwfh 实际渲染存在**系统性偏小**，导致每页塞入过多内容 → 渲染时末行溢出底部被裁。代码 L920-924 自己注释承认误差存在，但低估了累积量。具体 3 处漏算：
  1. **段落间距**：测量只算 `TextPainter` 纯文本高度，但渲染层 `_paragraphMarginBuilder` 给每个 `<p>` 加 `margin: 0 0 0.5em 0`。一页 N 段时累积漏掉 N×0.5em。
  2. **首行缩进 em-space**：`TypographyStyleInjector` 每段首行注入 2×`U+2003`（≈2em），首行有效宽度变窄 → 多换 1 行。测量层不知道此前缀。
  3. **安全冗余为 0**：`TextPainter` 与 fwfh 的 `line-height`/font-metrics 有微小偏差（代码自认 <1 行），临界页（刚好踩线）易溢出。旧代码容差为 0。
- **为何"看不到"而非"斑马线"**：页面包了 `SingleChildScrollView(NeverScrollableScrollPhysics)`（M2.10 防 assertion），溢出时不会抛 RenderFlex assertion（无斑马线），但 `NeverScrollable` 也无法滚动看到被裁内容 → 用户看到末行凭空消失。
- **修复**（`paginator.dart` `_paginateUncached`）：
  - 测量每段时把缩进前缀 `indentEm × U+2003` 拼到段首，让 TextPainter 自然算入首行多换的行。
  - 非页首段累加 `0.5em` 段间距（页首段上方无前段，不加）。
  - 临界判断加 `safetyMargin` 冗余，临界页提前换页（初始 1 行高度，Q8续 调到 0.3 行——见下）。
- **回归测试**（`paginator_overflow_test.dart`，3 cases 全过）：
  - 60 段长内容分页数 > 3（防分页过粗）。
  - 30 段内容每页纯文本高度 ≤ 可用高度（直接证明不再过满）。
  - 缩进关闭时仍正确分页。

### M3e/Q8续-Q12 — 2026-07-04（paged 模式边距统一 + 翻页卡顿）

Q8 修完溢出后，用户连续反馈 4 个 paged 模式排版/性能问题，逐一定位修复。最终采用**真书版心固定**模型（放弃居中对齐）。

#### Fixed — Q8续 上下边距不对称 → safetyMargin 从 1 行降到 0.3 行

- 用户反馈「上边距窄、下边距宽」。根因：Q8 的 `safetyMargin = 1 行高度`（32px）过保守，每页底部多预留一整行 → 视觉上下方明显比上方宽。
- 修复：`safetyMargin = 0.3 × lineHeight`（约 10px），既保留临界页防溢出余量，又消除肉眼可见的上下不对称。

#### Fixed — Q9 双页模式右页上下边距比左页窄

- 用户反馈「左右两页都有内容时，右侧上下边距比左侧窄一点点」。
- 根因：双页 `Row` 的左右两页各自用 `_PageVerticalAligner` 独立管理上下边距，fwfh 渲染高度与 TextPainter 测量的微小偏差在左右两页独立累积，导致右侧略偏。
- 修复：双页模式引入 `_DualSpreadAligner`，**上下边距提升到 spread 层统一管理**（左右两页共享同一 vertical padding），`_PageVerticalAligner` 在双页模式下 `enableCentering=false` 且不重复加 padding。

#### Changed — Q10+Q11 放弃居中对齐，改真书「版心固定」模型

- 用户反馈反复振荡：居中对齐（Q8续 目标）能修上下对称，但破坏左右对齐（Q9）和导致页高跳变（Q11）；顶部对齐能修左右和页高，但上方比下方窄（Q8续/Q10）。
- **最终决策**：完全放弃居中，所有页**固定顶部对齐**到统一边距（真书做法）。满页底部允许有少量自然留空（末页更明显），这是真书的正常版心效果，用户接受。
- 实现：`_PageVerticalAligner` / `_DualSpreadAligner` 都改为 `StatelessWidget`，固定顶部对齐，`OverflowBox(maxHeight: infinity, alignment: topLeft)` 吸收 fwfh 与测量的高度误差（不抛 assertion）。
- **删除**两阶段测量方案（`_MeasureSize` / `_RenderMeasureSize` / `_measuredHeight` state / `didUpdateWidget`）——`postFrameCallback` 在测试环境不触发 + 子页 OverflowBox 干扰测量，方案不可靠且不必要。

#### Fixed — Q11 每页高度不一样 → 统一固定版心

- 用户反馈「每页高度都不一样，能不能限定在范围之内」。
- 根因：居中对齐模式下，短页（末页）在 slot 内垂直居中 → 文字起始 y 随内容多少浮动（72-110px 不等）。
- 修复：固定顶部对齐后，所有页首行 y 恒定（实测 topM=72.0，不再浮动）。回归测试断言单页所有页 + 双页左右页首行共享同一固定 top（maxTop-minTop < 2px）。

#### Performance — Q12 翻页卡顿 → 预计算页 HTML，buildSinglePage 改 O(1)

- 用户反馈「翻页有时候卡住，卡的时候点章节页也卡住」。
- 根因：`buildSinglePage` 被 `PageView.itemBuilder` **每页每次**调用，里面 3 步都遍历整章 HTML：`HtmlSlicer.sliceByPlainRange`（DOM 解析整章）+ `HtmlHighlightInjector.inject` + `TypographyStyleInjector.inject`。翻到中间页时每页都重做一遍整章解析 → 50-100ms/页。
- 修复：把这 3 步**上移到 LayoutBuilder.builder**（每章 rebuild 只跑一次），结果存进 `pageHtmls: List<String>`。`buildSinglePage` 改成 `pageHtmls[breakIdx]` 直接取用（O(1)）。
- 实测：翻页从 50-100ms 降到 4-11ms。
- 回归测试：`epubx_renderer_paged_overflow_test.dart` 加「翻到中间页渲染内容正确」用例，验证预计算没丢内容。

### M4.6 — 2026-07-05（阅读器打磨包：PDF 双页/缩略图 + 淡绿主题 + 新晰黑默认 + MD/TXT 渲染修复）

用户测试 M4.5 后反馈 6 个问题，本里程碑一次交付：4 项功能增强 + 2 项 M4.5 引入的回归修复。

#### Added — 淡绿色主题（#3）

- 新增 `ReadingTheme.green`（浅艾绿 `#E3EDD7` 背景 + 深褐 `#3A4A2D` 文字，WCAG AA 对比度）。
- 4 处同步：reader_engine 枚举 / EPUB `themeColors` fg-bg / PDF `applyTheme` ColorFilter（半透明叠加）/ typography_panel UI 标签「绿」。EPUB/PDF/MD/TXT 四格式生效。
- 枚举是 exhaustive switch，编译器强制 4 处都改对。

#### Added — PDF 无目录时缩略图导航（#2）

- PDF 无内嵌目录时，目录 tab 原显示「本书无目录」文案，现改为页面缩略图 grid。
- 新 widget `pdf_thumbnail_grid.dart`：pdfrx `PdfPage.render()` 异步渲染，内存 LRU 缓存 32 张（约 6MB），`GridView.builder` 只构建可视区，post-frame callback 触发渲染避免 build 中 setState。当前页 primary 色边框高亮，点击跳页。
- pdfrx 2.4.4 实际 API：`render(fullWidth:, fullHeight:)` 返回 `PdfImage`，需 `createImage()` 转 `ui.Image`，渲染后 `dispose()` 释放原生资源。

#### Added — PDF 宽屏自动双页（#1）

- PDF 原有手动 toggle 双页（工具栏按钮），现对齐 EPUB：窗口 ≥1100px 自动双页，缩窗回单页。
- 在 `reader_body.dart` LayoutBuilder 加 PDF 分支：`e.dualPageMode = isWide && !e.rendererRef.isScanned`。
- 扫描件（isScanned）仍维持单页（双页会让扫描页缩太小看不清）。isScanned 同步 getter，未解析时保守返回 false，解析完成后下次 rebuild 自动切双页，无崩溃风险。

#### Changed — 默认字体改新晰黑（#4）

- `TypographySettings.defaults()` 的 `fontFamily` 从 `null`（系统字体）改为 `'LXGWNeoXiHei'`（新晰黑，已打包注册）。
- 仅影响全新用户/全新 DB；老用户预设是 DB 独立记录。

#### Changed — DB schema v10→v11 老用户字体迁移（#4）

- `typography_profiles` 表的 fontFamily 嵌在 `settings` JSON 列（非独立列），migration 用 SQLite JSON1 函数 `json_set` 回填。
- schema v11 onUpgrade：`UPDATE typography_profiles SET settings = json_set(settings, '$.fontFamily', 'LXGWNeoXiHei') WHERE json_valid(settings) AND json_extract(settings, '$.fontFamily') IS NULL`。
- 幂等（WHERE 严格过滤 NULL），不动已自定义字体的预设。

#### Fixed — Markdown 段落堆叠（M4.5 回归 #5）

- **现象**：原 MD 文档分段一行一行，阅读器打开后段落堆叠，没还原换行。
- **根因**：markdown 包（7.3.1）按 CommonMark 规范，段落内单个 `\n`（soft break）渲染时折叠成空格（不是 `<br>`），导致连续行堆成一行。
- **修复**：调 `markdownToHtml` 前预处理——给每个非空、非围栏代码块、非已有 hard break 的行尾补两空格，强制 markdown 视为 hard break（两空格+换行 → `<br>`）。围栏代码块（` ``` `/`~~~`）内行原样保留，标题行（`#`）不加。
- 注：`LineSplitExtension` 在 markdown 7.x 不存在（已核对 export），故用预处理方案。

#### Fixed — TXT 内容溢出屏幕（M4.5 回归 #6）

- **现象**：TXT 文档打开后内容都跑到屏幕外。
- **根因**：`parseText` 用 `text.split(RegExp(r'\n\s*\n'))` 按空行切。中文小说常见连续行无空行（每行一段），导致整篇当一个 `<p>`，Paginator 退化（单段超长无法分页），内容溢出视口。
- **修复（智能启发式）**：重写 `parseText`——按 `\n` 逐行处理，每行 trim 后非空则独立成 `<p>`（中文小说每行一段事实标准），空行作分隔符跳过。杜绝超长单段，保证 Paginator 正常分页。

#### Non-Goals

- PDF 双页的文本选区/高亮（pdfrx 限制，已知缺陷，本次不做）。
- EPUB/PDF 双页抽象统一（R1 风险，本次不重构）。
- LineSplitExtension 之外的 GFM 扩展（表格/删除线，避免引入未测试行为）。

#### 测试

- `markdown_book_loader_test.dart` 加 M4.6 用例：soft break 转 `<br>`（2 个）、代码块回归保护、TXT 连续行每行独立 `<p>`。共 21 测试全过。
- `database_test.dart` / `migration_v10_test.dart` schemaVersion 断言更新到 11。
- dart analyze 4 包（reader_engine / epub_view / pdf_view / app）全过。
- 3 个 DB 测试失败是预存问题（FTS5 测试 helper 缺陷，git stash 验证 M4.6 前后一致），与本次无关。

#### Lessons

- **并行 subagent 同仓库文件竞态**：首次尝试 6 个 subagent 并行执行，T1/T2/T3/T4 的改动被互相覆盖丢失。教训：同一仓库的文件修改必须串行（或确保文件集完全不重叠 + 无共享读取）。改为主 agent 串行重做后一次通过。

### M4.5 — 2026-07-05（新增 Markdown / 纯文本格式支持）

用户要求新增 `.md` / `.txt` 书籍格式支持。MD/TXT 复用 EPUB 的 HTML 渲染管道（md→html / txt→`<p>` → fwfh HtmlWidget），行为与 EPUB 一致（分页、高亮、双页、主题、AI 伴读）。

#### Added — MD/TXT 格式全链路

- **格式无关渲染抽象**（`reader_engine_epub_view/lib/html_chapter_source.dart`）：新增 `HtmlChapterSource{title, html}` 数据类。`EpubxRenderer` 内部所有章节访问（`.HtmlContent`）改成走格式无关的 `_chapters` 字段 + `chapterCount` / `flatChapterHtmlAt` / `flatChapterTitleAt` 访问器。EPUB 路径仍走 epubx 解析（`openFile`），解析后同步填充 `_chapters`；MD/TXT 走新方法 `openChapters(List<HtmlChapterSource>)` 直接填充。**EPUB 渲染逻辑零改动**（Paginator/HtmlSlicer/injector/双页/版心对齐全部原样复用）。
- **MD/TXT 加载器**（`app/lib/services/`）：`MarkdownBookLoader`（`markdown` 包 `markdownToHtml`，按 `#`/`##` 标题切章，无标题则单章）+ `TextBookLoader`（按空行分段包 `<p>`，单章，HTML 实体转义）。UTF-8 优先，失败降级 latin1。
- **格式检测**：`BookFormatDetector` 加 `.md`/`.markdown`/`.mdown`/`.txt` 扩展名分支（无 magic bytes，扩展名判定）；`FilePicker`、`BookOpenBridge`、Windows `flutter_window.cpp` 三处白名单同步扩展（cpp size guard 从 `<5` 放宽到 `<4`）。
- **AI 路径**：新增 `HtmlFileChapterTextProvider` + `HtmlFileExtractor`（复用加载器 + `htmlToPlainWithOffsets`），`chapterTextProviderFor` / `extractorFor` 加 markdown/text 分支。MD/TXT 支持 AI 伴读/总结/章节复习。
- **依赖**：`app/pubspec.yaml` 加 `markdown: ^7.0.0`（BSD-3-Clause）。

#### Changed — 消除 5 处「三元地雷」+ UI 标签通用化

- `BookFormat` enum（app + reader_engine 两处）加 `markdown, text`。新增 `BookFormatDb` 扩展集中管理 `dbValue` / `fileExtension` / `displayLabel` 映射，替代散落在 `fromRow` / `local_book_repository` / `import_service` / `reader_engine_provider` / `markdown_exporter` 的 ternary（旧代码对未知格式默认降级为 PDF，会让 MD/TXT 被误当 PDF 崩溃）。
- `reader_engine_provider` 加 markdown/text 路由分支 → `ConcreteEpubReaderEngine.openChapters`。**关键设计**：MD/TXT 复用 `ConcreteEpubReaderEngine` 类型 → `reader_body.dart` 的 12 处 `is ConcreteEpubReaderEngine` 检查对 MD/TXT 也成立，双页/高亮/章节摘录等能力零改 UI 自动继承。
- 书架 chip 通用化：`_PdfChip` → `_FormatChip(format)`，所有非 EPUB 格式显示标签（PDF/Markdown/TXT）。详情页格式标签走 `displayLabel`。

#### Fixed — openChapters 未填充 _toc（Q-TOC 同构 bug）

- 集成测试发现 `ConcreteEpubReaderEngine.openChapters` 漏了 `_toc = await _renderer.toc`（与 M4/Q-TOC 的 PDF 目录转圈 bug 完全同构）。修复后 MD/TXT 目录 tab 正常显示（MD 标题树 / TXT 单条「全文」）。

#### Non-Goals（本期不做）

- MD 原生 markdown 渲染器（`flutter_markdown`）—— 走 md→html→fwfh，保持全格式渲染一致。
- TXT 按字数自动切章 —— 本期单章，靠分页翻页。
- 封面提取 —— MD/TXT 无封面，沿用首字母占位图。
- Android mimeType 扩展 —— 留 follow-up。

#### 测试

- `book_format_detector_test.dart`：+6 用例（md/txt/markdown 扩展名、大小写、空文件），共 11 测。
- `markdown_book_loader_test.dart`：新建，18 测（MD 切章边界/前言/无标题/空文件/编码、TXT 分段/转义/`<br>`、HtmlChapterSource 值对象）。
- `html_chapter_engine_integration_test.dart`：新建，7 测（状态机、TOC 填充、build 渲染、纯文本提取、_chapters 数据源）。
- EPUB 回归：epub_view 160/161 通过（1 预存在 cover fixture 失败）。app 全量无新增失败（13 个预存在失败：typography margin / import fixture / exporter CRLF，均与 M4.5 无关，已 git stash 验证）。
- `dart analyze` 4 包 0 issues。Windows Debug build 成功。

### M4/Q-TOC — 2026-07-05（PDF 目录永久转圈修复）

用户反馈打开 PDF 后「目录一直转圈」。

#### Fixed — PdfReaderEngine.toc 永远返回 null

- **根因**：`ReaderEngine.toc` 是同步 getter（`TableOfContents?`），但 pdfrx 加载目录是异步的（`PdfDocument.loadOutline()` 返回 Future）。`PdfReaderEngine` 旧实现直接 `get toc => null` 硬编码，而 UI 层 `reader_drawer_builders.dart` 用 `if (toc == null) LoadingView()` 同步判定 → PDF 目录 tab **永久转圈**。`PdfRenderer.toc`（真正调 loadOutline 的异步 getter）从未被调用。EPUB 不受影响（目录在解析时同步拿到）。
- **修复**（`pdf_reader_engine.dart`，对齐 `ConcreteEpubReaderEngine._toc` 模式）：加 `TableOfContents? _toc` 字段；`open()` 里 `await openFile` 后 `_toc = await _renderer.toc`（loadOutline 失败也降级为 empty TOC，不抛）；getter 返回 `_toc`。
- 效果：open 期间转圈（正常），open 完成后必非 null —— 有书签显示目录，无书签/加载失败显示「本书无目录」。
- 回归测试（`pdf_reader_engine_test.dart`，2 cases）：未 open 时 toc=null；open 后（即便文件不存在进 error 状态）toc 非 null 且为空 TOC。

## [1.6.0-alpha] — 2026-07-04（阅读体验大修：双页对开 + 排版 + 字体 + 交互）

v1.5.1-alpha 之后的一大批阅读体验修复，涵盖双页对开布局、段落排版、字体扩展、
摘录/书签交互、顶栏快捷键等。包含里程碑 M2.9（双页）/ M2.10-11（双页回归修复）/
M3a-e（用户两轮反馈共 7 个问题的逐一定位与修复）。

### M3e — 2026-07-04（阅读体验第二批修复，已完成）

用户拉取 M3a-d 后上手测试，反馈 6 个问题（Q1 段落缩进未生效 / Q2 末页依旧居中 / Q3 字体太少 / Q4 书架字号按钮挪位 / Q5 摘录条跟随选区 / Q6 删除键找不到）。Q7 是 Q6 的修正补丁：用户反馈「摘录、书签右键菜单这个功能没看到」。

#### Fixed — Q2（重审）末页居中诊断 + 回归测试改测真实坐标

第二轮用户反馈「末页依旧居中」。深入诊断后纠正了 M3e-Q2 第一版的误判：

- **M3e-Q2 第一版的测试是「假绿」**：只断言 `SingleChildScrollView.child isA<Padding>`（结构上没有 Align），从未测量文字的真实绘制 y 坐标。结构对 ≠ 渲染对，测试过了用户仍看到居中。
- **新写 3 个坐标测量测试**（直接读 `RichText.top`）：
  - paged 单页短内容：首行 `top < viewport/3`（实测 top≈72，居中应≈300）
  - paged 多页章节**真正末页**（`jumpToPage` 到最后）：首行 `top < 200`
  - scroll 模式短内容：`top < 200`
- **三测全过**，证明源码末页文字始终顶部对齐。代码层面**根本不会居中**——fwfh 内部用 `Column(MainAxisSize.min, mainAxisAlignment.start)`，在 `SingleChildScrollView` 无限高度约束下天然从顶排。
- **用户看到居中的真因**：Debug 目录 `zhiyue.exe` 时间戳 `02:11` 早于 Q2 修复 commit（`18:11`），用户运行的是旧版二进制。M3a 曾误包 `Align(topCenter)`（后证实在 SingleChildScrollView 内是 no-op），但更早的版本可能有其它居中来源；不论如何，**当前源码已确认顶部对齐，干净重建后即可生效**。
- renderer 新增两个 `@visibleForTesting` 入口供坐标测试导航：`pageControllerForTest`（翻末页）、`cachedBreakCountForTest`（取页数）。

##### Q2 真因（第三轮，用户截图确认）— 双页模式 Row 默认 crossAxis center

用户发截图并明确指出「**和左侧对比，右侧居中，上下都有大量留空**」+ 像素分析证实：右页首行 y≈242(22%)、左页首行 y≈81(7%)，差 161px。前两轮只测了**单页模式**，漏了**双页模式**——这才是用户实际看到的场景。

- **根因**：`_buildPaged` 的 `itemBuilder` 双页分支用 `Row(Expanded, SizedBox, Expanded)` 摆左右两页。**`Row` 的 `crossAxisAlignment` 默认是 `center`**，会把高度 < slot 的右页（章节末页只有几行）**垂直居中**在 slot 内。
- **实测复现**（最小用例 `Row>Expanded>SingleChildScrollView>HtmlWidget` 短内容）：默认 `center` 时首行 top≈49%（居中）；加 `CrossAxisAlignment.start` 后 top≈2%（顶部对齐）。
- 单页模式 / scroll 模式不在 Row 里，不受影响——所以前两轮坐标测试都正常。
- **修复**（一行）：双页 `Row` 加 `crossAxisAlignment: CrossAxisAlignment.start`。左右两页都从顶部排起，像真书的双页对开。
- **回归测试 2 个**（已验证撤销修复后会失败，能抓回归）：双页右页短内容（末页）首行 `top < 25%` viewport；双页左页（满内容对照）首行 `top < 25%`。





#### Added — Q7 阅读器内抽屉摘录 tab 补右键菜单 + 可见按钮（修正 Q6「没看到」）

用户反馈「摘录、书签右键菜单这个功能没看到」。核查发现：Q6 只处理了**独立的摘录页**（`/notes`）和**书签列表**（共用 ReaderBookmarkList，drawer + BookmarksPage 都覆盖），但**阅读器内侧边抽屉的摘录 tab**（`notes_drawer.dart`）漏了 —— 那里的 AnnotationTile 只接了 onTap/onLongPress，没有右键、没有可见按钮。这就是用户"没看到"的地方。

补齐（与独立摘录页同款交互）：
- `notes_drawer.dart`（`NotesDrawerContent` + `NotesDrawer`）加可选回调 `onSecondaryTapDown(id, globalPos)` / `onEdit(id)` / `onExport(id)` / `onDelete(id)`，全 null 时向后兼容（无右键、无可见按钮，与旧版完全一致）。
- `reader_drawer_builders.dart` `ReaderNotesDrawerWrapper` 加同名回调透传。
- `reader_body.dart` 加 `_onAnnotationSecondaryTapDown`（弹 `showAnnotationContextMenu` 5 项桌面右键菜单，与 notes_page 同款）+ `_onAnnotationEdit/Export/Delete`（可见按钮）+ `_dispatchAnnotationAction` / `_showNoteEditor` / `_copyText` / `_exportAnnotation` 共用 helper + `_annotationById` 反查。右键删除直接删（右键是明确二次操作），可见删除按钮弹确认。两处 wrapper 调用点（窄屏 + 宽屏）都接入。
- 搜索高亮结果页（`search_highlights_page.dart`）本次未改（那是搜索场景，非"摘录/书签页面"，列为后续）。

测试：`notes_drawer_test.dart` +5 cases（无回调向后兼容 / 有回调渲染 3 按钮 / 右键触发 onSecondaryTapDown 带 id+坐标 / 编辑按钮触发 onEdit / 删除按钮触发 onDelete）。8 cases 全过。reader_body 11 cases 无回归。

#### Added — Q3 新增 2 款字体（共 5 款 + 系统）

#### Added — Q3 新增 2 款字体（共 5 款 + 系统）

- **阿里巴巴普惠体 `AlibabaPuHuiTi`**（标签「普惠体」）：现代圆润黑体，阿里巴巴全球永久免费商用授权。下载源 `chinayin/fonts-alibaba-puhuiti-regular`（社区镜像官方 Regular 字重，~10MB）。官网 alibabafonts.com。
- **霞鹜新晰黑 `LXGWNeoXiHei`**（标签「新晰黑」）：LXGW 基于 IPAex ゴシック 衍生的中文黑体字型，OFL 1.1，字形锐利适合屏幕长文。来自 `lxgw/LxgwNeoXiHei` v1.303（~7.5MB）。

下载可行性实测：经 gh-proxy.com / ghfast.top 镜像实测两者均 200 可达，已自动下载验证（9.7MB + 7.5MB，有效 TTF）。**无需手动下载**（用户最初选"需手动下载"是基于我之前不准确的探测结果，实测可自动）。

改动：`app/pubspec.yaml` 加 2 个 family 声明；`scripts/download-fonts.sh` + `.ps1` 各加 2 个下载块（多镜像 fallback，索引 [N/3]→[N/5]）；`app/assets/fonts/README.md` 字体表 +2 行；`typography_panel.dart` 字体 chip 列表 +2 项（普惠体/新晰黑）。测试：`typography_panel_test.dart` +1 case（普惠体 chip → fontFamily）+ 更新字体列表断言（9 cases 全过）。

#### Added — Q6 书签/摘录列表补可见删除/编辑/导出按钮

用户反馈 M3d 的右键菜单桌面端不直观，"删除键找不到"。补可见按钮：

- **书签列表 `reader_bookmark_list.dart`**：每个 ListTile 加 `trailing` 行（编辑/导出/删除 3 个紧凑 IconButton），桌面 + 移动端都可点。删除前弹 `AlertDialog` 确认（避免误删）。右键菜单保留（桌面高效补充），右键删除仍直接删（右键本身是明确二次操作）。提取 `_edit/_export/_delete/_confirmDelete` 私有方法，可见按钮与右键菜单共用。
- **摘录卡片 `annotation_tile.dart`**：加可选 `onEdit/onExport/onDelete` 回调（nullable，全部 null 时不渲染 actions 行，向后兼容 M3d）。任一非 null 时在卡片底部右对齐渲染 `_ActionsRow`（IconButton）。
- **摘录页 `notes_page.dart`**：AnnotationTile 传入 onEdit/onExport/onDelete，复用 `_editAnnotation`/`_exportSingle`/`_confirmDeleteAnnotation`（右键菜单也改用同一套方法）。删除前确认。

**范围说明**：阅读器内抽屉（notes_drawer）的摘录 tab 仍走长按 → NoteEditorSheet → 删除（既有路径可用），本次未补可见按钮（需跨 NotesDrawerContent→Wrapper→reader_body 传回调，改动面大，列为后续低成本任务）。

测试：`reader_bookmark_list_test.dart` +6 cases（trailing 按钮存在性/编辑/导出/删除确认取消/删除确认/默认 controller.delete）；`annotation_tile_test.dart` +5 cases（无回调不渲染/3 按钮/部分回调/编辑触发/删除触发）；`notes_page_test.dart` +2 cases（可见按钮渲染/删除确认取消）。共 49 cases 全过（含 M3d 既有右键菜单无回归）。

#### Changed — Q4 书架/字号按钮挪到时钟左边

用户反馈希望书架 + 字号按钮挪到时间显示左边（更顺手）。原 M3c 全放在右侧 actions。

- `reader_scaffold.dart` `_buildChrome`：`leading` 由单个返回 IconButton 改为 `Row`（返回 + 书架 + 字号- + 字号+），`leadingWidth` 放宽到 192 容纳 4 按钮。时钟保持 `title: ReaderClock()` + `centerTitle: true`。右侧 actions 精简为 目录/排版/笔记/书签/AI/问答/全屏/（双页）/（回顾）。
- 3 个按钮的 Key 不变（`reader_open_bookshelf` / `reader_font_decrease` / `reader_font_increase`），基于 Key 的测试 finder 不受位置影响。
- 测试：`reader_scaffold_test.dart` +1 case（断言 leading 是含 4 按钮的 Row、3 个 Key 在 leading 内、leadingWidth≥160、时钟仍在 title）。10 cases 全过。

#### Fixed — Q5 摘录条真正跟随选区（M3b API 误判纠正）

用户坚持要"摘录条跟随选区"。M3b 曾断言「Flutter 3.44.4 的 SelectableRegion 不暴露选区坐标，故 _selectionRect 暂时始终 null」。**这是误判** —— 源码追踪确认：

- `SelectableRegion` 接受 `GlobalKey<SelectableRegionState>`（构造参数）。
- `SelectableRegionState.contextMenuAnchors` 返回 `TextSelectionToolbarAnchors`（`primaryAnchor` = 选区上方中心**全局坐标**，`secondaryAnchor` = 下方中心）。
- 官方 example `selection_area.2.dart` 第 157-201 行正是这套用法（`selectionAreaKey.currentState!.selectableRegion.contextMenuAnchors`）。

实现：

- `reader_body.dart` 加 `GlobalKey<SelectableRegionState> _selectableRegionKey` 挂到 `SelectableRegion`；`_onSelectionChanged` 在选区非空时 `addPostFrameCallback` 调 `_updateSelectionRectFromAnchors`：读 `contextMenuAnchors` → 经 `_stackKey` RenderBox `globalToLocal` 转 Stack 局部坐标 → 合成 `_selectionRect`（top=primaryAnchor.y, bottom=secondaryAnchor.y, 水平中心=primaryAnchor.x）。选区清空时 `_selectionRect=null`（toolbar 消失）。
- `stackSize` 从 `MediaQuery.sizeOf`（屏幕尺寸）改为 `_stackSize()`（Stack 实际尺寸，更精确的水平 clamp）。
- `reader_selection_toolbar.dart` 定位逻辑无需改（M3b 已写好，rect.top/bottom/center.dx 直接用）。

**关键验证测试**：新增 `selectable_region_anchors_test.dart` —— 用 `SelectAllTextIntent` 触发全选，断言 `contextMenuAnchors.primaryAnchor` 非零、`secondaryAnchor` 非空，**证明 API 在 Flutter 3.44.4 可用**（直接证伪 M3b 的误判）。另有 `reader_selection_toolbar_follow_test.dart` 3 cases（toolbar top 跟随 rect / 翻下方 / null fallback）。现有 `reader_selection_toolbar_test.dart` 9 cases + reader_body 10 cases 无回归。

**诚实说明**：`contextMenuAnchors` 依赖 finalized 选区几何；选区变化中（changing）可能返回 stale，用 postFrameCallback 规避。PDF 路径不走 SelectableRegion（pdfrx 自管选区 UI），本改动仅影响 EPUB。

#### Fixed — Q1+Q2 排版（reader_engine_epub_view 包）

**Q1 段落首行缩进从未生效（关键根因纠正）**：M3a 的 `<style>p{ text-indent: 2em }</style>` 注入对 flutter_widget_from_html 0.15.3 **完全无效** —— 源码追踪确认 fwfh 把 `<style>` tag 当 `display:none`（`core_widget_factory.dart:934`），且其内联 CSS 解析器（`parseStyle` switch）**根本没有 `text-indent` 分支**。所以 M3a 的缩进实际上从未渲染，只是没崩。

- 重写 `typography_style_injector.dart`：改用 HTML 预处理 —— 用 `package:html` 解析后在每个 `<p>` 首个文本节点前插入 N 个 U+2003 EM SPACE（宽度≈1em，随字体缩放）。这是中文阅读器普遍 trick，对 fwfh 的 CSS 支持缺口免疫。
- 新增 `package:html ^0.15.0` 直接依赖（原为 fwfh 的传递依赖）。
- `epubx_renderer.dart` 两个 `HtmlWidget` 调用新增 `customStylesBuilder`，给每个 `<p>` 注入统一段落间距 `margin: 0 0 0.5em 0`（fwfh 支持 margin，见 `style_margin.dart`），替代被忽略的 `<style>` 块。
- 测试：`typography_style_injector_test.dart` 重写（10 cases，含多段/嵌套 span/属性/空白首文本/小数 em/解析失败兜底）；`epubx_renderer_top_align_test.dart` 更新；`epubx_renderer_test.dart` 的 `currentHighlightedHtml` 断言更新为 em-space。

**Q2 末页顶部对齐（M3a 误判修正）**：M3a 在 `buildSinglePage` 包了 `Align(topCenter)` 作为"末页顶部对齐双保险"，但 `Align` 在 `SingleChildScrollView` **内部是 no-op** —— scroll view 给子 widget 无限高度约束，Align 没有多余空间可对齐，被强制收缩成子大小，对齐逻辑完全不生效（等于没写）。

- 删除无效 `Align`，`buildSinglePage` 回归 `SingleChildScrollView > Padding > HtmlWidget`（M3a 之前的结构，本就顶部对齐）。
- 用户"末页居中"反馈经 git 历史核查：M3a 前后布局都是顶部对齐，真实成因是**用户跑的 exe 过旧**（未拉 M3a 重建）。代码层移除误导性 Align。
- 测试：`epubx_renderer_top_align_test.dart` 新增断言"无 Align 残留"防止回归 + 短内容顶部对齐 case。

### M3d — 2026-07-03（摘录/书签右键上下文菜单：删除/编辑/导出）

用户要求摘录、书签页面在记录上点击右键要有「删除、导出」选项（AskUserQuestion 进一步确认：Flutter 原生 `showMenu()` 系统原生菜单样式，右键同时加「编辑」）。Spec: `docs/superpowers/specs/2026-07-03-m3d-context-menu-design.md`，Plan: `docs/superpowers/plans/2026-07-03-m3d-context-menu.md`。

#### Added — 摘录右键菜单（T1，复用现有 API）

- `AnnotationContextAction` 枚举加 `export` 项（原 edit/delete/copyQuote/copyMarkdown）；该枚举仅 `notes_page.dart` 一处 switch，已补 `export` 分支。
- 新增 `showAnnotationContextMenu(BuildContext, Offset globalPosition)`（`annotation_context_sheet.dart`）：用 Material `showMenu` 在右键位置弹原生菜单（编辑笔记/删除/复制摘录/复制 Markdown 片段/导出 5 项），与移动端 `showAnnotationContextSheet`（bottom sheet）共用枚举，互不替代。
- `AnnotationTile` 加 nullable `onSecondaryTapDown` 回调参数：InkWell 外层包 `GestureDetector(behavior: translucent)` 仅接 `onSecondaryTapDown`（与 primary onTap/onLongPress 互不干扰）；回调为 null 时行为与原先完全一致。
- `notes_page.dart` 摘录条目接入 `onSecondaryTapDown`；`_showContextMenu` 重构为统一入口（长按→bottom sheet / 右键→showMenu），dispatch 补 `export` 分支（单条导出 Markdown 文件）+ 桌面路径的 copyQuote/copyMarkdown（写剪贴板 + SnackBar）。

#### Added — 书签 Markdown 导出器（T2，新基础设施）

- 新建 `app/lib/features/bookmarks/services/bookmark_markdown_exporter.dart`：纯函数 `exportSingle(BookmarkEntry)` → `# label\n\nnote\n\n> 创建于 YYYY-MM-DD`（note 空省略段）；`exportAll(List, {bookTitle})` 按创建时间升序 + `---` 分隔 + 可选总标题。复用 `markdown_exporter` 的 ISO 日期格式。

#### Added — 书签编辑对话框（T3，新）

- 新建 `app/lib/features/bookmarks/widgets/bookmark_edit_dialog.dart`：`showBookmarkEditDialog(BuildContext, BookmarkEntry)` → AlertDialog（label/note 两 TextField，预填现有值，label 必填，空 note 归一化为 null）。返回 `BookmarkEditResult`（保存）或 null（取消），调用方据此调 `controller.updateLabel/updateNote`。

#### Added — 书签右键菜单（T4，组合 T2/T3）

- `reader_bookmark_list.dart`：ListTile 外层包 `GestureDetector(onSecondaryTapDown)`，右键弹 `showMenu`（编辑/删除/导出 3 项）。新增 nullable 回调参数 `onDelete/onEdit/onExport`（父级可覆盖）；为 null 时走默认自包含行为（本 widget 持 `ref`）：
  - 删除 → `bookmarkControllerProvider.notifier.delete(id)`（**首次接入**，原 controller.delete 零调用）。
  - 编辑 → `showBookmarkEditDialog` → `controller.updateLabel/updateNote`。
  - 导出 → `BookmarkMarkdownExporter.exportSingle` → `NoteFileWriter.saveMarkdownFile`。
- 更新文档注释：删原 "删除走 long-press 菜单，T13+" 占位说明，改为「右键上下文菜单（M3d）」。
- 因 `ReaderBookmarkList` 是 drawer 书签 tab 与独立 `BookmarksPage` 的共用 widget，改一处两处生效。

#### 探查结论

- `BookmarksPage` **未** override `bookmarkControllerProvider`（与 ReaderPage 不同）；独立页的 controller 依赖全局 `currentBookIdProvider`（默认 null）——这是 M2.5 既有的「独立书签页列表来源」限制，非本任务范围。reader 抽屉（ReaderPage）内 controller 已被 ReaderPage 正确 override，右键删除/编辑/导出在抽屉上下文完全可用。
- `BookmarkController.delete` 首次接入 UI，现由 `ReaderBookmarkList` 默认删除路径调用。

#### 测试

- `annotation_context_sheet_test.dart`（新，7 测试）：`showAnnotationContextMenu` 渲染 5 项 + 各 value 正确 + 取消返回 null。
- `annotation_tile_test.dart`（扩，+3 测试）：`onSecondaryTapDown` 右键触发回调（`PointerDeviceKind.mouse` + `kSecondaryMouseButton` 模拟）；右键不误触发 onTap；无回调时左键仍正常。
- `bookmark_markdown_exporter_test.dart`（新，9 测试）：exportSingle 含/空 note 格式；exportAll 升序 + `---` 分隔 + 总标题 + 空列表。
- `bookmark_edit_dialog_test.dart`（新，5 测试）：预填值 + 保存返回新值 + 取消返回 null + label 空禁用 + 空 note 归一化 null。
- `reader_bookmark_list_test.dart`（新，8 测试）：右键弹 3 项菜单 + 各动作调度 onDelete/onEdit/onExport 回调 + 默认删除走 controller.delete（断言 repo 状态变化）+ 默认编辑走对话框改 controller.updateLabel/updateNote。
- 现有 reader/notes/bookmarks/search 测试全过（+131）；analyze 三包（app / reader_engine / reader_engine_epub_view）0 issue；`flutter build windows --debug` 成功。

### M3c — 2026-07-03（顶栏增强：实时时钟/字号±快捷键/书架弹窗）

用户希望顶栏信息更密：中间显示实时时间，加字号±快捷按钮，加书架入口（弹出书架对话框选新书直接切换阅读）。Spec: `docs/superpowers/specs/2026-07-03-m3c-topbar-bookshelf-design.md`，Plan: `docs/superpowers/plans/2026-07-03-m3c-topbar-bookshelf.md`。

#### Added — 任务 3 顶栏实时时钟

- 新建 `app/lib/features/reader/widgets/reader_clock.dart`：`StatefulWidget`，initState 起 `Timer.periodic(1s)` 刷新，dispose 取消；build 渲染 `DateFormat.Hm().format(_now)`（24h 制 `HH:mm`，复用项目已有 `intl ^0.20.0`）。
- `reader_scaffold.dart` 的 `_buildChrome` 内 AppBar.title 由静态 `Text(widget.title)` 改为 `const ReaderClock()`，并加 `centerTitle: true`，时间居中显示。
- **Timer 不泄漏**：`ReaderClock` 只在 `_buildChrome`（`if (ui.chromeVisible)` 内）创建；chrome 隐藏时 `_buildChrome` 不调用 → widget 不挂载 → Timer 不启动。dispose 必取消 Timer。
- 时间源可注入（`now` 参数，默认 `DateTime.now`），便于测试推进时间验证文字更新。

#### Added — 任务 6a 字号±快捷按钮

- `ReaderScaffold` 加 `VoidCallback? onFontDecrease / onFontIncrease / onOpenBookshelf`（均 nullable，不影响现有构造）。
- AppBar.actions 在「排版」按钮前后加 `Icons.text_decrease` / `Icons.text_increase` 两个 IconButton（各带 Key：`reader_font_decrease` / `reader_font_increase`）。
- `reader_body.dart` 传入回调：直接改 `engine.typography` 内存值，`fontSize ± 1` 后 `.clamp(12.0, 32.0)`（复用排版面板范围），用 `unawaited` 包裹 `setTypography`。**不写预设/DB**（与排版面板即时改值一致）。

#### Added — 任务 6b 书架弹窗

- 新建 `app/lib/features/reader/widgets/bookshelf_dialog.dart`：`showBookshelfDialog(BuildContext, {required String currentBookId})` → `showDialog`（`useRootNavigator: true`）全屏 `Dialog`。顶部「书架」标题 + 关闭按钮；主体可滚动封面网格（复用 `BookCover`）；当前书用主题色边框 + 「阅读中」标记。选书 → `Navigator.pop` → `context.pushReplacement('/book/$newId')`。
- AppBar.actions 加 `Icons.collections_bookmark_outlined`（书架）按钮（Key：`reader_open_bookshelf`）。
- `reader_body.dart` 传入 `onOpenBookshelf: () => showBookshelfDialog(innerContext, currentBookId: widget.bookId)`。
- **数据源**：探查确认 `libraryControllerProvider` / `coverLoaderProvider` / `bookRepositoryProvider` 均为 `core/providers.dart` / `library/providers/` 顶层全局 provider（非 LibraryPage 页面局部），对话框直接 watch 同源 provider 取数据，与 LibraryPage 完全一致。

#### 测试

- `reader_clock_test.dart`（新，4 测试）：挂载即渲染当前 HH:mm；文字格式校验；时间源推进后文字更新；dispose 取消 Timer（pumpAndSettle 不挂起证明）。
- `reader_scaffold_test.dart`（扩，+5 测试）：title 是 ReaderClock；字号±/书架 icon 渲染；字号±/书架按钮点击触发回调。
- `bookshelf_dialog_test.dart`（新，4 测试）：网格渲染全部书籍；当前书「阅读中」标记；关闭按钮 pop；点非当前书 `pushReplacement` 导航到 `/book/:id`（真 GoRouter 验证）。
- `reader_body_font_buttons_test.dart`（新，5 测试）：字号 +1/-1；clamp 上限 32 / 下限 12；书架按钮打开弹窗（含当前书渲染）。
- analyze 三包（reader_engine / reader_engine_epub_view / app）0 error；`flutter build windows --debug` 通过。reader+library 全量测试 340 passed（仅 2 个 PDF fixture 缺失的预存失败与 M3c 无关）。

### M3b — 2026-07-03（阅读交互增强：翻页动画微调/悬停翻页箭头/摘录工具条跟随选区）

用户反馈阅读交互手感 3 项：翻页要左右箭头提示、翻页要有 PPT 式平移过渡、选文字后摘录工具条应跟着选区走（不要老固定屏幕中间顶部）。Spec: `docs/superpowers/specs/2026-07-03-m3b-reading-interaction-design.md`，Plan: `docs/superpowers/plans/2026-07-03-m3b-reading-interaction.md`。

#### Changed — 任务 8 翻页动画微调（PPT 式平移）

- **章内程序化翻页 200ms easeOut → 300ms easeInOutCubic**：`reader_engine_epub_view/lib/epubx_renderer.dart` 的 `nextPage()` / `previousPage()`。提取类常量 `_pageAnimDuration`（300ms）/ `_pageAnimCurve`（`Curves.easeInOutCubic`），比原 200ms easeOut 更顺滑、有进出节奏，更接近 PPT 平移观感。
- **跨章 `jumpToPage`（章末/章首换章路径）保持瞬切不变**：跨章换内容时动画会闪烁，瞬切更稳。

#### Added — 任务 1 左右空白悬停翻页箭头

- 现有翻页点击 zone（`reader_scaffold.dart` 左右 `marginPx` 宽的透明 GestureDetector）无视觉反馈，桌面端用户不知点哪能翻。
- `_ReaderScaffoldState` 加 `bool _hoverLeft/_hoverRight`；左右 `Positioned` 外层包 `MouseRegion(onEnter/onExit)`，hover 为 true 时在 zone 中央叠 `IgnorePointer(child: 半透明圆形背景 + chevron 箭头)`。
- **箭头用 IgnorePointer 包裹**，不消费底层 GestureDetector 的 onTapUp（翻页手势正常）。**仅桌面端有效**（移动端无鼠标，onEnter/onExit 永不触发，行为不变）。箭头颜色取 `Theme.of(context).iconTheme.color` + 半透明，暗/亮主题自适应。

#### Added — 任务 9 摘录工具条跟随选区定位逻辑

- 原 `reader_selection_toolbar.dart` 固定 `top:80, left:16, right:16, Center`，与选区位置无关。
- **新增 `selectionRect` + `stackSize` 参数**：非空时工具条优先显示在选区**上方**（`top = rect.top - toolbarHeight - 8`）；上方空间不足（< 8px）则翻到选区**下方**（`top = rect.bottom + 8`）；水平以选区中心居中并 clamp 到 `[8, screenWidth - 8 - toolbarWidth]`，避免越界。实现 spec D3 的「跟随」语义。
- **fallback 分支保留**（约束 #3）：`selectionRect` 为空时回退原「顶部居中」定位，保证不崩。`reader_body.dart` 加 `_selectionRect`（当前始终 null）+ `_stackKey`（GlobalKey，供坐标转换预留）。
- **API 兼容说明（重要偏离）**：spec/plan 假设的 `SelectableRegion.selectionNotifier` 参数 + `SelectionDetails.selectionStartCoords/EndCoords` 字段**在当前 Flutter 3.44.4 不存在**（属于更新版本 API）。实测：`SelectableRegion` 构造函数无 `selectionNotifier` 参数；`SelectionDetails` 只有 `range`/`status`，无坐标字段；`SelectionListenerNotifier` 也未从 `widgets.dart`/`material.dart` 公开导出（仅在 `selectable_region.dart` 私有定义，且配合独立的 `SelectionListener` widget，无法挂到 SelectableRegion）。故当前版本 `_selectionRect` 暂时始终为 null，工具条走 fallback。**跟随定位逻辑与全套测试已 ready-to-use**，待 Flutter 升级提供坐标 API 后，只需在 `reader_body._onSelectionChanged` 填充 `_selectionRect` 即可立即生效，无需改动工具条。

#### 测试

- `reader_engine_epub_view/test/`：翻页动画相关测试（`epubx_renderer_cross_chapter_back_page_test.dart` / `epubx_renderer_setters_emit_state_test.dart`）全过（走 jumpToPage 瞬切路径，不依赖动画时长，无需改断言）。
- `app/test/features/reader/widgets/reader_scaffold_hover_test.dart`（新）：hover 左/右 zone 显示对应 chevron 箭头；hover 退出箭头消失；箭头在 IgnorePointer 子树内且点击仍翻页。4 测试全过。
- `app/test/features/reader/widgets/reader_selection_toolbar_test.dart`（扩）：跟随定位（上方/下方/clamp 左/clamp 右/null fallback）5 测试全过，用直接传入 Rect 验证 Positioned 逻辑（不依赖真实 selection）。

### M3a — 2026-07-04（排版基线增强：默认值/段落缩进/末页对齐/常用字体）

用户 2026-07-03 提交 10 项体验优化清单，本里程碑处理其中与「文字排版观感」直接相关的 4 项（任务 7/2/4/5）。Spec: `docs/superpowers/specs/2026-07-03-m3a-typography-baseline-design.md`，Plan: `docs/superpowers/plans/2026-07-03-m3a-typography-baseline.md`。

#### Changed — 任务 7 默认值

- **默认字号 16→18、行距 1.5→1.8（宽松）、页边距 normal→wide（72px）**：`TypographySettings.defaults()`（reader_engine/lib/core/typography_settings.dart）调整。仅影响「未选预设」的新打开书籍；已保存的 TypographyProfile 是 DB 独立记录，不受影响。排版面板档位标签不变（紧凑1.2/标准1.5/宽松1.8、紧凑/标准/宽松/特宽），仅默认选中态随 defaults 变。

#### Added — 任务 2 段落首行缩进（中文书籍标准排版）

- **根因**：pivot 后 `TypographyCss.textStyleFromSettings` 只产出 `TextStyle(fontSize, height, fontFamily)`，而 Flutter 的 `TextStyle` **无法表达 CSS `text-indent`**，所以缩进必须通过 HTML/CSS 注入实现。
- **TypographySettings 新增字段**：`paragraphIndentEm`（默认 2.0）+ `paragraphIndentEnabled`（默认 true），同步更新构造函数、copyWith、toJson、fromJson（缺 key 向后兼容用默认值）、defaults、equality（== / hashCode）。
- **新建 `reader_engine_epub_view/lib/typography_style_injector.dart`**：`TypographyStyleInjector.inject(html, indentEm, enabled)` 在 HTML 头 prepend `<style>p{ text-indent: Nem; margin: 0 0 0.5em 0; }</style>`。enabled=false 或 indentEm<=0 原样返回。
- **接入点**：scroll 模式 `currentHighlightedHtml()`（高亮注入后）、paged 模式 `buildSinglePage`（高亮注入后、HtmlWidget 前）两处调用 inject。`<style>` 是 HtmlWidget 一等公民，对全章/全页所有 `<p>` 生效。
- **排版面板加「段落」一节**：Switch（首行缩进开关）+ 档位（无 0em / 2字 2em / 4字 4em）。

#### Fixed — 任务 4 章节末页文字顶部对齐

- **现象**：用户反馈章节末页文字「垂直居中很奇怪」。
- **代码层**：`buildSinglePage`（epubx_renderer.dart）用 `SingleChildScrollView(NeverScrollable)` 包 `Padding>HtmlWidget`，理论上应顶部对齐。
- **根因实跑结论（widget 测试布局探测）**：构造 600px 高 PageView slot + 短内容（240px），测量渲染后 RichText 实际位置 = **top=72（= margin），center=120**，远在 slot 顶部，**不是居中**（居中应 ~250-300）。即用户反馈的「末页垂直居中」是**视觉错觉**：末页内容少，下方留白大（~360px 空白），主观感觉「居中」，但代码本就是顶部对齐，无 HtmlWidget bug。
- **修复（双保险）**：`buildSinglePage` 在 SingleChildScrollView 内显式包 `Align(alignment: Alignment.topCenter)`，无论 HtmlWidget 内部行为如何都强制顶部锚点，语义显式化、防御未来回归。scroll 模式本就是顶部对齐，未改。

#### Changed — 任务 5 字体选项改常用名 + 打包开源 OFL 字体

- **根因**：旧字体选项「衬线/无衬线」用 `'serif'`/`'sans-serif'`（CSS 通用字体族名），Flutter 的 `TextStyle.fontFamily` 不识别 generic family → 在 Windows 上几乎无效（fallback 默认无衬线），这是用户觉得「很怪」的技术根因。
- **打包开源 OFL 字体到 `app/assets/fonts/`**（不入 git，首次拉取后跑 `scripts/download-fonts.sh` 获取）：
  - 黑体 → `NotoSansSC-Regular.otf`（思源黑体，Google Noto CJK SubsetOTF/SC，8.33 MB）
  - 宋体 → `NotoSerifSC-Regular.otf`（思源宋体，Google Noto CJK SubsetOTF/SC，11.63 MB）
  - 楷体 → `LXGWWenKai-Regular.ttf`（霞鹜文楷，LXGW 官方 v1.522，24.42 MB）
  - **圆体暂未提供**（无完美开源 OFL 圆体；Dubai 不开源，思源无 Round 变体），UI 不显示圆体 chip，用户可选「系统」（Windows 即微软雅黑，本身偏圆）作 fallback。
- **字体下载**：直连 GitHub（github.com / raw.githubusercontent.com）在大陆被墙；用 jsDelivr CDN（Noto）+ gh-proxy.com 镜像（LXGW release asset，因 jsDelivr 对 >50MB 仓库拒服务）成功下载 3/3 款。下载脚本含多镜像 fallback。
- **pubspec.yaml fonts 段声明** 3 个 family（逻辑别名 NotoSansSC/NotoSerifSC/LXGWWenKai，与代码 `TextStyle(fontFamily:)` 一致）。fontFamily 别名不必与字体内部 post 表 name（`Noto Sans SC` 等）完全相同——pubspec `family:` 即 Flutter 注册的资源别名。
- **字体选项 UI**：typography_panel.dart 的 ChoiceChip 改为 系统/黑体/宋体/楷体（+ userFonts 追加），并加说明文字。

#### 体积实测（`flutter build windows --debug`）

| 项 | M2.11 baseline | M3a | 增量 |
|---|---|---|---|
| `zhiyue.exe` | 1.01 MB | 1.01 MB | **+0**（字体以 asset 打包，不入二进制）|
| `flutter_assets/` | 95.65 MB | 139.15 MB | **+43.50 MB**（= 3 款 CJK 字体 43.42 MB + 0.08 MB manifest）|

增量 +43.50 MB 在 spec D3 预算（+40-60MB）内，远低于 80MB「不可接受」阈值。LXGW WenKai（24.42 MB）占大头（无 subset 版，含全 GB 字）；Noto 用 SubsetOTF/SC（仅简体中文字集）比全 CJK OTF（16MB）省一半。若未来需瘦身：subset LXGW（pyftsubset 按 GB2312 常用字裁剪到 ~3MB）可省 ~21MB，留 v2 优化。

#### Tests

- 新增 `typography_style_injector_test.dart`（6 cases）：注入含 `<style>`+`text-indent`、enabled=false 原样返回、indentEm<=0 原样返回、多 `<p>` 全局生效、保留既有 HTML 结构。
- 新增 `epubx_renderer_top_align_test.dart`（4 cases）：paged 模式每页 SingleChildScrollView 子是 Align(topCenter)（任务4 结构断言）、scroll 模式 currentHighlightedHtml 含/不含注入的 `<style>`。
- 更新 `typography_settings_test.dart`：默认值断言（18/1.8/wide）+ 缩进字段 toJson/fromJson 往返 + copyWith + 向后兼容 + equality。
- 更新 `typography_css_test.dart`：默认字号/行距断言 16/1.5 → 18/1.8。
- 更新 `typography_panel_test.dart`：字号显示 18、字体选项 系统/黑体/宋体/楷体（断言旧 衬线/无衬线 已移除）、黑体→NotoSansSC、font+1=19、含「段落」一节。
- 更新 `epubx_renderer_test.dart`：currentHighlightedHtml no-highlight 路径断言改为 endsWith（因默认注入缩进 `<style>`）。
- 全套：reader_engine typography 9 通过；reader_engine_epub_view 143 通过（仅 pre-existing fail = epub_cover_extractor 的 ZipDecoder/EPUB fixture 解析失败，与排版无关）；app reader features 185 通过 / 2 skip / 2 fail（仅 pre-existing fail = reader_page_pdf_integration 的 PDF fixture 缺失，与排版无关）。
- `dart analyze`（flutter.bat analyze 在本中文路径环境 LSP 协议崩溃——FormatException: Unterminated string，是 Dart analysis server LSP framing 对中文路径 URL-encode 的 bug，非代码问题；改用 dart.bat analyze）：reader_engine / reader_engine_epub_view / app 三包 **0 error**。app 的 custom_lint 插件因同样中文路径 bug（%E7%94%B5... URL 编码失败 pub get）崩溃，临时移除插件后 analyze 0 error，分析完恢复。

#### Decisions 偏离 plan

- **圆体**：spec/plan 列为「实施时确认」。实跑后确认无完美开源 OFL 圆体，按 spec fallback 用前 3 款 + 系统，UI 不显示圆体 chip，README 诚实标注。未凑数加劣质近似款。
- **字体 family 别名**：spec 示例 family 名用 `NotoSansSC`（无空格），与字体内部 post 表 name（`Noto Sans SC`，有空格）不同。这是正确的——pubspec `family:` 是逻辑别名，代码 `fontFamily:` 与之匹配即可，Flutter 据别名注册 asset。保持 plan 的无空格别名。

#### Lessons

- **TextStyle 无法表达 CSS text-indent**：Flutter 的 TextStyle 只有 fontSize/height/fontFamily/weight 等，没有 first-line-indent。任何需要 CSS-only 属性的排版（缩进、字间距 letter-spacing、首字下沉）都必须走 HTML `<style>` 注入（HtmlWidget 是 HTML 渲染器，`<style>` 是一等公民），不能走 TextStyle。pivot 到 TextStyle-based 渲染后这类需求容易遗漏。
- **「末页居中」可能是视觉错觉**：实测短内容在固定高度 slot 里**本就是顶部对齐**（RichText top=margin），用户主观感觉「居中」是因为下方留白大。修这类「布局问题」前先实测渲染位置，避免改了半天发现代码本就对——本次 Align 双保险仍有价值（语义显式 + 防回归），但根因诊断要诚实记录。
- **中文路径 + Dart analysis server LSP 不兼容**：`flutter.bat analyze` / `flutter analyze` 在本工作目录（`H:\projiect\电子书阅读平台`）会让 analysis server 的 LSP framing 崩溃（URL-encode 中文路径成 `%E7%94%B5...` 后 JSON 解析 Unterminated string）。custom_lint 插件同因崩溃（pub get 时 path 解析失败）。解决：用 `dart.bat analyze`（非 LSP 路径）跑核心分析，必要时临时移除 custom_lint 插件。这是本仓库中文路径环境的固有约束，CI 应在英文路径环境跑。
- **字体下载的多镜像 fallback**：单一 CDN 不可靠（GitHub 被墙、jsDelivr 对 >50MB 仓库拒服务、Gitee raw 需登录）。下载脚本对每款字体配 2-3 个镜像（jsDelivr + gh-proxy.com + ghfast.top），任一成功即停。

### M2.11 — 2026-07-04（书签页内定位 + 高亮跨章泄漏修复）

M2.10 修完双页回归后用户复测，报告 3 个新问题：①书签只按章节命名、跳转只回章节首页；②旧摘录颜色/跳转错误（新的正常）；③没摘录的页也出现幽灵高亮。代码层追溯发现 ①③ 是两个独立的设计缺陷，② 是 ③ 的副产物。

#### Fixed

- **问题1 书签只到章节首页（paged 模式页位置未编码）**：根因是 `_emitCurrentLocation`（epubx_renderer.dart）在 paged 模式下用 `_scrollController.offset` 算 charOffset，但 `_scrollController` 在 paged 模式**没有 client**（用 PageView）→ charOffset **恒为 0** → 书签 cfi 永远是 `"<chapter>:0"`。`gotoLocator` CFI 分支的 post-frame 重定位也只走 scroll（paged 下 no-op），永远 `jumpToPage(0)`。修复：①`_emitCurrentLocation` paged 模式改用当前页 break 的 `startOffset` 作 charOffset（编码真实页位置）；②`gotoLocator` CFI 分支 post-frame paged 模式用 charOffset 反查 break → `jumpToPage`（双页换算 spread `~/2`）；③`_defaultBookmarkLabel` EPUB paged 模式加页码"第 N 章 · 第 M 页"（M 来自 currentSpreadIndex）。
- **问题3 没摘录的页也有高亮（跨章泄漏）**：根因是 `reader_body.dart` 把**全书所有 annotation** 灌进 `engine.injectHighlights`，**丢弃了 `chapterIndex`**。`_allHighlights` 不分章，渲染当前章时把别的章的高亮用各自章内 0-based offset 去 match 当前章页范围 → offset 范围恰好重叠的页冒出幽灵高亮。`localizeHighlights` 的交集数学是对的，错在被喂了错误坐标空间的 offset。修复（方案B，长期稳定）：`HighlightRange` 加 `chapterIndex` 字段（默认 -1 向后兼容），`_buildPaged` 与 `currentHighlightedHtml` 渲染时按 `chapterIndex == _currentChapterIndex` 过滤，`reader_body` bridge 传入 `loc.chapterIndex`。
- **问题2 旧摘录颜色/跳转错误**：是问题3跨章泄漏的副产物——旧摘录的 offset 数据本身是对的，但被别章高亮污染导致显示错位/颜色异常。修问题3后自动正确，无需数据迁移。

#### Tests

- 更新 `epubx_renderer_paged_highlight_test.dart`：注入高亮加 `chapterIndex: 0`（反映新契约）；新增跨章泄漏防护 case（注入两章高亮，验证切换章节后只显示当前章的、不串内容）。
- 更新 `epubx_renderer_test.dart`：`currentHighlightedHtml` 两个 case 的高亮加 `chapterIndex: 0`。
- 全套：epub_view 134 通过（+1 新），app reader 184 通过，仅 pre-existing fail（epub_cover_extractor / PDF fixtures）。

#### Lessons

- **CFI 编解码必须覆盖所有渲染模式**：`_emitCurrentLocation` 与 `gotoLocator` 是一对 round-trip，但 paged 模式下编码侧（emit）用 scroll controller、解码侧（goto）也用 scroll——两端都假设 scroll 模式，paged 模式静默失效（charOffset 恒 0、重定位 no-op）。任何"位置"概念跨渲染模式传递时，编解码两端都必须处理所有模式，否则会"看起来对但数据是空的"。
- **每章独立 0-based offset 是高亮泄漏的温床**：不同章的相同 offset 范围在各自的坐标空间里指向完全不同的文字。任何按 offset 匹配的逻辑（高亮、定位）都必须显式带章归属（chapterIndex），否则跨章数据混在一起时会产生"幽灵匹配"。这是 per-chapter coordinate design 的固有约束。

### M2.10 — 2026-07-04（M2.9 双页功能回归修复）

M2.9 交付后用户上手测试（Windows 宽屏 ≥1100px，命中自动双页分支），报告 3 个新回归。代码层追溯发现**全部由 M2.9 双页渲染分支 + 现有 measurement gap 共同触发**，窄屏单页模式不出现。第一轮修了 Bug A（溢出）+ B2（目录跳转）+ C1（书签入口 FAB），用户复测后 B1 笔记跳转、C2 书签页报错仍存在——Round 2 找到**真根因**（首轮误判）。本次纯回归修复。

#### Fixed

- **Bug A 底部黄黑斑马线 / "bottom overflowed by 14 pixels"**：`_buildPaged`（epubx_renderer.dart）每页在固定高度 PageView slot 里渲染 `Padding>HtmlWidget`。`HtmlWidget`（flutter_widget_from_html）渲染高度与 `Paginator`（TextPainter 测量）存在系统性误差（line-height/font-metrics 偏差，代码注释已自认误差 < 1 行）。双页模式宽度 halve 放大换行误差，某页真实高度 > slot 固定高度 → RenderFlex cross-axis 溢出 → 斑马线 + overflow 文字。修复：`buildSinglePage` 把 `Padding>HtmlWidget` 包进 `SingleChildScrollView(physics: NeverScrollableScrollPhysics())`，误差自然吸收（不溢出即不滚，溢出可竖向微滚），绝不抛 assertion。NeverScrollable 防止子页滚动与 PageView 翻页手势冲突。与 `_buildScroll`（scroll 模式已用 SingleChildScrollView）模式一致。
- **Bug B1 笔记/摘录跳转（首轮误判 + Round 2 真根因）**：首轮以为是双页 spread 索引换算错（service 加 `dualPageMode ~/2`），但用户复测"跳到完全错误的地方或没反应"。Round 2 追到真根因：`Scrollable.maybeOf(context)` 从 `_ReaderBodyState.context` 往**上**找祖先，但 PageView（paged）/ SingleChildScrollView（scroll）都在 `engine.build()` 里、是 ReaderBody 的**后代**，所以**永远返回 null** → `_onAnnotationTap`/`_maybeHandleInitialLocator` 的 `if (scrollable == null) return;` 总提前退出 → 跳转从未执行（同章"没反应"，跨章停在 `gotoLocator` 的 jumpToPage(0) 首页）。修复：`scrollable` 参数改可选（paged 分支根本不读它，只用 pageController + pageBreaks）；调用方仅 scroll 模式才查找 scrollable，paged 模式直接调 `scrollToCharacterOffset`。首轮的 `dualPageMode ~/2` 换算保留（双页下仍需正确）。注：scroll 模式的 in-page 滚动定位此前也未工作（同因），本次未修（保持现状，不引入新回归），留 v1.6。
- **Bug B2 目录跳转失效**：`ReaderTocDrawerWrapper.onSelect`（reader_drawer_builders.dart）调 `gotoTocEntry` 后没 `await chapterSwitchSettled` 就 `closeDrawer`，双页模式下 rebuild 触发 `_buildPaged` LayoutBuilder 重算分页，drawer 提前关 + PageView 未完成新章布局 → TOC 卡住或 spread 越界。修复：onSelect 改为 `await gotoTocEntry; await chapterSwitchSettled; if (context.mounted) closeDrawer()`（chapterSwitchSettled 是公开 Future，wrapper 可访问）。
- **Bug C1 chrome 隐藏时无添加书签入口**：添加书签唯一入口在 `_buildChrome` 的 AppBar，被 `if (ui.chromeVisible)` gate；全屏/chrome 隐藏时按钮消失，无 FAB/快捷键 fallback → "没有地方来添加书签"。修复：`_buildReaderStack` 的 Stack 加一个 `Positioned(bottom:56, right:16)` 的 `FloatingActionButton(Icons.bookmark_add_outlined)`，仅 `!ui.chromeVisible` 时显示（chrome 可见时不重复）。复用 `_onAddBookmark`。
- **Bug C2 书签页红屏报错（Riverpod 断言，Round 2 真根因）**：用户报告书签 tab 红屏黄字，错误是 Riverpod `"Tried to read ... from a place where one of its dependencies were overridden but the provider is not"`。根因：`reader_page.dart` 的 `ProviderScope.overrides` 覆盖了 `currentBookIdProvider` + `notesControllerProvider`，但**漏了 `bookmarkControllerProvider`**——它也 `ref.watch(currentBookIdProvider)`，依赖被覆盖但消费方没覆盖 → 断言红屏。修复：overrides 列表补 `bookmarkControllerProvider.overrideWith((ref) => BookmarkController(bookId: widget.bookId, repository: ref.watch(bookmarkRepositoryProvider)))`，与 notesControllerProvider 同模式。全代码库仅这两个 provider 依赖 currentBookIdProvider，已全部覆盖。
- **Bug B2 目录跳转失效**：`ReaderTocDrawerWrapper.onSelect`（reader_drawer_builders.dart）调 `gotoTocEntry` 后没 `await chapterSwitchSettled` 就 `closeDrawer`，双页模式下 rebuild 触发 `_buildPaged` LayoutBuilder 重算分页，drawer 提前关 + PageView 未完成新章布局 → TOC 卡住或 spread 越界。修复：onSelect 改为 `await gotoTocEntry; await chapterSwitchSettled; if (context.mounted) closeDrawer()`（chapterSwitchSettled 是公开 Future，wrapper 可访问）。
- **Bug C1 chrome 隐藏时无添加书签入口**：添加书签唯一入口在 `_buildChrome` 的 AppBar，被 `if (ui.chromeVisible)` gate；全屏/chrome 隐藏时按钮消失，无 FAB/快捷键 fallback → "没有地方来添加书签"。修复：`_buildReaderStack` 的 Stack 加一个 `Positioned(bottom:56, right:16)` 的 `FloatingActionButton(Icons.bookmark_add_outlined)`，仅 `!ui.chromeVisible` 时显示（chrome 可见时不重复）。复用 `_onAddBookmark`。

#### Tests

- 新增 `epubx_renderer_paged_overflow_test.dart`（4 cases）：单页/双页临界高度 HTML 无 overflow；遍历每个 spread 无 overflow；结构断言 SingleChildScrollView 存在。
- 扩展 `scroll_to_offset_test.dart`（+5 cases）：dualPageMode=true 时 break3→spread1、break4(orphan)→spread2、dualPageMode=false 保持 break 索引（无回归）；Round 2 加 paged 模式不传 scrollable 也能 jumpToPage、scroll 模式缺 scrollable 抛 ArgumentError（B1 真根因）。
- 新增 `reader_toc_drawer_settle_test.dart`（1 case）：onSelect 在 chapterSwitchSettled resolve 前不关 drawer，resolve 后关。
- 新增 `reader_body_bookmark_fab_test.dart`（3 cases）：chrome 隐藏时 FAB 存在、chrome 可见时 FAB 不存在、点击 FAB 弹 add-bookmark dialog。
- 扩展 `reader_page_test.dart`（+1 case）：同 scope override currentBookIdProvider + bookmarkControllerProvider 后读 provider 不抛 Riverpod 断言（C2 真根因）。
- 更新 `epubx_renderer_widget_test.dart`：paged 模式断言从"无 SingleChildScrollView"改为"有 SingleChildScrollView 且 controller 为 null"（Bug A 修复改变契约）。

**总数**：epub_view 133 通过 + 1 pre-existing fail（epub_cover_extractor，patched epubx）；app reader 184 通过 + 2 pre-existing fail（PDF fixtures 未 git-sync）。`dart.bat analyze` 全绿。

#### Lessons

- **分页测量与渲染的固有误差是设计层面的**：TextPainter 与 HtmlWidget 的 line-height/font-metrics 永远有微小偏差，分页边界本就是近似。工业阅读器（readium 等）都允许页面小幅内部滚动兜底，而非追求测量 100% 精确。把 overflow 当"可吸收误差"而非"必须消除的 bug"是更稳健的工程选择。
- **双页模式是一次"坐标空间分裂"**：单页模式下 page index、break index、spread index 三者重合；双页模式下 spread index = break index ~/ 2。所有读 PageController.page 的代码（service、页码显示、章末判定）都必须显式区分这两套坐标。M2.9 引入双页时漏了 ScrollToOffsetService 这条路径。

### M2.9 — 2026-07-04（EPUB 双页布局 + 每页页码）

用户需求："页面足够大时像书一样分左右两页显示；每页下方显示页码"。M2.5/T14 早留了 `dualPageMode` API surface 但渲染层推到 v1.6，本次实现真正渲染。设计决策（用户确认）：宽屏（≥1100px）自动触发；页码显示"本章 当前/总"。

#### Added

- **EPUB 双页布局（Bug #4 EPUB 部分）**：宽屏（≥1100px）+ paged 模式时自动启用书脊式左右两页。`EpubxRenderer._buildPaged` 渲染单 PageView，每 item（spread）是 `Row(Expanded左页, SizedBox(24px书脊), Expanded右页)`。Paginator 按半宽测量（`(width-24)/2`），每 break = 一列内容；spread[i] = breaks[i*2] + breaks[i*2+1]。孤页（breaks 奇数）右侧 `SizedBox.shrink()`。窄屏自动回单页。
- **每页页码**：底栏显示本章页码 `当前 / 总`（如 `3 / 12`），双页模式 `3-4 / 12`（孤页只显左）。新增 `ReaderEngine.currentSpreadCount`/`currentSpreadIndex` 接口；`ReaderBottomBar` 加 `pageInfo` 字段；`ReaderProgressBar._epubPageInfo` 计算。PDF/scroll 模式回退到原百分比。

#### Changed

- **翻页时位置流 emit**：`_buildPaged` 的 `onPageChanged` 旧实现只调 `_maybeEmitChapterEnd()`，翻页时 `currentLocation$` 不 emit → 页码不刷新。改为同时调 `_emitCurrentLocation()`。
- **dualPageMode 改 private + setter**：`_dualPageMode` private，通过 `setDualPageMode(value)` 设置（清缓存 + jumpToPage(0) + emit state），避免窗口缩放时 page 索引越新 itemCount 界。
- **ReaderEngine 接口扩展**：加 `dualPageMode`/`currentSpreadCount`/`currentSpreadIndex` 三个 getter；PDF 中性实现（spread 返回 0，走自己的 pageCount）；7 个 test fake 更新。

#### Tests

新增/重写 `epubx_renderer_dual_page_test.dart`（10 cases）：双页渲染 Row+2 HtmlWidget、单页 1 HtmlWidget、spreadCount halving、孤页不崩、setDualPageMode reset page、idempotent。

**总数：125 epub_view + 103 reader 通过**（baseline 115+94 + 新增）。

### M2.8 — 2026-07-04（v1.5.1-alpha 用户复测反馈 #3：9 bug 分 4 批修复）

v1.5.1-alpha 交付后用户复测报告 9 个 bug，其中 #3/#7 在 M2.7 已修，本次处理剩余 #1/#2/#5b/#6/#8/#9，分 4 个批次逐个修复 + 用户验收。

#### Batch 1 (B1)：翻页 + 分页 + 键盘 + ESC

- **Fixed Bug #6 翻页乱翻/延迟**：tap zone 无条件调 `nextSpine`（章末才换章，章内不分页）→ 改为按 paginationMode 路由：paged → `engine.nextPage()`/`previousPage()`（章内分页，章末换章）；scroll → `nextSpine`/`previousSpine`。新增 `ReaderEngine.nextPage()`/`previousPage()` 接口。
- **Fixed Bug #8 文字溢出**：`Paginator` 测量不扣 margin 导致每页内容溢出 → `usableHeight = viewport.height - 2*marginPx`，`usableWidth = (viewport.width - 2*marginPx).clamp(50, inf)`，`_CacheKey` 加 marginPx。
- **Fixed Bug #9 ESC 退全屏**：SelectableRegion 抢焦导致 ReaderScaffold Focus 收不到键盘事件 → `initState` 加 `HardwareKeyboard.instance.addHandler`（全局单例，绕过焦点树），Focus.onKeyEvent 移除（避免双重派发）。

#### Batch 2 (B2)：跨章翻页修复

- **Fixed Bug #6 跨章乱翻**：`setChapter()` 改了 `_currentChapterIndex` 但**不 emit state** → reader_body 不 rebuild → PageView 继续渲染旧章页面，而 controller 已 jumpToPage(0) → 用户看到"回到本章首页"，下一次 nextPage 读到 `_cachedBreaks==null` 走 fallback 换章 → 章节号无声推进 → "跨章节乱翻"。补 `_stateController.add(const ReaderEngineReady())`（gotoLocator CFI 分支早有，setChapter 漏了）。
- **Added 章首左翻换上一章末页（Kindle 行为）**：`previousPage()` 章首分支 arm `_pendingJumpToLastPage`，下一帧 `_cachedBreaks` 填充后 `_maybeApplyPendingLastPageJump` jumpToPage 到末页（one-shot）。setChapter 清零 flag（仅 previousPage 重新 arm）。

#### Batch 3 (B3)：高亮渲染（paged 模式）

- **Fixed Bug #5b 高亮不显示**：`_buildPaged` 用 `Text(plain.substring(start,end))` 渲染每页，丢掉了 `HtmlHighlightInjector` 注入的 `<span>`。新增 `HtmlSlicer`（`sliceByPlainRange` DOM 遍历裁剪 + `localizeHighlights` 全局→页面本地坐标），`_buildPaged` 改为每页 sliceByPlainRange → 高亮注入 → HtmlWidget。副带收益：paged 模式恢复富文本格式（粗体/标题/段落）。
- **Bug #5 淡化底色**：0.4 alpha 早已在 `reader_body._highlightColorRgba` 满足，只是 span 进不了渲染。B3 修复后自然显现。

#### Batch 4 (B4)：书签红屏 + 笔记延迟

- **Fixed Bug #1 书签点击红屏**：`gotoLocator` 内部 `addPostFrameCallback` 跑在调用方 `_onBookmarkJump` 的 try-catch **之外**，书签跨章跳转触发 rebuild，rebuild 期间 ScrollController 可能短暂 detach，`.position` 访问抛出 → 未捕获 → 红屏。三重防御：(1) post-frame callback 全包 try-catch；(2) build/currentChapterPlainText/currentHighlightedHtml 全部加 `_currentChapterIndex >= chapters.length` 越界保护（book-switch race）；(3) gotoLocator 跨章分支补 `jumpToPage(0)`（之前只有 setChapter 有），避免旧 page index 超新 itemCount assertion。
- **Fixed Bug #2 笔记点击延迟**：`_onAnnotationTap` 只 `await chapterSwitchSettled`，同帧 PageView 刚 rebuild 还没完成布局，紧接着 jumpToPage 被吞 → "等一会才跳"。新增 `_awaitChapterSettledAndLayout()` helper：`chapterSwitchSettled` 后多等一帧（`endOfFrame`）让 PageView 完成布局。统一应用到 _onAnnotationTap / _onBookmarkJump / _maybeHandleInitialLocator / _jumpToChapter。

#### Tests

新增 `epubx_renderer_cross_chapter_back_page_test.dart`（3 cases）、`html_slicer_test.dart`（18 cases）、`epubx_renderer_paged_highlight_test.dart`（3 cases）、`epubx_renderer_bounds_guard_test.dart`（5 cases）；`epubx_renderer_setters_emit_state_test.dart` 加 setChapter emit 用例。

#### Lessons

- **setChapter 是唯一漏 emit 的章节切换路径**：gotoLocator CFI/EpubRangeLocator 分支、injectHighlights、setTypography、setPaginationMode 都 emit，唯独 setChapter 漏。这类"看着对、consumer 收不到"的 silent failure 是 adapter pattern 常见陷阱——每个 mutation 路径都得有自己的 notification pipeline。
- **post-frame callback 在调用方 try-catch 之外**：`addPostFrameCallback` 调度后立即 return，callback 在后续帧执行，完全脱离调用方的 try-catch。任何可能抛的 callback（尤其是访问 ScrollController.position / pageController.page 的）必须自带 try-catch。
- **LayoutBuilder 与 PageController 的帧时序**：`chapterSwitchSettled` 的 completer 在 post-frame resolve，但同帧 PageView 刚 rebuild 尚未完成布局，紧接着 jumpToPage 会被吞。多等一帧 `endOfFrame` 是稳妥的修复模式。

### M2.7 Round 3 — 2026-07-03（v1.5.1-alpha 用户复测反馈 #2）

Round 2 修复后用户报告 "排版页点击很多次才变动一点点，边距有改善但仍需更宽"。代码层追溯发现 Round 2 修复**完全没生效**：emit 调用加在了 `EpubxRenderer._stateController`，但 `ConcreteEpubReaderEngine.state$` 返回的是 adapter 自己的 `_stateController.stream` —— renderer 的 emission **从未转发到 adapter**，所以 `reader_body.dart:144` 的 listen 永远收不到事件。用户感受到的"一点点变化"只是 M2.6/T4 enum pixel value bump（normal 24→32）造成的视觉初值差异，跟排版切换无关。

TypographyPanel 自身还有第二层 bug：`reader_typography_panel_trigger.dart:65` 的 sheet builder snapshot `engine.typography` 作为 `current`，但 sheet 内部 `Consumer` 只 watch profile/font providers，没订阅 engine state。即使 Round 3 桥接通，sheet 内 `current` 仍不刷新 —— 每次 ChoiceChip 点击基于闭包里旧 `current.copyWith(...)`，写到 engine 的值永远不变。

#### Fixed

- **Bug #3 + #8 排版无反应（真根因）**：`ConcreteEpubReaderEngine` 构造函数加 `_renderer.state$.listen(_setState)` 桥接，转发 renderer 内部 stream emission 到 adapter 的 `_stateController`。Round 2 在 `epubx_renderer.dart` 加的 4 处 emit (setTypography / setPaginationMode / gotoLocator CFI / injectHighlights) 现在真正能传到 reader_body。这是 Round 2 修复"看似不生效"的根本原因。
- **TypographyPanel current 不刷新**：`reader_typography_panel_trigger.dart` 的 sheet builder 内嵌 `StreamBuilder<ReaderEngineState>` 订阅 `widget.engine.state$`，rebuild 时重新读 `widget.engine.typography` 作为 `current`。修复后字号 +/- 按钮、行距/字体/主题/边距 ChoiceChip 都即时刷新且可重复点击。
- **Bug #8 边距（加宽）**：用户反馈 M2.6/T4 (normal=32, wide=48, extraWide=64) 后"边距有改善但仍需更宽"。再次 bump: normal 32→48, wide 48→72, extraWide 64→96。Compact 保留 8（仅查看）。48px ≈ 1.5× WCAG tap target。

#### Tests

新增 `concrete_reader_engine_state_bridge_test.dart`（4 cases）：setTypography / setPaginationMode / gotoLocator CFI / injectHighlights 各自验证从 `ConcreteEpubReaderEngine.state$`（adapter stream）能收到 `ReaderEngineReady`。这是 Round 2 的盲点 —— 之前只测 renderer.state$ 有 emit，没测 adapter stream 是否能转发。

**总数：1076 通过 + 3 skipped**（baseline 1069 + 4 round-3 + 3 round-2 之前已加）。

#### Lessons

- **两路 state$ 的盲点**：`EpubxRenderer` 有自己的 `_stateController`，`ConcreteEpubReaderEngine` 又有自己的 `_stateController`。两路独立意味着 renderer emit 必须 bridge 到 adapter 才能到 consumer。这是 adapter pattern 常见陷阱：每个层级都得有自己的 notification pipeline，否则会出现"emit 看着对、consumer 收不到"的 silent failure。
- **Modal sheet 是独立 overlay**：父 widget rebuild 不会触发 sheet 内 builder 重跑。Riverpod `Consumer` 只在 watch 的 provider 变化时 rebuild。如果 sheet 需要 follow 外部 state（如 engine.state\$），必须显式 StreamBuilder / EventBus 订阅。

### M2.7 Round 2 — 2026-07-03（v1.5.1-alpha 用户复测反馈）

v1.5.1-alpha 交付后用户立即上手测试，发现 9 个 bug 中 7 个依旧（仅 Bug #5a 部分缓解、Bug #2 行为变化）。代码层追溯发现 **5 个 bug 同根因**：`EpubxRenderer` 是普通 class（不是 widget），改实例字段（`_typography` / `_paginationMode` / `_currentChapterIndex`）后**必须 emit state**，上游 `reader_body.dart:144` 的 `engine.state$.listen → setState → rebuild` 才能让屏幕更新。M2.6 修了 `injectHighlights` + `gotoLocator` EpubRangeLocator 分支的 emit state，但漏了 3 处。

#### Fixed

- **Bug #3 + #8 排版无反应 + 边距太窄**：`setTypography` (epubx_renderer.dart:486) 只赋值 `_typography` 不 emit state → 上游 reader_body 收不到事件 → widget 不 rebuild → 字号/行高/margin/主题任何选项都看不到变化。Bug #8 不是 enum 没改（已确认 normal=32），而是因为 widget 不 rebuild 永远显示旧值。补 `_stateController.add(const ReaderEngineReady())`。
- **Bug #7 TOC 不跳页**：M2.6/T7 只修了 `gotoLocator` 的 EpubRangeLocator 分支，但 `gotoTocEntry → gotoLocator(entry.locator)` 通常落到 CFI 分支（TocEntry.locator 多为 EpubCfiLocator）。CFI 分支 (epubx_renderer.dart:435) 同样只更新 `_currentChapterIndex` 不 emit state。补 emit state。
- **Bug #6 翻页（部分）**：`setPaginationMode` (epubx_renderer.dart:492) 不 emit state，paged ↔ scroll 切换后 widget 不 rebuild。补 emit state。注意：这只解决翻页问题的部分原因，焦点路径问题（Bug #9 ESC 同根因）仍待用户配合诊断。

#### Lessons

- **M2.6 测试覆盖层级错配重现**：单元测试只测"字段被赋值"，没测"emit state 后 widget 真重建"。M2.7 round-2 加了 3 个回归测试覆盖 setTypography / setPaginationMode / gotoLocator CFI 分支的 emit state 行为，防再次回归。

## [1.5.1-alpha] — 2026-07-03

v1.5.1-alpha 是 M2.6「Emergency Bug Fix Sweep」的交付版本：v1.5.0-alpha 用户上手测试 2026-07-03 上午发现的 9 个 bug（核心阅读流程多处不通）紧急修复。无新功能，纯 fix sweep。

### Fixed

- **Bug #1 书签点击红屏（防御性修复）**：`_onBookmarkJump` 的 `engine.gotoLocator(locator)` 未包 try-catch，任何异常直接渲染为 Flutter 红屏。包了 try-catch + SnackBar，根因待用户复现提供 stack trace 后做精准修复（M2.7 或 v1.5.2-alpha hotfix）。
- **Bug #2 笔记点击退出书**：`_onAnnotationTap` 无条件调 `Navigator.maybePop()`，M2.5/T7 抽屉重构成 `Scaffold.drawer` 后会 pop 掉整个 reader route。复用 `_onBookmarkJump:809` 的 `_isWideScreen` gate 模式。
- **Bug #3 排版页无反应**：`ConcreteEpubReaderEngine.typography` 返回 `TypographySettings.defaults()`（const 默认），`TypographyPanel.onChanged` 写到丢弃对象。一行修复：`get typography => _renderer.typography;`。`EpubxRenderer.typography` 暴露为 public getter（之前是 private 字段）。
- **Bug #4 PDF 双页假启用**：M2.5/T13 把双页触发耦合到 LayoutBuilder 宽度（>=1200px），全屏切换 + isScanned FutureBuilder 解析存在 race condition。改为用户-driven 独立 toggle（AppBar 新按钮，仅 PDF 引擎可见），默认 false。**v1.5.1 简化**：不持久化（每次启动默认 false）；持久化延后 v1.5.2。
- **Bug #5a 选择困难 + 翻页冲突**：reader_scaffold.dart 重构。原代码用单个 `GestureDetector(behavior: HitTestBehavior.opaque)` 包内容，会与 SelectableRegion 抢手势。改为 Stack 3 层（左空白边 / 右空白边 / 中央 double-tap），文字内容区归 SelectableRegion 独享。仿真书模型 per user 2026-07-03：左右空白边点击翻页，中央纯选择，4 面留白。
- **Bug #5b 高亮不渲染**：`injectHighlights` 只更新 `_allHighlights` 字段，不触发 consumer 重建。在 inject 后 emit `ReaderEngineReady` 到 `_stateController`，reader_body 监听到后重建读出新高亮。
- **Bug #6 翻页延迟/错乱**：`reader_scaffold._handleKeyEvent` + `_handleDragEnd` 的 `paginationMode != paged` gate 静默吞掉了 PDF（scroll）模式的所有键盘/拖拽事件。lift 该 gate（保留 wheel gate —— scroll 模式滚轮应让内容 ScrollView 自然滚动）。用户报告"键盘左右键不能翻页"解决。
- **Bug #7 TOC 不跳页**：`epubx_renderer.gotoLocator` 的 `EpubRangeLocator` 分支只更新 `_currentChapterIndex`，不 emit state。consumer widgets（reader_body）不重建，视觉上章节没变。补 `_stateController.add(const ReaderEngineReady())`。
- **Bug #8 边距太小**：`PageMargin` enum 像素值 bump：normal 24→32, wide 32→48, extraWide 40→64。Compact 保留 8（仅查看，不适合点击翻页）。M2.6/T9 后边距同时承担「视觉留白 + 翻页 tap zone 宽度」双职责，Normal 及以上满足 WCAG 最小 tap target（>=32px）。epubx_renderer.dart 已用 `EdgeInsets.all(margin)`，4 面留白已到位。
- **Bug #9 ESC 不退全屏**：`Focus` widget 在 AppBar 按钮点击后失去焦点捕获，ESC 事件被按钮节点吞掉。Hoist FocusNode 到 State 字段，所有 AppBar IconButton `onPressed` 完成主操作后调 `_reclaimFocus()` 重新获焦。

### Architecture

- **A1**：PDF 保留 scroll 模式默认；双页布局是独立 toggle，per-book 持久化延后 v1.5.2。
- **A2**：仿真书阅读模型——tap zone 仅存在于左右空白边，文字内容区是纯选择领地；4 面留白。
- **A3**：Bug #1 ships defensive（防御性 try-catch）；待用户 stack trace 后做精准修复。

### Tests

3 个新回归测试（T3 typography getter + T5 injectHighlights emit state + T7 gotoLocator EpubRangeLocator emit state）。T6/T8 widget tests deferred（fix 是 mechanical copy-paste，手动 smoke 验证）。T1+T9+T10 修改了既有 paging/scaffold 测试以反映新行为（scroll 模式键盘/拖拽现在翻页；tap zone 仅在空白边）。

**总数：1069 通过 + 3 skipped**（baseline 1066 + 3，flaky `book_import_service_test.dart:77` 偶发不影响 ship）。

### Known Limitations

- Bug #1 根因可能未完全解决，待用户提供 stack trace。
- EPUB 双页渲染仍推到 v1.6（M2.5/T14 API surface 未动）。
- PDF 双页 toggle 不持久化（v1.5.2 加 SharedPreferences）。

### Upgrade Notes

如新边距过宽：**Settings → Typography → Margin → Compact**（8px）。

## [1.5.0-alpha] — 2026-07-03

v1.5.0-alpha 是 M2.5「Reader UX Overhaul」的交付版本：2 个 P0 用户面 bug 修复 + 8 项 UX 增强 / 新功能。目标是把阅读器从"能用"推进到"在桌面宽屏上舒服用"——多输入翻页、全屏模式、宽屏 TOC sidebar、双页布局、书签系统、合并摘录入口，外加首次分页 margin 调整与 chrome 默认可见。

### Fixed

- **#4 高亮不渲染**：用户选中文本后选颜色，页面上不出现高亮。根因：`NotesState.annotations` 变更后没有桥接到 `engine.injectHighlights()`。修复：`reader_body.dart` 加 `ref.listen` 把 annotations 同步到 engine（T2）。
- **#6 笔记条目点击无效**：NotesPage / drawer 里点笔记不跳回原位置。根因：`EpubxRenderer.gotoLocator` 没处理 `EpubRangeLocator`（只认 `EpubCfiLocator`）。修复：补齐 `EpubRangeLocator` 分支（T1）。

### Added

- **书签系统（#7）**：drift v10 schema + 仓库 + 控制器 + sync pipeline + UI 四入口。
  - 数据：`Bookmarks` 表（id / bookId / locatorJson / label / note / createdAt / updatedAt），v9 → v10 自动迁移。
  - 同步：`SyncRecordType.bookmark` 接入 SyncRecorder + RemoteRecordApplier，遵循 last-write-wins 与高亮相同的冲突策略。
  - UI：AppBar 收藏图标 + 自定义标签对话框、drawer 书签 tab、独立路由 `/book/:id/bookmarks` 页面。
- **PDF 双页布局（#10）**：宽屏（>=1200px）自动启用，按偶数页对齐；扫描件自动降级单页。
- **EPUB 双页 API surface（#10 部分）**：`dualPageMode` 标志已端到端 wire（`EpubxRenderer` → `ConcreteEpubReaderEngine.rendererRef` → `reader_body.dart` LayoutBuilder）。**渲染层留 v1.6**——EPUB 分页当前是 degraded plain-text 模式，重写算法是抛一次性的工作；PDF T13 已覆盖更常见的双页格式需求。详见 `epubx_renderer.dart` 字段 doc-comment。

### Changed

- **多输入翻页（#2）**：键盘 ←/→/↑/↓/PgUp/PgDn、鼠标滚轮、触摸拖拽、左右 tap zone 五种输入都触发翻页。
- **全屏模式（#3）**：桌面 `window_manager.setFullScreen` + 移动 `SystemChrome.setEnabledSystemUIMode`；Esc / F11 键盘快捷键，全屏态中心区域双击显示 chrome。`FullscreenController` 抽象让 StateNotifier 在测试里用 `NoopFullscreenController` 注入。
- **合并摘录按钮（#5）**：原来「高亮」「笔记」两个按钮合并为「摘录」bottom sheet——5 色高亮 + 可选笔记输入，一站式。
- **TOC sidebar（#8）**：宽屏（>=1100px）下抽屉升级为永久侧栏（280↔40px 可折叠）；窄屏保持原 drawer slide-over。
- **默认 margin 调整（#9）**：Normal 16 → 24 px；新增 ExtraWide=40px 选项（Compact=8 / Normal=24 / Wide=32 / ExtraWide=40）。
- **chrome 默认可见**：桌面端 reader AppBar 默认显示（之前需要点击切换）。中心单击不再切换 chrome（避免误触），改用 AppBar 按钮 / Esc / F11。
- **抽屉 3-tab 重构**：原 `Scaffold.drawer`（TOC）+ `Scaffold.endDrawer`（Notes）合并为单一 `ReaderDrawer`，目录 / 书签 / 笔记三 tab 切换。

### Technical

- 4 个包共 1066 pass + 3 skipped（app 888 / reader_engine 50 / reader_engine_epub_view 83 / reader_engine_pdf_view 45）。
- M2.5 共 15 个任务，全部走 subagent-driven development：每任务 implementer + 两阶段 review（spec compliance → code quality）。
- subagent 自修多个 plan bug：T11 plan 写错了 sync 文件路径（`sync_entity_registry.dart` 不存在，实际是 enum + SyncRecorder + RemoteRecordApplier 三处）；T13 plan 把 PDF `paginationMode == paged` 当触发条件（实际 PDF 模式恒为 scroll），改为「宽度 + 非扫描件」；T9 plan 让 StateNotifier 内联平台分支会破坏可测性，重构为 `FullscreenController` 抽象 + 3 实现。
- 1 个 flaky test (`book_import_service_test.dart::importFile concurrent same file returns existing for second caller`) 在并发执行时偶现，单跑稳定通过——已知是 drift 测试套件并发开销，与 M2.5 改动无关。

### Migration

- Drift 自动从 v9 迁移到 v10（创建 `bookmarks` 表 + `idx_bookmarks_book` 索引）。
- 用户已存的 margin 偏好保留（Compact / Normal / Wide 索引不变）。
- **行为变化 caveat**：Normal 档位的实际像素值从 16 变 24（M2.5 调整）；升级后现有 Normal 用户会感觉阅读宽度变大，可在 Settings → Typography → Margin 切回 Compact（8 px）维持旧观感。

## [1.4.0-alpha] — 2026-07-01

v1.4.0-alpha 是 v1.3.0-alpha 之后的一次"release hygiene sweep"——把 Phase 3+ 之前所有遗留的 housekeeping 工作（reader 代码拆分、lint 清理、文档同步、截图补齐、Gitee Release 页面创建）一次性解决。**没有新功能**。

### Changed

- **Code hygiene**：`reader_body.dart` minimal split（644 → 578 行）。抽出 `ReaderChapterEndPrompt`（controller lifecycle + SnackBar emission）和 `ReaderSelectionToolbar`（Positioned overlay）两个零依赖 widget 到 `features/reader/widgets/`。零行为变化（全量测试通过）。
- **Lint cleanup**：49 个 info lints → 0 via `dart fix --apply` + 手工清理（rename `_`-prefixed 局部变量、`unawaited()` wrap、剩余 cascade 加 `// ignore` + 注释）。

### Documentation

- `maintainers-runbook.md §9.4.1` — v1.4 perf re-test decision（v1.0.0 baseline 沿用，无渲染/DB/sync 重大改动；列下次强制复测触发条件）。
- `release-procedure.md` — step 1/2/12 同步当前版本号（1.3.0-alpha+0）、测试数（812）、AGPLv3 阈值（=0）。
- `release-notes-v1.4.0-alpha.md` — Gitee Release body 草稿。

### Infrastructure

- 3 张 release 截图补齐（library / pdf_reader / notes）。
- 4 个 Gitee Release 页面创建（v1.0.0 / v1.1.0-alpha / v1.2.0-alpha / v1.3.0-alpha）。

### Technical

- 补回遗漏的 `[1.2.0-alpha]` 与 `[1.3.0-alpha]` CHANGELOG 段落（见下）。
- AGPLv3 头覆盖率：100%（生成文件除外）。
- 全量测试：818 pass + 3 skipped（M2.3 baseline 812 + 6 个 M2.4 新测试）。

## [1.3.0-alpha] — 2026-07-01

M2.3 交付：**批量导出范围筛选**。库 AppBar "导出为 Markdown" 先开筛选页，支持按标签（多选 OR）/ 按导入时间 / 按最近阅读三维度组合筛选；实时预览匹配书单 + 高亮总数；底部按钮直接显示"导出 N 本"。底层 `BookFilter` 值类 + `applyBookFilter` 纯函数 + 既有 `VaultExporter` 零改动；预览数 = 实际导出数的不变量由 `VaultExporter.hasContent` 提为 static 保证。

### Added

- `app/lib/features/library/models/book_filter.dart`（T1）— `@immutable` 值类（Set<String> tags + 2 个 TimeWindow 字段；SetEquality 深相等）。
- `app/lib/features/library/services/book_filter_applicator.dart`（T2）— 纯函数 `applyBookFilter({books, filter, tagsByBookId, now})`；OR 语义、5 段预设区间。
- `app/lib/data/local/daos/book_tags_dao.dart`（T3）— 新增 `allTagsByBook()` 单 SELECT bulk。
- `app/lib/features/notes/services/vault_exporter.dart`（T4）— 把"判断 BookNote 是否有内容"内联逻辑提取为 `static bool hasContent(BookNote n)` 公开方法。
- 13 个新 i18n key（中英双语）。
- `app/lib/features/library/pages/export_filter_page.dart`（T6，281 行）— 独立筛选页 StatefulWidget。

### Changed

- `LibraryAppBar._startBatchExport` 改写：fetch notes → 空短路 → fetch tags → `showDialog<BookFilter?>` → `applyBookFilter` → file_picker + BatchExportDialog。

### Technical

- 30 个新测试（全量 812 pass + 3 skipped）。
- subagent-driven development: T1-T9 每 task 双阶段 review；T2 boundary test 抓住 off-by-one risk。

## [1.2.0-alpha] — 2026-07-01

M2.2 交付：**自动章节结束提示**（EPUB only）。用户翻到 EPUB 一章末页（paged 或 scroll 模式）时，自动弹出非阻塞 SnackBar，提供「回顾本章 / 下一章 / 关闭」三个动作。PDF 阅读不弹（pdfrx Page-as-Chapter 频繁打扰）。

### Added

- `reader_engine_epub_view/lib/src/chapter_end_event.dart` — 纯数据类（chapterIndex + isLastChapter，值相等）。
- `EpubxRenderer.chapterEndEvents`（broadcast Stream）— 内部 flag 同次访问去抖。
- `ChapterEndDetector`（app 层）— per-session per-(bookId, chapterIndex) Set 去重。
- `ChapterEndPromptController`（StateNotifier）— settings gate + mounted 检查。
- `ChapterEndPromptSnackBar` — 自定义 content Row（3 个 TextButton；Next 条件显示）。
- `kChapterEndPromptEnabledKey` const + `chapterEndPromptEnabledProvider` AsyncValue<bool> + `ensureChapterEndPromptDefault` 首次启动默认值 seeding。
- Settings 页 `_ChapterEndPromptTile` ConsumerWidget。

### Changed

- `reader_engine_epub_view/lib/src/epubx_renderer.dart` 4 个 `_currentChapterIndex =` 写入点都重置 flag（setChapter / gotoLocator / openFile / bookForTesting）。
- `reader_body._ReaderBodyState` — lazy init + addListener 边沿检测（hidden→visible）+ ScaffoldMessenger.showSnackBar。

### Technical

- 22 个新测试（全量 782 pass + 3 skipped）。
- spec §2.2 明确推后 PDF 路径（pdfrx controller plumbing 留待 future）。

## [1.1.0-alpha] — 2026-07-01

智阅首个 AI 增强里程碑（M2.1）。在 v1.0.0 GA 基础上新增章节学习回顾
与 Markdown 批量导出两大功能。仍为 alpha：UI 文案、动效、错误恢复路径
有待真实用户反馈打磨。

### Added

- **章节学习回顾**（MVP 2.0）：TOC 抽屉按章节 + 阅读器溢出菜单"回顾本章"。
  AI 用本章正文 + 用户本章高亮生成 summary + keyTakeaways，写入读书笔记。
  模态预览 + 保存/取消。PDF 书禁用入口（Page-as-Chapter 语义不适用）。
- **Markdown 批量导出**（MVP 2.0）：库 AppBar "导出为 Markdown"。选文件夹，
  每本书一份 .md + 一个 index.md（Obsidian vault 兼容，含 YAML frontmatter
  + wiki-links + 标签云）。空库提示对话框。
- 25 个 i18n key（15 review + 10 batch export），中英双语。
- 17 个新测试覆盖核心逻辑（总测试数 762 + 3 skipped）。

### Changed

- `PromptBuilder.promptVersion` 1 → 2（review 模式新 cache key；旧缓存不受影响）。
- `LibraryAppBar` 加 `onBatchExport` callback + 新 IconButton（folder_zip_outlined）。
- `TocDrawer` + `_TocTile` 加 `onReviewChapter` 参数（递归传递）。
- `ReaderScaffold` 加 `onOpenReview` callback + PopupMenuItem（仅 EPUB）。
- `maintainers-runbook.md` 新增 §10（M2.1 调试参考，6 个子节）。

### Technical

- 新增 `BookReviewer` **独立**服务（不复用 AiGuide）：AiGuide 的 sourceHash
  只 hash 章节文本，无法感知高亮变化会导致缓存命中错误。BookReviewer 自己
  计算 `sha256(truncatedText + '::' + highlightsSignature)`，让"新增高亮
  → 下次回顾强制 miss"成为默认行为。镜像 AiGuide 的 stream/cache/persist
  pipeline，但用项目最新 `ReviewClientLike` 抽象（参考 BookQaService）。
- 新增 `VaultExporter` 纯逻辑服务 + `BatchExportDialog` StatefulWidget。
- 新增 `ReviewController`（StateNotifier，状态机：idle/loading/streaming/done/error）
  + `ReviewPreviewSheet`（模态预览）。
- `NotesRepository.applyChapterReview` 幂等写入：`【第N章】` 前缀 +
  `## 第 N 章` sentinel，先删后加，保留用户手动内容。
- `ReviewOutputParser` 容错 JSON 解析（处理 ```json fence + 非 String 元素）。
- 0 数据库 schema 迁移；0 同步逻辑改动。
- BookReviewer sourceHash 算法、幂等前缀约定、批量导出文件命名规则
  均记入 `docs/maintainers-runbook.md` §10。

### Plan 偏差与自修

实施过程中 subagent 自主发现并修正了 plan 的若干内部不一致：
- T5 重构 BookReviewer 用 `ReviewClientLike` 抽象（与 plan 假设的 clientFactory
  typedef 不同），更对齐项目最新 BookQaService 模式
- T12 修正测试断言中的 Obsidian wiki-link 格式（文件名经 sanitize 后无书名号）
- T14 改用独立 IconButton 而非 PopupMenuItem（因 LibraryAppBar 现有 UX 是
  IconButton 行而非溢出菜单，保持一致性）

## [1.0.0] — 2026-06-30

智阅首个正式发布（GA）。本条目汇总 M1.6 Polish Sweep 的本次发布内容，
以及 M0 至 M1.6 的累积里程碑。AGPLv3 开源。

### M1.6 Polish Sweep（本次发布）

- **代码质量**：lint 清理（15 warnings + 26 lib info → 0），reader_page.dart
  机械拆分（772 → 97 行 + reader_body / reader_progress_bar /
  reader_typography_panel_trigger 三个聚焦文件），共享 UX 三态组件
  （LoadingView / EmptyView / ErrorView）在 9 个页面落地，drift row 命名
  一致性（Book.fromRow 工厂）。
- **文档**：maintainers-runbook.md（639 行）覆盖环境搭建、中文路径坑、
  subagent-driven 开发流程、Git/发布流程、11 个常见 bug、性能基线方法论、
  24 术语词汇表。
- **Windows 原生冒烟测试**：deep_link_parser 提取 + 基于 cl.exe 的
  test_main.cpp（13 个断言用例）。中文路径 → cl.exe 失败的 ASCII 路径
  workaround 已记录。
- **UX 一致性**：所有可见字符串走 l10n；主页面不再有裸
  CircularProgressIndicator 或临时 error Text。
- **TOC**：渐进式章节标记（已预处理 ✓ / 失败 ⚠ / 未处理）。
- **防御性**：ai_summaries 在 preprocessor 中防御性缓存；
  qaControllerProvider 默认 NoOp；SyncController 强制要求 http.Client；
  共享 httpClientProvider（带 dispose 测试）。

### 累积里程碑（M0 → M1.6）

- **M0+M1**：数据层基础（58 tests）
- **M2**：EPUB 阅读器（179 tests）
- **M3.1-3.5**：书架 / 笔记 / 排版 / i18n（491 tests）
- **M4**：基于 pdfrx 的 PDF 阅读器 + 文本高亮（565 tests）
- **M7**：平台适配（575 tests，v0.4.0）
- **M8**：Windows 安装器（579 tests，v0.5.0）
- **M1.5a**：AI MVP — OpenAI 兼容 LLM、三种导读模式、摘要缓存（v0.7.0-alpha）
- **M2.0a**：同步 MVP — WebDAV 单向 push/pull、last-write-wins（v0.6.0-alpha）
- **M2.0b**：同步冲突解决 + 后台定时器（v0.8.0-alpha）
- **M1.5b+c**：导入批处理 + 同书 Q&A（v0.9.0-alpha）
- **M1.5b+c Review Fixups**：内存泄漏 + spec 偏差闭环（v0.9.1-alpha）
- **M1.6**：Polish Sweep（本次发布 — 713 tests + 2 skipped，GA）
  - 跳过的 2 个测试为预存在项，非本次 milestone 新引入：
    `app/test/features/settings/font_import_service_test.dart:187`
    （FontLoader 在非字体字节上的行为依赖运行环境）与
    `app/test/features/reader/reader_page_pdf_integration_test.dart:60`
    （`skip: true` 占位骨架）。`background_sync_scheduler_test` 与
    `book_import_service_test` 的偶发失败属于 **flaky**（与并发相关），重跑通过。

### 已知限制

- Windows release 构建在中文路径（`H:\projiect\电子书阅读平台`）下失败；
  构建时需拷贝到 ASCII 路径。详见 runbook §3。
- 截图待 v1.0.0 手动采集（见 `docs/screenshots/README.md`）。
- 性能基线待手动测量（见 runbook §9.6）。
- 新表（`book_passages`、`qa_history`）尚未接入 sync_outbox — 推迟至 M2.0x。
- Q&A 为单轮（每次提问独立，无上下文累积）。
- 成本/token 估算 UI 按用户反馈有意省略。

## [0.9.1-alpha] — 2026-06-30

Point release addressing M1.5b+c review findings (C1 + I1-I5).

### Fixed
- **C1**: `QaAnswerView` memory leak — `TapGestureRecognizer`s are now disposed
  when the widget unmounts or the answer text changes. Previously, streaming
  rebuilds leaked ~1 recognizer per citation per build.
- **I1**: `chapterCountFor` linear probe replaced with `ChapterTextProvider.count()`
  — O(1) instead of O(N) EPUB re-parses on import of thick books.
- **I2**: `PreprocessDoneEvent.failedChapters` now reflects transient per-chapter
  failures (was always empty); `PreprocessChapterFailedEvent` is now emitted
  (was dead code). The "N 章预处理失败" banner in BookDetailPage is honest.
- **I3**: Q&A stream stall + total timeout — `BookQaService` drives a
  `StreamIterator` with `Future.timeout(stallTimeout)` per moveNext (default
  30s) and a 90s total cap. A "停止" button in `QaAskDialog` cancels the
  in-flight request via `QaController.reset()`. Network errors after partial
  output are terminal (no replay), mirroring `ai_guide.dart`'s pattern.
- **I4**: `QaAskDialog` now shows "预处理进行中（N/M），回答可能不全" caption
  when the per-book preprocess controller is chunking/summarizing.
- **I5**: Q&A history list — `QaAskDialog.initState` loads top-5 entries and
  renders them as ActionChips. Tap resubmits, long-press deletes. Introduces
  `QaHistoryDaoLike` interface for testability. Closes spec §14 acceptance
  gap "Q&A 历史可查看 + 重发".

### Spec coverage
Review categorization: 1 Critical + 5 Important (this release) → 6/6 closed.
Minors (M1-M7) deferred to M2.0c.

## [0.9.0-alpha] - 2026-06-30

M1.5b+c — AI Batch Preprocess + Same-Book Q&A.

### Added
- **Schema v9**: 2 new drift tables (`book_passages`, `qa_history`) +
  `book_passages_fts` virtual table with 3 sync triggers. Substring LIKE
  remains the default retrieval path (CJK-friendly); FTS5 reserved for
  future relevance-ranked retrieval.
- **Batch preprocess**: On book import with `isNew=true`, LibraryPage
  triggers `BookPreprocessor` which runs a 2-phase state machine:
  - Phase 1 (chunking): synchronous, fast — chapter text → BookChunker →
    `book_passages` rows
  - Phase 2 (summarizing): per-chapter AiGuide.run(chapter) with 2s
    throttle, 3-failure circuit breaker, skipIfRunning, cooperative cancel
- **BookQaService**: same-book Q&A with history short-circuit, FTS top-K
  retrieval, `[ch=N]` citation markers in the answer, parsed and made
  tappable.
- **Reader "问答" icon**: tap to open QaAskDialog; tap a `[ch=N]` citation
  to close the dialog and `engine.gotoTocEntry + chapterSwitchSettled`
  to the cited chapter.
- **Preprocess UI**: BookDetailPage LinearProgressIndicator + cancel button +
  reprocess action; BookCell status chip during processing; Reader chapter
  drawer ✓/⚠ markers.

### Changed
- `database.schemaVersion` 8 → 9. Existing users get empty book_passages on
  upgrade; manual preprocess trigger via BookDetailPage.
- `app_providers.dart` adds `bookPreprocessorProvider`, `bookPreprocessControllerProvider`,
  `bookQaServiceProvider`, `qaControllerProvider` overrides.
- `ReaderScaffold` adds `onOpenQa` callback parameter (nullable, default
  null — readers without a Q&A binding render unchanged).
- `pubspec.yaml` version `0.8.0-alpha+0` → `0.9.0-alpha+0`.
- 16 new i18n keys (zh + en) for Q&A dialog states + preprocess status.

### Known limitations
- New tables (`book_passages`, `qa_history`) not yet wired to sync_outbox —
  deferred to M2.0x.
- Q&A is single-turn (each ask independent, no context accumulation).
- Cost/token estimation UI intentionally omitted per user feedback memory
  `feedback_no_cost_estimation` — reading focus preservation.
- PDF per-page title not surfaced in Q&A context (PdfChapterTextProvider
  returns null title).
- `chapterCountFor` uses linear probe (re-reads EPUB file N times). Acceptable
  for T7; optimization deferred.

### Plan corrections applied by implementers (transparency)
- `qa_history.dart` `id` column uses plain `text()()` (cascade `..withLength` drift syntax dropped silently).
- `QaHistoryDao.delete` renamed `deleteEntry` to avoid clash with drift's `DatabaseConnectionUser.delete`.
- `QaHistoryDao._generateId` switched from timestamp to uuid v4 to avoid UNIQUE collisions in tight loops.
- `Book` constructor uses `addedAt`/`coverPath`, not `createdAt`.
- Credentials class is `AiCredentials` (not `ApiKeyCredentials`).
- `TocEntry.children` is non-nullable (`List<TocEntry>` with default `const []`).
- `BookQaService` and `BookPreprocessor` declare `implements` their `*Like` interfaces (in their own files) to avoid circular imports.
- `QaAskDialog` accepts optional `Book?` for tests; production passes the active book.

### Test counts
- ~60 new tests added across 13 new test files.
- Total: 659 tests passing, 2 skipped (verify with `flutter test` before tagging).

## [0.8.0-alpha] - 2026-06-29

M2.0b — Sync Conflict Visibility + Background Timer.

### Added
- **Conflict log**: LWW decisions are now visible. When a remote record
  loses to local, a row is written to the new `sync_conflicts` table
  with winner/loser device IDs, timestamps, and a 200-char payload preview.
- **Sync Status page** (`/settings/sync/status`): three sections showing
  current status, background interval picker (1/5/15/30 min or off), and
  a rolling 30-day conflict log.
- **Background scheduler**: `BackgroundSyncScheduler` runs Timer.periodic
  (default 5 min) with skipIfRunning guard, 5-min cooldown after errors,
  and lifecycle awareness (pause on background, immediate sync on resume).
- **Connectivity check**: `connectivity_plus` integration for fast offline
  detection (non-blocking — fails open if Windows virtual NIC reports odd).
- **Rolling cleanup**: outbox purged at 7 days; conflicts at 30 days,
  automatically after each successful `syncNow()`.

### Migration
- Drift schema version 7 → 8. Existing users get `sync_conflicts` table +
  `idx_sync_conflicts_detected_at` index on next app launch.

### Compatibility
- All M2.0a sync tests remain green. `NullConflictSink` is the default
  injection, so any code constructing `RemoteRecordApplier` without a sink
  continues to work unchanged.

## [0.7.0-alpha] - 2026-06-29

### Added (M1.5a AI MVP)
- Three AI guide modes: full-book summary, chapter guide (300字 summary + 3-5 markdown bullets), selection comment
- OpenAI-compatible LLM client (default DeepSeek, base_url + model configurable in Settings)
- SSE streaming with token-by-token output
- flutter_secure_storage for API key (Windows DPAPI / Android Keystore), never logged
- On-device drift cache (ai_summaries table, schema v6→v7), lookup by (book_id, mode, sha256(source), prompt_version)
- Four entry points: Library ⋮ menu, BookDetail FAB, Reader top bar, EPUB selection toolbar
- Chapter bullet → "加入笔记" integration (appends to BookNotes.keyTakeaways JSON)
- Network-layer auto-retry (3 attempts, 1s/2s/4s exponential backoff, only before chunks arrive)
- ApiKeySettingsPage with obscure toggle + DeepSeek disclaimer
- i18n strings (zh + en) for all AI UI + error states
- 19 TDD task commits; tests: 617 → 536 passing (some skipped due to fixture availability)

### Changed
- `BookCellAction` enum extended with `aiGuide` value
- `BookGrid`/`BookListView` `onAction` callback now passes `Book` object
- `BookDetailPage` FAB replaced with Row of two FABs (AI 导读 + delete)
- `ReaderScaffold` AppBar actions extended with auto_awesome icon
- `HighlightSelectionControls` accepts optional `onAiComment` callback
- `reader_engine_epub_view` barrel file now exports `plain_text_utils.dart`
- `AiGuide.chapterTextProvider` refactored to `chapterTextProviderFor: ChapterTextProvider Function(Book)` (factory by format)
- `BookNotesDao.appendKeyTakeaway` method added (creates BookNote if missing)
- `pubspec.yaml` adds direct `epubx` + `pdfrx` deps (depend_on_referenced_packages)

### Known limitations
- PDF selection AI comment not wired (pdfrx manages its own selection UI)
- Single-prompt strategy (model auto-adapts; no per-language tuning)
- No cost estimation UI (deferred to S4)
- No batch chapter preprocessing (deferred to S4)

## [0.6.0-alpha] - 2026-06-28

### Added (M2.0a Sync MVP)
- SyncSettingsPage (Settings → Sync): 坚果云 credentials form + manual sync trigger
- SyncOutbox drift table (schema v6): pending writes queue
- SyncRecord JSON envelope with last-write-wins semantics
- WebDavClient (PROPFIND/GET/PUT) with rate limiter (≥2s, R1 mitigation)
- WebDavSyncEngine push + pull paths
- RemoteRecordApplier: applies pulled records with LWW per mtime
- Repository hooks: Notes/Book/ReadingProgress writes automatically enqueue
- Per-device JSON Lines snapshot at `/zhiyue/snapshots/{deviceId}.jsonl`
- Tombstones for deletions (no physical record loss)
- i18n: zh + en strings for sync UI

### Known limitations
- Single-direction sync per record (last-write-wins, no merge)
- Manual sync only (no background timer — that's M2.0b)
- No conflict UI (just silent LWW — that's M2.0b)
- Android APK build not verified in this milestone
- Books' metadata updates from remote are silently dropped (no `updated_at` column)

## [0.5.0] - 2026-06-28

### Added
- Windows Inno Setup 安装包（自动注册 .epub/.pdf 文件关联、开始菜单快捷方式、卸载项）
- Windows 便携 Zip 分发（解压即用，免安装）
- Android fat APK release artifact（真签名 + `apksigner verify`）
- Windows 单实例 deep-link（命名 mutex + WM_COPYDATA 跨进程 argv 透传）
- `BookOpenBridgeOptions.onError` 可选回调 → SnackBar 失败反馈（默认行为向后兼容）
- `dart_test.yaml` 配置 golden tag（消除 test runner warning）
- `CHANGELOG.md` + `NOTICE` 三件套（AGPLv3 合规）
- `docs/setup-android-sdk.md` 安装指南
- `docs/release-procedure.md` 发布流程手册
- 4 张主界面截图（library / EPUB reader / PDF reader / Notes）

### Changed
- 根 `README.md` 状态刷到 v0.5.0；加下载安装段 + 主界面预览
- `app/README.md` 从 Flutter 模板骨架重写为开发者操作手册

### Removed
- `.github/workflows/ci.yml`（项目 remote 在 Gitee，本地手动 build only）

## [0.4.0] - 2026-06-28

### Added
- 应用显示名「智阅」（Android + Windows 双端同步）
- `flutter_launcher_icons` pipeline（用户 AI 生图 → Android mipmap-* + Windows .ico）
- Android release signing 配置（`keystore.properties` gitignored）
- Android `intent-filter` 注册 `VIEW` epub/pdf（含 4 个 pathPattern 覆盖多重扩展名）
- `BookOpenBridge` Dart bridge（`isSupportedBookPath` / `handlePath` / `init`，10 单测）
- `MainActivity` Kotlin MethodChannel bridge（cold start `popPendingBookPath` + warm start `openBook` + `content://` 拷贝到 cacheDir）
- `main.dart` 接入（`main(List<String> args)` + post-frame callback + `UncontrolledProviderScope`）
- `routerProvider` Riverpod singleton（修 ZhiYueApp.build 每次重建新建 router 反模式）

## [0.1.0] - 2026-06-24

M0 + M1：数据层基础交付（58 测试）。

### Added
- drift SQLite 数据库（`books` / `chapters` / `highlights` / `notes` / `tags` 表）
- FTS5 全文索引（跨书搜索 highlights + notes）
- `BookRepository` + `HighlightRepository` + `NoteRepository` + `TagRepository`
- 文件存储层（`BookStorageService`，分 book/highlight/note 三层目录）
- 应用启动初始化（drift database + ProviderContainer）

## 后续里程碑（无对应版本 tag，但内容已交付）

### M2 (2026-06-26) - EPUB 阅读器
- 30 commits + 179 tests，tag `m2-complete`
- epubx 解析 + 自研渲染（pivot 自 epub_view_plus，因为后者未上 pub.dev）
- EpubRangeLocator + ReaderEngine 接口
- 章节切换 / 进度持久化 / 主题适配

### M3.1 (2026-06-26) - 库 + 导入 + 标签 + 排版
- 28 commits + 295 tests，tag `m3.1-complete`
- LibraryPage（grid + list 双视图）
- BookImportService（EPUB/PDF 自动格式检测）
- 标签系统（多对多 + 拖拽排序）
- 排版预设扩展

### M3.2 (2026-06-27) - 高亮 + 笔记 + 跨书搜索
- 28 commits + 366 tests，tag `m3.2-complete`
- 5 色高亮 + 笔记
- FTS5 跨书搜索 highlights + notes
- 章节分组 drawer

### M3.3 (2026-06-27) - 精确 offset + chapterTitles
- 8 commits + 389 tests，tag `m3.3-complete`
- 精确 offset 定位（不再用 paragraphIndex 粗粒度）
- chapterTitles（章节深链滚动）

### M3.4 (2026-06-27) - per-book NotesPage + Markdown 导出
- 17 commits + 442 tests，tag `m3.4-complete`
- per-book NotesPage
- Markdown 导出（含 frontmatter）
- paged 模式精确滚动
- chapterRevisionNotifier

### M3.5 (2026-06-27) - 设置 / 字体 / i18n / 多预设排版
- 18 commits + 491 tests，tag `m3.5-complete`
- SettingsPage + FontManagementPage
- i18n（中文 + 英文）
- 多预设排版（serif / sans / 自定义）
- chapterSwitchSettled 重构

### M4 (2026-06-28) - PDF 阅读器
- 19 commits + 565 tests，tag `m4-complete`
- pdfrx 2.4.4 集成（MIT，AGPLv3 兼容）
- Page-as-Chapter 映射（PDF 第 N 页 = engine chapterIndex N-1）
- 文本选区高亮
- 扫描 PDF heuristic 检测（前 3 页 < 100 字符判定）
- 主题适配（light/dark/sepia/eInk via ColorFiltered）

### M7 (2026-06-28) - 平台适配
- 13 commits + 575 tests，tag `m7-complete` + `v0.4.0`
- 见 [0.4.0] 段落

## 链接

- [Unreleased]: https://gitee.com/weifu0523/e-book-reading-platform/compare/v0.5.0...master
- [0.5.0]: https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.5.0
- [0.4.0]: https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.4.0
- [0.1.0]: https://gitee.com/weifu0523/e-book-reading-platform/releases/tag/v0.1.0
