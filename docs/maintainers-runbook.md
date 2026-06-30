# 智阅 Maintainer's Runbook

**目标读者**：新接手项目的维护者（人或 Claude 实例）。读完本文 + `docs/superpowers/specs/2026-06-24-ebook-platform-design.md` 应能：

1. 在新机器上 setup dev env 并跑通测试
2. 知道中文路径的所有坑与对应 workaround
3. 派遣子代理执行 task（model 选择、prompt 必填项）
4. 跑 release 流程出 Windows installer + Gitee Release

本文是冷启动手册。设计动机看 spec，里程碑细节看 `CHANGELOG.md` 与 `docs/superpowers/plans/`。

---

## 1. 项目概览

| 字段 | 值 |
|---|---|
| 项目 | 智阅（Zhi Yue）— Flutter 跨平台电子书阅读平台 |
| 目标用户 | 深度阅读 / 学习者（非休闲读者） |
| 平台 | Windows + Android（Mac 后期） |
| 技术栈 | Flutter 3.44 / Dart 3.10 / drift 2.18 / riverpod 2.5 / go_router 14 |
| 支持格式 | EPUB（完整）+ PDF（文本完整 + 扫描仅阅读） |
| AI 接入 | BYOK，OpenAI-compatible（先期 DeepSeek） |
| 同步 | 坚果云 WebDAV（不自建后端） |
| 知识库 | App 内读书笔记 + Markdown 导出（Obsidian 兼容） |
| 商业模式 | 免费开源 |
| 协议 | AGPLv3 |
| 仓库 | `gitee.com:weifu0523/e-book-reading-platform.git`（单仓库 monorepo） |
| 本地化 | 中英双语（默认中文） |

**关键文档位置**：

- 整体设计：`docs/superpowers/specs/2026-06-24-ebook-platform-design.md`
- Phase 2 路线图：`docs/superpowers/specs/2026-06-28-phase2-roadmap-design.md`
- 里程碑 spec：`docs/superpowers/specs/2026-06-{date}-{milestone}-design.md`
- 里程碑 plan（task 拆分）：`docs/superpowers/plans/2026-06-{date}-{milestone}.md`
- Code review：`docs/superpowers/reviews/`
- 发布流程：`docs/release-procedure.md`

**仓库结构**：

```
电子书阅读平台/                  # repo root（中文路径，见 §3）
├── app/                         # 主 Flutter app（zhiyue）
├── reader_engine/               # 阅读引擎抽象 package
├── reader_engine_epub_view/     # EPUB 渲染实现
├── reader_engine_pdf_view/      # PDF 渲染实现（pdfrx）
├── epubx_patched/              # epubx 本地 fork（修 image 4.x 兼容）
└── docs/                        # 设计文档 + 本 runbook
```

**里程碑索引**（截至 v0.9.1-alpha）：

- M0+M1：数据层基础（drift schema + DAOs）
- M2：EPUB 阅读器（epubx + 自研渲染）
- M3.1–M3.5：库页 + 标签 + 高亮/笔记 + FTS5 跨书搜索 + 精确 locator + per-book NotesPage + Markdown 导出 + 设置/字体/i18n
- M4：PDF 渲染（pdfrx + Page-as-Chapter + 文本高亮 + 扫描降级）
- M7：平台适配（图标 / 显示名 / deep-link / 签名）
- M8：发布打包（Windows 单实例 + Inno Setup installer + v0.5.0）
- M2.0a/b：坚果云 WebDAV 双向同步 + 冲突日志 + 后台定时
- M1.5a/b/c：AI MVP（OpenAI-compatible LLM + 三模式导读 + 摘要缓存 + 同书 Q&A + 引用跳转）
- M1.6：Polish Sweep（reader 拆分 + i18n + UX 三态 + runbook + 截图 + perf baseline） → v1.0.0

---

## 2. Dev Environment Setup

### 2.1 必装

- **Flutter 3.44 stable**（项目最早 pin 3.27，目前用 3.44.2；`pubspec.yaml` 约束 `flutter: ^3.27.0`）
- **Dart 3.10+**（`pubspec.yaml` 约束 `sdk: ^3.10.0`）
- **Git for Windows** + 配置好 SSH key 能 push Gitee
- **Visual Studio 2022** with "Desktop development with C++" workload（Windows native build 需要 cl.exe + ATL）
- **Android Studio**（Android SDK + emulator；M8 之后才有 Android build，setup 见 `docs/setup-android-sdk.md`）
- **Inno Setup 6**（仅 release 时需要，编译 Windows installer）

### 2.2 Flutter SDK 安装位置

本机约定：`C:\flutter`（Gitee 镜像 `https://gitee.com/mirrors/Flutter.git`）。其他位置也行，但 PATH 配置与下文命令需要相应调整。

### 2.3 中国镜像（重要）

**Pub mirror**（系统环境变量或本地脚本）：

```
set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
set PUB_HOSTED_PUB=https://pub.flutter-io.cn
```

**Gradle 镜像**（用户级 `~/.gradle/init.gradle`，Android build 用）：

```gradle
allprojects {
  repositories {
    maven { url 'https://maven.aliyun.com/repository/public' }
    maven { url 'https://maven.aliyun.com/repository/google' }
    mavenCentral()
    google()
  }
}
```

`gradle-wrapper.properties` 的 distributionUrl 用 Tencent 镜像拉 distribution。

### 2.4 Clone + First Run

```bash
git clone git@gitee.com:weifu0523/e-book-reading-platform.git 电子书阅读平台
cd 电子书阅读平台/app
flutter pub get
flutter gen-l10n           # 生成 lib/gen_l10n/app_localizations*.dart
flutter run -d windows
```

如果改了 `app/lib/data/local/database.dart`（drift schema），还需要：

```bash
cd app
dart run build_runner build --delete-conflicting-outputs
```

这会重新生成 `*.g.dart`（DAO / database）。生成的文件已 commit 进仓库，正常开发不需要跑。

---

## 3. 中文路径坑（必读）

项目根目录是 `H:\projiect\电子书阅读平台`，含中文字符。这是用户有意为之，不要改成 ASCII 路径。但它带来以下约束：

### 3.1 `flutter analyze` 必崩溃 → 用 `dart analyze`

**症状**：`flutter analyze`（workspace 模式）启动 analysis_server LSP，LSP 在 JSON-RPC 消息中 URL-encode 中文路径，多字节 UTF-8 跨消息块时解析失败，报 `FormatException: Unterminated string`。

**修复**：永远用 `dart analyze`，它走 CLI 不走 LSP：

```bash
cd app
/c/flutter/bin/dart.bat analyze           # 全 lib
/c/flutter/bin/dart.bat analyze lib/path/to/file.dart   # 单文件
```

**注意**：`flutter test` 不受影响（走 test runner 不走 LSP）。所以测试可以正常跑。

### 3.2 Windows bash 下用 `.bat` 而非 `.exe`

`flutter` / `dart` 命令在 Windows bash（Git Bash / MSYS）下要用 `/c/flutter/bin/flutter.bat` 与 `/c/flutter/bin/dart.bat`，**不是** `.exe`。`.bat` 才是入口，shell 能直接执行；用 `.exe` 会报找不到或行为异常。

### 3.3 PATH 未持久化

每个新 bash 会话都需要：

```bash
export PATH="/c/flutter/bin:$PATH"
```

否则 `flutter` / `dart` 命令找不到。建议写进 `~/.bashrc`，但子代理派遣时仍要显式 export 防止遗漏。

### 3.4 MSBuild / cl.exe UTF-8↔GBK 冲突

Windows native **release** build 时，cl.exe 处理含中文路径的源文件会失败（编译错误或链接错误）。

**临时方案**：把 `app/` 复制到 ASCII 路径再 build：

```bash
mkdir -p /c/dev/zhiyue-smoke
cp -r app/* /c/dev/zhiyue-smoke/
cd /c/dev/zhiyue-smoke
flutter build windows --release
```

**长期方案**：M8 的 Inno Setup installer 脚本（`app/windows/installer/zhiyue.iss`）已设计为在 ASCII 路径下编译。日常 debug build 一般不出问题。

### 3.5 子代理派遣必填项

每个 Flutter 相关子代理 prompt 必须包含以下 5 点，否则几乎必失败：

1. `export PATH="/c/flutter/bin:$PATH"`（PATH 未持久化）
2. 用 `/c/flutter/bin/dart.bat analyze` 代替 `flutter analyze`
3. 工作目录绝对路径：`H:\projiect\电子书阅读平台\app`
4. 提交后必须 push 到 Gitee（`git push origin master`）
5. Commit message 格式：`<type>(<milestone>/<task>): <subject>` + HEREDOC 末尾 `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`

---

## 4. 日常工作流（Daily Workflow）

### 4.1 跑测试

```bash
cd "H:\projiect\电子书阅读平台\app"
/c/flutter/bin/flutter.bat test --concurrency=1
```

**为什么 `--concurrency=1`**：drift Native 库（sqlite3）在并发 isolate 加载时偶现冲突；concurrency=1 是项目约定，能稳定跑全套 ~670 测试。

**不要用 `dart test`**：drift 的 Native 库需要 Flutter test runner 加载，`dart test` 跑不了。

跑单个测试文件：

```bash
/c/flutter/bin/flutter.bat test --concurrency=1 test/data/models/book_from_row_test.dart
```

跑单个测试用例（按名字）：

```bash
/c/flutter/bin/flutter.bat test --concurrency=1 --plain-name "maps all 11 fields from a drift BookData row (EPUB)"
```

**已知 flaky**：`app/test/.../background_sync_scheduler_test.dart` 的 "isRunning reflects current state"（30ms/50ms wall-clock waits）。单跑通过，并发跑偶现。不要为它改代码，重跑即可。

### 4.2 静态分析

```bash
cd app
/c/flutter/bin/dart.bat analyze
```

预期输出：仅 `epubx_patched/` 包内的错误（本地 fork，第三方代码）+ 已知 infos。app/ 内应为 0 issue。

### 4.3 生成 l10n

```bash
cd app
/c/flutter/bin/flutter.bat gen-l10n
```

配置在 `app/l10n.yaml`：

```yaml
arb-dir: lib/l10n
template-arb-file: app_zh.arb
output-localization-file: app_localizations.dart
output-dir: lib/gen_l10n
preferred-supported-locales: [zh, en]
```

模板是 `app_zh.arb`（中文），翻译是 `app_en.arb`。生成产物 `app/lib/gen_l10n/app_localizations*.dart` 已 commit 进仓库；改 ARB 后必须重跑 gen-l10n 并 commit 生成文件。

### 4.4 跑生成代码（drift / riverpod）

只有改 drift schema（`database.dart`）或 riverpod annotation 时需要：

```bash
cd app
/c/flutter/bin/dart.bat run build_runner build --delete-conflicting-outputs
```

### 4.5 Windows debug build

```bash
cd app
/c/flutter/bin/flutter.bat run -d windows
```

### 4.6 Windows release build

```bash
cd app
/c/flutter/bin/flutter.bat build windows --release
```

如果失败且错误信息含中文路径相关字符，参考 §3.4 复制到 ASCII 路径。

### 4.7 Windows native smoke test（M1.6 T12 引入）

```bash
cd app/windows/runner
./run_smoke_test.bat
```

构建并跑 `test_main.cpp`，验证 deep-link parser 的 CLI 参数解析逻辑（不依赖 Flutter engine）。

---

## 5. Subagent-Driven Development

### 5.1 何时用

- 多 task plan（如 M1.6 16 个 task）
- 每个 task 独立可验证（test 或 build）
- 不需要跨 task 共享上下文（每个 task 自包含）

### 5.2 流程

每个 task 走：

1. **Plan**：读 task spec（plan 文件对应 Task 段），写到 prompt
2. **Implement**（TDD：红→绿→重构）：子代理执行
3. **Spec review**：另一个子代理或主线验证实现符合 spec
4. **Quality review**：验证代码质量（无 lint / 无 dead code / 无 unused import）
5. **Commit**：per-task commit（HEREDOC + Co-Authored-By）
6. **Push**：每个 commit 推 Gitee

### 5.3 Model 选择规则

按当前北京时间（24h制）选 model：

| 时段 | Model | 理由 |
|---|---|---|
| 14:00–18:00 | `haiku` | 避开 opus 限额高峰 |
| 18:00–次日 14:00 | `opus`（首选） | 限额窗口外，opus 一次通过率更高 |

implementer + reviewer 用同一 model。

**特殊情况**：

- **C++ / Windows native / Win32 API**：用 `sonnet`（中文路径风险 + 类型严格，opus 浪费、haiku 不够稳）
- **复杂 plan bug 修复**：如 haiku 子代理多次 BLOCKED / DONE_WITH_CONCERNS，等 18:00 后用 opus 重派

### 5.4 Prompt 必填项

派遣子代理时，prompt 必须含：

1. **完整任务文本**：直接贴 plan 的 Task 段（不要让子代理自己读 plan 文件，容易读偏）
2. **环境约束**：§3 的 5 点（PATH、dart analyze、工作目录、push、commit 格式）
3. **文件路径**：绝对路径，不要相对
4. **验收标准**：明确写"test 通过 / analyze 0 issue / 文件存在"
5. **报告格式**：要求子代理返回 status / commit SHA / 测试数 / 关键决策

### 5.5 TDD 纪律

每个 task：

- 先写失败测试（红）
- 实现到测试通过（绿）
- 重构（不变行为）
- commit

不要"先实现再补测试"。重构阶段不能改 public API。

---

## 6. Git 工作流

### 6.1 分支策略

- 主干：`master`
- **不开 PR 分支**，直接在 master 提交（单人项目，PR 流程是开销）
- 每个 commit 推 Gitee（用户已立规则：每次迭代都推送，避免本地丢失）

### 6.2 Commit message 格式

Conventional commits：

```
<type>(<scope>): <subject>

<body>

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
```

**Types**：`feat` / `fix` / `refactor` / `test` / `docs` / `chore` / `perf`

**Scope**：`<milestone>/<task>`，如 `m1.6/t13`，或功能域 `ai` / `reader` / `sync` / `library`。

**HEREDOC 示例**（bash）：

```bash
git commit -m "$(cat <<'EOF'
docs(m1.6/t13): maintainer's runbook

Cold-start guide for new maintainers covering setup, Chinese path
quirks, daily workflow, subagent model selection, git/release flow,
common bugs, perf baseline methodology, and glossary.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

### 6.3 Stage 文件

**Windows bash 下用单行 git add**：

```bash
git add docs/maintainers-runbook.md
```

不要用反斜杠续行（`\`）多行 add，Windows bash 解析不稳定。多文件就多行 add。

### 6.4 禁用项

- **不用** `--no-verify`（绕 pre-commit hook）
- **不用** `git push --force`（破坏远程历史；如必须，先与用户确认）
- **不** `git commit --amend` 已 push 的 commit
- **不** `git reset --hard` 远程已 push 的 commit
- **不** `git rebase -i` 已 push 的 commit

### 6.5 推送

```bash
git push origin master
```

如果只推 tag：`git push origin refs/tags/v1.0.0`。

---

## 7. Release 流程

### 7.1 Version bump 位置

- `app/pubspec.yaml`：`version: 1.0.0+0`（`major.minor.patch+build`）
- `CHANGELOG.md`：顶部加新 section
- `windows/runner/Runner.rc`（如果改了 VERSIONINFO；M8 之后默认不动）

### 7.2 CHANGELOG

`CHANGELOG.md` 顶部加：

```markdown
## [1.0.0] - 2026-06-30

### Added
- M1.6 T8: reader_page 拆分为 4 文件（reader_body / reader_action_handlers / reader_progress_bar / reader_typography_panel_trigger）
- M1.6 T9: shared UX state widgets（LoadingView / EmptyView / ErrorView）
...

### Changed
- ...

### Fixed
- ...
```

### 7.3 双 tag（milestone + version）

项目惯例是每个里程碑打两个 tag：

```bash
git tag -a m1.6-polish-sweep -m "M1.6 Polish Sweep — reader split + UX states + runbook + perf baseline"
git tag -a v1.0.0 -m "v1.0.0 — Phase 2 finale"
git push origin master --tags
```

历史示例：`m4-complete` + `v0.5.0`、`m1.5a-complete` + `v0.7.0-alpha`。

### 7.4 Windows installer build

```bash
cd app
/c/flutter/bin/flutter.bat build windows --release
# 编译 installer（需要本机装 Inno Setup 6）
cd windows/installer
iscc zhiyue.iss
```

输出：`app/windows/installer/Output/ZhiYueSetup-<version>.exe`。

详细 release 步骤（含 portable zip）见 `docs/release-procedure.md`。

### 7.5 Gitee Release

1. 浏览器打开 `https://gitee.com/weifu0523/e-book-reading-platform/releases/new`
2. 选刚推的 tag（如 `v1.0.0`）
3. 标题：`v1.0.0 — M1.6 Polish Sweep`
4. 描述：贴 CHANGELOG `[1.0.0]` 段 + 链接到本 runbook
5. 附：installer exe + 4 张截图（`docs/screenshots/library.png` / `epub_reader.png` / `pdf_reader.png` / `notes.png`）
6. 发布

### 7.6 截图

截图通过 Win32 `PrintWindow(hwnd, hdc, 0x2)` 在窗口 iconic 恢复后捕获（M8 T14 验证可行，2208×1200 PNG）。详见 `docs/release-procedure.md`。

---

## 8. 常见 Bug 与修复

### 8.1 `Stream.timeout` 不触发（async* 源 paused）

**症状**：异步生成器（`async*`）yield 后 await 一个永不完成的 future，外层 `Stream.timeout` 不触发。

**原因**：Dart 的 `Stream.timeout` 在源订阅 paused 时不走表。async* 源 yield 后 await 触发 paused 状态。

**修复**：用 `StreamIterator.moveNext().timeout()` 替代，无 pause 耦合。见 `app/lib/services/ai/book_qa_service.dart`（M1.5bc Review Fixups C1 修复的内存泄漏同源）。

### 8.2 drift DAO mocking 困难 → 抽 `Like` 接口

**症状**：drift DAO 直接 fake 麻烦（`DatabaseAccessor` mixin 要求 db accessor）。

**修复**：抽 `Like` 接口。例如 `QaHistoryDaoLike`，让 widget test 用 fake 实现。见 `app/lib/data/local/daos/qa_history_dao.dart` 的 `QaHistoryDaoLike`。

### 8.3 drift 表名复数 vs 数据类单数

**症状**：drift 表 `Books` 生成的数据类是 `Book`（单数），不是 `Books`。容易写错。

**修复**：参考 `database.dart` 的 `@DataClassName('Book')` 注解；测试里用 `BookData` / `Book` 别名 `as drift` 区分 domain model 与 drift row（domain model 也叫 `Book`，见 `app/lib/data/models/book.dart`）。

**派生坑**：domain `Book` 与 drift `Book` 同名。`library_page.dart` / `book_detail_page.dart` 用 `Book.fromRow(row)` factory（M1.6 T1 引入）转换；不要直接 `as` cast。

### 8.4 provider 默认 `throw UnimplementedError` 引发 widget test 噪音

**症状**：widget test 不 override 某 provider 时，`initState` post-frame 读它会抛 `UnimplementedError`，被 unawaited future 吞但打印 stack trace，污染测试日志。

**修复**：默认值改 NoOp（inert）+ production override 在 `app/lib/core/app_providers.dart` 的 `providers` list。见 `_NoOpQaHistoryDao` 模式（M1.6 T4 引入）。

### 8.5 `ActionChip.onLongPress` 不存在

**症状**：Flutter `ActionChip` 没有 `onLongPress` 回调。

**修复**：用 `GestureDetector(behavior: HitTestBehavior.translucent, onLongPress: ...)` 包，保留 chip 的 onPressed 涟漪。

### 8.6 `TapGestureRecognizer` 不自动 dispose → 内存泄漏

**症状**：`TextSpan.recognizer` 创建的 recognizer framework 不自动 dispose，造成内存泄漏。

**修复**：StatefulWidget 持有 refs，在 `dispose()` 和 `didUpdateWidget` 中手动 dispose。见 `app/lib/features/ai/widgets/qa_answer_view.dart`（M1.5bc Review Fixups C1）。

### 8.7 drift DateTime 等值比较丢失 isUtc

**症状**：drift 默认存 unix 秒丢失 `isUtc` 标志，`==` 比较两个 DateTime 返回 false。

**修复**：用 `isAtSameMomentAs` 而非 `==`。

### 8.8 `connectivity_plus` 6.x API 变化

**症状**：`checkConnectivity()` 在 6.x 返回 `List<ConnectivityResult>` 而非单个值。

**修复**：检查 `results.any((r) => r == ConnectivityResult.none)` 或 `results.contains(ConnectivityResult.wifi)`。

### 8.9 FlutterSecureStorage 不能用 `noSuchMethod` mock

**症状**：plan 写的 `noSuchMethod` mock 模式不工作（方法是具体的，不走 `noSuchMethod`）。

**修复**：用 `mocktail` 包，`when(() => storage.read(key: any(named: 'key'))).thenReturn(...)`。

### 8.10 Windows C++ 类型严格性

**症状**：plan 写伪代码时容易忽略 Windows 类型严格性；实际 MSBuild `/WX` 把警告当错误。

**修复**（M8 T4/T5 教训）：

- `size_t` → `DWORD`：用 `static_cast<DWORD>`
- `SendMessageW` 的 WPARAM 拒绝 `nullptr`：用 `0`
- `reinterpret_cast<uintptr_t>(1)` 无效（1 是 int 不是指针）：先 `static_cast<uintptr_t>(1)` 再 reinterpret

未来 Windows-native task plan 必须在 quality-review 阶段跑一次实际 `flutter build windows` 验证。

### 8.11 `background_sync_scheduler_test` flaky

**症状**：`isRunning reflects current state` 单跑通过，并发跑偶现。

**原因**：30ms/50ms wall-clock waits 在 CI 慢机不可靠。

**修复**：不修。重跑。本项目约定 `--concurrency=1` 已大幅缓解。

---

## 9. Performance Baseline 测量

### 9.1 冷启动（cold start）

```bash
cd app
/c/flutter/bin/flutter.bat run --trace-startup --profile -d windows
```

Flutter 退出后写 `build/flutter_01.json`。读：

- `engineEnterTimestampMicros` vs `timeToFrameworkSetupMicros`：engine → framework 时间
- 目标：< 2000ms（具体数字由 M1.6 T15 实测填入）

### 9.2 FPS / jank

```bash
/c/flutter/bin/flutter.bat run --profile -d windows
```

打开 PerformanceOverlay（Settings 里 toggle，或代码中 `MaterialApp(showPerformanceOverlay: true)`）。

场景：打开一本 5MB EPUB，连续滚动 30s，看右上角 FPS 线。目标：≥ 55 fps（60Hz 屏幕）。

### 9.3 内存峰值

```bash
/c/flutter/bin/dart.bat pub global activate devtools
/c/flutter/bin/dart.bat pub global run devtools
```

浏览器打开 DevTools → Memory tab → "Take a snapshot"。

场景：打开大 PDF（50MB+），翻 20 页，记录 RSS 峰值。目标：< 500MB。

### 9.4 Measured Baseline（v1.0.0）

实测数字由 M1.6 T15（perf baseline task）填入。下表为目标门限；release 前 T15 会跑 §9.1–9.3 三个场景并把数字写到本节。任何未达目标项必须在 release notes 显式说明。

| 指标 | 目标 | 实测 v1.0.0（T15 填） |
|---|---|---|
| Cold start (windows) | < 2000ms | — |
| EPUB 滚动 FPS（5MB 书，30s） | ≥ 55 fps | — |
| PDF 50MB 内存峰值 | < 500MB | — |

---

## 10. Glossary

| 术语 | 含义 |
|---|---|
| **drift** | Dart 的 SQLite ORM，类型安全 + schema migration。本项目用它做所有本地持久化（books / annotations / notes / progress / sync_outbox / sync_conflicts / ai_summaries / book_passages / qa_history 等）。 |
| **riverpod** | Flutter 状态管理库（编译时安全，无 BuildContext 依赖）。本项目用 `flutter_riverpod` 2.5 + `riverpod_annotation`，部分 provider 用 codegen（`@riverpod` 注解 → `*.g.dart`），部分手写 `StateNotifierProvider`。 |
| **mocktail** | Dart 的 mock 库（vs mockito，不需要 build_runner）。本项目 widget test / dao test 用它。 |
| **FTS5** | SQLite 的全文搜索扩展。M3.2 用它做跨书搜索（annotations 表的 text 列）。CJK 不分词，用 LIKE 子串匹配补足（见 `book_passages_dao`）。 |
| **EPUBCFI** | EPUB Canonical Fragment Identifier，定位到段落 / 字符的标准。本项目早期用，后期换成自定义 `EpubRangeLocator` JSON（更简单）。 |
| **RangeLocator** | 项目内抽象，EPUB 和 PDF 各有实现（`EpubRangeLocator` / `PdfRangeLocator`），序列化为 JSON 存 annotations 表。 |
| **Page-as-Chapter** | PDF 渲染策略：PDF 第 N 页 = engine chapterIndex N-1。让 ReaderEngine 接口对 EPUB / PDF 统一。 |
| **epubx_patched** | epubx 4.0.0 的本地 fork，修了 image ^3.0.8 pin（pdfrx 需要 image 4.x）。仓库内 path dependency。 |
| **pdfrx** | Windows / Android PDF 渲染 Flutter package（v2.3+）。自带文本选择 / TOC / 夜间模式 / 懒加载。 |
| **BYOK** | Bring Your Own Key。AI 功能用户自己提供 API key（DeepSeek / OpenAI-compatible），存 `flutter_secure_storage`。 |
| **OpenAI-compatible** | API 兼容 OpenAI Chat Completions 格式（`/v1/chat/completions` + SSE streaming）。DeepSeek / Moonshot / 本地 Ollama 都走这个协议。 |
| **WebDAV** | HTTP-based 文件协议。本项目用它接坚果云做同步（push / pull / LWW）。 |
| **LWW** | Last-Write-Wins，同步冲突解决策略。本项目仅 LWW，不交互式合并（v1 YAGNI）。冲突落 `sync_conflicts` 表供用户查阅。 |
| **Outbox pattern** | 同步写入：本地先写 `sync_outbox` 表，后台 worker 异步推远端。失败重试，离线累积。 |
| **ConflictSink** | 同步冲突接收器抽象，让测试能注入 NullConflictSink（不记冲突）或 DbConflictSink（落表）。 |
| **ChapterBulletParser** | M1.5a 工具类，把 LLM 输出的章节导读（总结段 + bullet 列表）解析为结构化数据，bullet 可一键加入笔记。 |
| **TokenTruncator** | M1.5a 工具类，按 token 上限裁剪 LLM 输入。启发式：CJK=1 token，其他 4 chars=1 token。 |
| **BookPreprocessor** | M1.5b 服务，导入即批处理：每章跑 AiGuide 生成摘要 + 切 chunk 入 `book_passages`。 |
| **BookChunker** | M1.5b 工具，默认章即一 chunk，超过 100K token 才再切（深 500-token slice）。 |
| **chapterSwitchSettled** | ReaderEngine 接口方法，返回章节切换完成的 Future（paged 模式滚动到精确 offset 后 complete）。M3.4 引入。 |
| **TDD** | Test-Driven Development。本项目每个 task 红→绿→重构，先写失败测试再实现。 |
| **subagent-driven-development** | Claude Code 工作流：每个 task 派一个子代理执行 + 主线 review。本项目 phase 2 全程使用。 |
| **superpowers** | Claude Code 的 skills 集合（brainstorming / writing-plans / executing-plans / subagent-driven-development / test-driven-development / systematic-debugging 等）。本项目 plan 文件顶部都引用 `superpowers:subagent-driven-development`。 |
| **Cold start** | App 启动到首帧渲染的时间。`flutter run --trace-startup` 测量。 |
| **Smoke test** | 端到端冒烟测试。本项目指 `app/windows/runner/run_smoke_test.bat`（C++ 单元测试 deep-link parser）。 |

---

## 11. 相关文档

- 整体设计：`docs/superpowers/specs/2026-06-24-ebook-platform-design.md`
- Phase 2 路线图：`docs/superpowers/specs/2026-06-28-phase2-roadmap-design.md`
- M1.6 spec：`docs/superpowers/specs/2026-06-30-m1.6-polish-sweep-design.md`
- M1.6 plan：`docs/superpowers/plans/2026-06-30-m1.6-polish-sweep.md`
- 发布流程：`docs/release-procedure.md`
- Android SDK setup：`docs/setup-android-sdk.md`
- 最新 review：`docs/superpowers/reviews/`
- CHANGELOG：`CHANGELOG.md`
