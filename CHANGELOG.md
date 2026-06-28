# Changelog

本项目所有重要变更记录在此文件。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

M8 之后到 v1.0 之间的打磨工作将记在此处。

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
