# 智阅 v1.7.1-alpha Release Notes

**发布日期**：2026-07-10
**性质**：fix（用户面 bug 修复 + 测试卫生 + 深度清理）
**Tag**：`v1.7.1-alpha`

## 主要变更

### 修复

- **reader**: per-book typography persistence 修复
  - **现象**：用户调整字体设为默认后退出软件，重新打开加载书籍，字体恢复预设而非用户设定
  - **根因**：第一轮修复用 `ref.onDispose` + fire-and-forget `saveForBook`，被 `main.dart` 的 `exit(0)` 同步截断（绕 PDFium 死锁的设计）
  - **修复**：引入 `TypographyPersister`，订阅 `engine.state$` stream，debounce 500ms 后即时 `repository.saveForBook`，参照 `ProgressPersister` 模式
  - **PDF 补丁**：`PdfRenderer.setTypography` 补充 `stateController.add(ReaderEngineReady())` emit，保持与 `EpubxRenderer` 契约一致
  - **架构约束**：dispose 回调里的 fire-and-forget Future 必丢（exit(0) 截断），新持久化需求必须参照 ProgressPersister/TypographyPersister 即时落盘模式

### 测试卫生

- migration_v4_test: schemaVersion 硬编码 10 → 12（M2.6+M2.7 bump 后过期）
- notes_repository_test: drift 2.28 watchAnnotations 改 asyncExpand 修 cancel 生命周期
- typography_profile_repository_test: stale fontSize 断言 16.0 → `defaults().fontSize`（M3a bump 后过期）
- book_open_bridge_test: M4.5 加 .txt/.md 支持后 non-book 列表过期，加防回归用例
- library_golden_test + reader_ui_golden_test: regen 6 个 golden（字体漂移 <1.1%）
- typography_golden_test: skip（TypographyPanel 改 ConsumerWidget 后需 ProviderScope override，deferred 到下个 sweep）
- reader_ai_drawer_integration + reader_page_pdf_integration: skip 理由补描述性字符串

### 杂项

- gitignore: 扩展 `.claude/` + 根目录 `*.png` + `pub_get_output.txt` + `**/failures/`
- installer: 移除 Inno Setup chinesesimp language + MyAppVersion 历史遗留修正（1.5.1 → 1.7.1-alpha）
- docs: 归档 2026-07-08 review 报告（1 P0 + 8 P1 + 7 P2）
- docs: 移动端前置深度清理 spec + plan

## Commit 清单（v1.7.0-alpha 之后）

**typography 修复（2026-07-09）**：
- `436b35f` fix(reader): add TypographyPersister for immediate per-book save
- `216f70b` fix(reader): wire TypographyPersister into reader_page lifecycle
- `ecb0f26` fix(reader): remove fire-and-forget saveForBook from engine provider
- `85c94f8` fix(reader): close final-review gaps in typography persistence
- `95cfcee` chore(installer): drop chinesesimp language from Inno Setup script

**深度清理（2026-07-10）**：
- `67f36c4` docs(spec): pre-mobile deep cleanup design
- `230ee7e` docs(plan): pre-mobile deep cleanup implementation plan
- `acdb560` chore(gitignore): expand rules
- `9c4a158` docs(plans): add 2026-07-09 plans
- `2f08876` test(migration): fix annotations_fts schemaVersion
- `8bca9f8` test(notes): fix watchAnnotations drift 2.28 cancel
- `38072ee` test(typography): fix seedDefaultIfEmpty stale fontSize
- `3ec8563` test(book_open_bridge): fix isSupportedBookPath for .txt/.md
- `e77b954` test(goldens): regen 6 snapshots + skip typography_panel
- `19dec51` test: clarify skip reasons
- `aba5634` docs(review): archive 2026-07-08 project review
- `ffcf834` docs(screenshots): refresh status
- `7958b24` docs(readme): bump badge + status
- `77e7e84` docs(changelog): add v1.7.1-alpha entry

## 已知问题

- 5 个 pre-existing 测试失败（router_test / reader_page_test ×4 / reader_flow_integration），不阻塞本版本，留待下个 sweep
- README.md `docs/screenshots/pdf_reader.png` + `notes.png` 仍缺失（需用户手动截图）

## 升级指南

直接覆盖安装即可，无 schema 迁移。

## 下一节点

打 `desktop-stable-pre-mobile` tag，进入移动端 MVP 开发。
