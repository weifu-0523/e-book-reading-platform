# 🔄 RESUME — M4.6-fix10 接力棒

> **本文件由 2026-07-06 会话编写。M4.6-fix10 代码已完成并推送 Gitee。**
> **新会话开始时：先读本文件，再读 spec + plan + CHANGELOG。**

**最后一次更新**：2026-07-06（fix10 全部 6 个 Task 完成，已推送）

---

## 🎯 当前任务

**M4.6-fix10 已完成代码侧修复。需要用户端到端验证 SC1-SC7。**

spec：`docs/superpowers/specs/2026-07-06-m4.6-fix10-six-bugs-design.md`
plan：`docs/superpowers/plans/2026-07-06-m4.6-fix10-six-bugs.md`
CHANGELOG：`[Unreleased]` 区段 `### M4.6-fix10 — 2026-07-06`

## ✅ 已完成的 6 个修复

| # | 问题 | 修复 | 关键文件 |
|---|------|------|---------|
| 1 | PDF 双页卡死 | 彻底锁死单页（移除 toggle 按钮） | reader_body.dart:407,576-584; pdf_renderer.dart |
| 2 | MD 排版乱 | 仿 TXT 每行成 `<p>`（根因：`<br>` 不增 plain 偏移却增视觉高度） | markdown_book_loader.dart; reader_engine_provider.dart |
| 3 | EPUB 卡顿 | O(N²)→O(N)：整章 DOM 解析一次复用（非破坏式遍历） | html_slicer.dart; epubx_renderer.dart |
| 4 | 双页跨页选区 | 每页独立 SelectionArea（局部 registrar 隔离） | epubx_renderer.dart; reader_body.dart |
| 5 | 摘录不刷新 | watchAnnotations 双表 watch（修复首条摘录场景 stream 提前终结） | book_notes_dao.dart; local_notes_repository.dart |
| 6 | 红色蒙层 | ErrorWidget.builder + FlutterError.onError + runZonedGuarded | main.dart |

## 🧪 待用户验证（SC1-SC7）

- [ ] **SC1**：PDF 打开任意书籍，主区永远单页，工具栏**无双页 toggle 按钮**
- [ ] **SC2**：PDF 翻页时，缩略图 grid 当前页高亮**实时跟随**（无需关闭重开 drawer）
- [ ] **SC3**：打开 MD 文件，章节 TOC 完整（按 `#`/`##` 切章），正文 paged 翻页流畅、无双页跨页溢出、段落不被切到页中
- [ ] **SC4**：EPUB《一本书读懂财报》（或任意长章节书）翻页流畅、目录点击立即跳转，无卡顿
- [ ] **SC5**：EPUB 双页模式下，选左页某几行**只选中左页**，右页同行不被选中；TXT 同样修复
- [ ] **SC6**：对**新书**（尚无任何摘录）首次添加摘录后，notes drawer 立即出现该摘录，无需退出书架重进
- [ ] **SC7**：build 异常显示**自定义错误占位**（白底+图标+文字），不再红屏；导航条保留

## ⚠️ 已知阻塞（非代码问题）

**构建 exe 失败**：Flutter `gen_snapshot` 在中文路径 `H:\projiect\电子书阅读平台` 下用 GBK 解码路径，UTF-8 中文变乱码 `锟斤拷`，找不到 app.dill。

**这是 Flutter 工具链 pre-existing bug，与代码改动无关**（fix9 之前的构建如果是英文路径才能成功）。

Workaround（按推荐度排序）：
1. **Junction 法（推荐）**：在英文路径创建 junction
   ```cmd
   mklink /J C:\zhiyue H:\projiect\电子书阅读平台
   cd C:\zhiyue\app
   flutter build windows --release
   ```
2. **临时移盘**：把项目复制到 `C:\zhiyue` 构建，构建完拷回 exe
3. 等 Flutter 修复 gen_snapshot 的 UTF-8 路径支持

## 📊 测试状态

- 751 通过 / 14 跳过 / 254 失败
- **254 失败全部是 drift native fts5 模块环境缺失**（pre-existing，fix9 HEAD 就失败，与本次改动无关）
- 本次改动相关测试全绿：
  - MD loader：28 个通过
  - html_slicer：21 个通过（含 3 个新增非破坏式测试）
  - epubx_renderer dual page：10 个通过

## 📝 MD 根因铁证（用户重点关心的问题 2）

用同一份 4 行文本「第一点\n第二点\n第三点\n第四点」对照实验：
- TXT 产出：`<p>第一点</p><p>第二点</p><p>第三点</p><p>第四点</p>`（4 个独立 `<p>`，无 `<br>`）
- MD 旧产出：`<p>第一点<br />第二点<br />第三点<br />第四点</p>`（1 个 `<p>` 内含 3 个 `<br>`）
- MD 新产出（fix10）：与 TXT 完全一致（4 个独立 `<p>`）

根因：fix7 的 `_forceVisibleLineBreaks` 给每行尾加两空格 → markdown 标准库识别为 hard break → 产 `<br>`。但 Paginator 按 plain text 字符偏移测高，`<br>` 不增加偏移却增加视觉高度 → 测出来"很矮"、实际"很高" → 一页塞太多 → 溢出。

## ➡️ 下一步

用户构建 exe（用 junction workaround）后，手动验证 SC1-SC7。如有回归，回到 plan 对应 Task 修复。

若全部通过，可以开始规划 M4.7（PDF 双页重写——用 PageView + PdfPage.render 自绘方案，绕开 pdfrx 双 PdfViewer 竞态）。
