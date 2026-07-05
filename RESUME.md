# 🔄 RESUME — M4.6-fix9 接力棒（定时任务唤醒用）

> **本文件由 2026-07-05 22:15 会话编写，供凌晨 01:00 定时任务唤醒的新会话接力。**
> **新会话开始时：先读本文件，再读 spec + plan，然后继续 TodoWrite 推进。**

**最后一次更新**：2026-07-05 22:15（fix9 进行中）

---

## 🎯 当前任务

**M4.6-fix9：PDF 双页重写 + MD scroll 管线**（解决 PDF 死锁导致 exe 僵尸 + MD 段落溢出）

### 必读文档（按顺序）
1. **本文件**（你正在读）
2. `docs/superpowers/specs/2026-07-05-m4.6-fix9-pdf-dual-page-and-md-pipeline-design.md` —— 设计依据（根因 + 方案选型）
3. `docs/superpowers/plans/2026-07-05-m4.6-fix9-pdf-dual-page-and-md-pipeline.md` —— 7 个 Task 的执行清单

### 用户的核心诉求（原话）
> 1. PDF 一张都没加载成功 → 必须能加载、能双页
> 2. PDF 关闭后 exe 不能再次启动（僵尸进程）→ 必须修复
> 3. MD 分段乱（段落溢出页面、被切到页中）→ 必须修复
> 4. TXT 正常 → **不要碰 TXT**
> 5. PDF 双页是专业阅读器必备功能 → **必须保留双页**

### 根因（已用 zhiyue_pdf.log 铁证定位，详见 spec §1）
- **PDF 死锁**：旧双页实现用两个 `PdfViewer.data()` + `sourceName#L/#R` → pdfium 加载两份 29MB → `_doc.dispose()` 永远不返回 → 进程僵尸 → 持有 named mutex → exe 二次启动失败
- **MD 分段**：MD 复用 EPUB 的 `Paginator`（按 plain text 偏移机械分页），`<br>` 强制换行打破"连续字符流"假设 → 段落被切到页中、溢出

### 方案（已与用户确认，spec §4）⚠️ 重要：方案已修正
- **PDF 方案 A''（修正后）**：双 `PdfViewer.data()` **相同 sourceName** → pdfrx CanonicalizedMap 共享一份 PdfDocument（第 18/78/92-97 行官方机制）。两 viewer 各 `NeverScrollableScrollPhysics` 锁定到各自页，翻页 step=2 用 ValueKey 重建。
  - **为什么不是方案 A（主页+位图预览）**：用户敏锐指出该方案有 2-3 页错位风险 + 主页可滚动导致不同步 + 副页不能交互。已被推翻。
  - **死锁根除机制**：相同 sourceName → 共享 PdfDocument → 只一份 → dispose 干净
- **PDF dispose 安全网**：`_doc.dispose()` 加 3s timeout
- **MD**：强制 `PaginationMode.scroll`（复用既有 `_buildScroll`），无双页
- **TXT**：保持 paged + 双页，零改动
- **EPUB**：零改动

---

## 📊 当前进度（真实状态，2026-07-05 22:35 更新）

| Task | 状态 | 说明 |
|------|------|------|
| spec + plan | ✅ 完成 | commit `3761f84` |
| Task 3: MD scroll 管线 | ✅ 完成 | `reader_engine_provider.dart`：MD 调 `setPaginationMode(scroll)`，TXT 不调 |
| Task 1: PDF 双 viewer 共享 PdfDocument | ✅ 完成 | `pdf_renderer.dart`：双 PdfViewer 相同 sourceName + NeverScrollableScrollPhysics + ValueKey 重建 |
| Task 2: PDF dispose timeout | ✅ 完成 | `_doc.dispose().timeout(3s)` 安全网 |
| Task 4: reader_body gate | ✅ 完成 | 注释更新，MD scroll 自动跳过双页 gate |
| Task 5: 测试 | ✅ 完成 | 29 (MD/TXT) + 10 (PDF) + 245 (reader) 全过，2 失败是无关的 PDF fixture 缺失 |
| Task 6: 构建 exe | ✅ 完成 | exe 已生成，启动测试通过（PID 38800） |
| Task 7: CHANGELOG + 提交 | 🔧 进行中 | CHANGELOG 已写，待提交 |

### ⚠️ 待用户端到端验证（SC1-SC9）
代码 + 测试 + 构建都过了，但 **PDF 死锁修复和 MD 段落修复需要用户实测确认**：
- SC1: PDF 加载并显示
- SC2: PDF 双页显示（主页 + 副页，无 2-3 错位）
- SC3: dispose < 5s（日志 `dispose done`）
- SC4: exe 双击 → 关闭 → 再双击能启动
- SC5: MD 段落完整不溢出
- SC6: MD 段内每行保留换行
- SC7: MD 无双页（scroll 单列）
- SC8: TXT 不回归（仍 paged + 双页）
- SC9: EPUB 不回归

**验证方法**：双击 `H:\projiect\电子书阅读平台\app\build\windows\x64\runner\Debug\zhiyue.exe`，分别测试 PDF/MD/TXT/EPUB 四种书，关闭后再次双击验证 exe 循环。

### 如果验证发现问题
- PDF 仍死锁：查 `%TEMP%\zhiyue_pdf.log` 的 `dispose` 段
- MD 仍溢出：确认 `reader_engine_provider.dart` 里 MD 分支调了 `setPaginationMode(scroll)`
- exe 仍无法二次启动：查 `%TEMP%\zhiyue_runner.log`

### git 当前状态
```
HEAD = 3761f84 (docs(m4.6-fix9): spec/plan)
未提交修改：
  M app/lib/features/reader/providers/reader_engine_provider.dart  (Task 3，已完成)
  M reader_engine_pdf_view/lib/pdf_renderer.dart                   (Task 1，进行中)
```

### 当前 pdf_renderer.dart 的"半成品"状态（重要！）
`pdf_renderer.dart` 现在**编译不过**，因为：
1. 已删除 `_leftController` / `_rightController` 字段
2. 但 `setPage()` 的 dual 分支还调用 `_goToDualPageSpread(target)` ← **此方法仍引用已删字段**
3. `_buildDualPage` 还引用 `_leftController` / `_rightController`

**接力第一步**：完成 Task 1 的剩余步骤（详见 plan Task 1 的 Steps 1.3-1.8）：
- [ ] 1.3 重写 `_buildDualPage`：左 Expanded 用单 `PdfViewer.data(controller: _mainController)`，右 Expanded 用 `FutureBuilder` + `CustomPaint` 绘制副页位图
- [ ] 1.4 新增 `_renderDualPreview(PdfDocument doc, int pageIdx0)`：调 `doc.pages[pageIdx0].render(fullWidth:, fullHeight:, flags: limitedImageCache)` → `PdfImage.createImage()` → 返回 `ui.Image`
- [ ] 1.5 `setPage` dual 分支：调 `_mainController.goToPage(leftIdx+1)` + setState 触发副页 render
- [ ] 1.6 删除 `_goToDualPageSpread` 方法（旧实现）
- [ ] 1.7 保留 `pdfDiagLog` 日志
- [ ] 1.8 `dart analyze lib/` 通过

然后 Task 2（dispose timeout）、Task 4-7。

---

## 🛠️ 环境关键约定（AGENTS.md 摘要）

```bash
conda activate ebook                      # 必须，自动配 Flutter PATH + 镜像
/c/flutter/bin/dart.bat analyze lib/      # 静态分析（不用 flutter analyze，会崩）
/c/flutter/bin/flutter.bat test --concurrency=1   # 测试（drift 必须并发=1）
```
- CJK 路径：用 `dart.bat analyze lib/`（按包），不要单文件
- MSVC C4819：改 `main.cpp` 中文注释必须保留 UTF-8 BOM
- Tavily 搜索是备用，主搜索不可用时才用
- 测试 exe：`H:\projiect\电子书阅读平台\app\build\windows\x64\runner\Debug\zhiyue.exe`
- 日志：`%TEMP%\zhiyue_pdf.log`（PDF）、`%TEMP%\zhiyue_runner.log`（启动）

## 📐 文档纪律（superpowers）
- spec → plan → CHANGELOG 三件套，缺一不可
- 提交信息用 heredoc（避免反引号）
- spec/plan 已存在，本任务完成后写 CHANGELOG `[Unreleased]` 区段

## 🚨 历史失败教训（避免重蹈）
- PDF fix4~fix8 共 5 次失败：都在"双 PdfViewer"架构上打补丁 → 死锁没解决
- MD fix2/3/5/7 共 4 次失败：都在"paged 模式 + 修 Paginator/换行"上打补丁 → 段落还是溢出
- **fix9 是架构重写，不要再走老路**

---

## ✅ 接力会话的第一步动作清单

新会话开始时，按以下顺序执行：

1. **读本文件**（你刚读完）
2. **读 spec**：`docs/superpowers/specs/2026-07-05-m4.6-fix9-pdf-dual-page-and-md-pipeline-design.md`
3. **读 plan**：`docs/superpowers/plans/2026-07-05-m4.6-fix9-pdf-dual-page-and-md-pipeline.md`
4. **检查 git 状态**：`git status` + `git log --oneline -3`，对照本文件的"当前进度"
5. **检查 pdf_renderer.dart 当前状态**：读 `reader_engine_pdf_view/lib/pdf_renderer.dart`，确认半成品的具体行号
6. **TodoWrite 重建任务列表**（见 plan 的 7 个 Task）
7. **从 Task 1 步骤 1.3 继续**：重写 `_buildDualPage` + 新增 `_renderDualPreview`
8. **完成 Task 1-7**，每完成一个 Task 更新 TodoWrite + 提交
9. **完成后**：更新本 RESUME.md 标记"✅ 已完成"，删除定时任务（见下方清理命令）

## 🧹 任务完成后清理定时任务
```bash
schtasks /Delete /TN "ZhiYue_M4_6_fix9_Resume" /F
```
