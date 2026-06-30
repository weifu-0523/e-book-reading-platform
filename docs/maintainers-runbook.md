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

**已知 flaky**：`app/test/.../background_sync_scheduler_test.dart` 的 "isRunning reflects current state"（30ms/50ms wall-clock waits）。单跑通过，并发跑偶现。不要为它改代码，重跑即可。`app/test/.../book_import_service_test.dart` 的 "importFile concurrent same file" 同属此类（test 内 dedup 逻辑的并发 race，单独跑过、`--concurrency=1` 跑过）。

**真正被 `skip:` 标记的测试（v1.0.0 共 2 个，预存在项）**：

- `app/test/features/settings/font_import_service_test.dart:187` — `skip: 'FontLoader behavior on non-font bytes is environment-dependent'`
- `app/test/features/reader/reader_page_pdf_integration_test.dart:60` — `skip: true`（占位骨架，等 fixture + 真 reader widget 接通后启用）

新增 milestone 不应再增加 skip；如必须新增，需在 release notes 显式说明原因。

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

截图是**手动步骤**——subagent 无法驱动 Windows GUI 导航（导入书、开 reader、切到 Notes tab）。M8 T14 用 Win32 `PrintWindow(hwnd, hdc, 0x2)` 在窗口 iconic 恢复后捕获了 `epub_reader.png`（2208×1200 PNG），其余 3 张由用户在 v1.0.0 发布前补齐。

每张截图应展示的内容、捕获流程、当前 pending 状态详见 [`docs/screenshots/README.md`](screenshots/README.md)。步骤 9 of `docs/release-procedure.md` 是同一流程的简短版本。

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

| 指标 | 目标 | 实测 v1.0.0 |
|---|---|---|
| Cold start (windows, time to first frame) | < 500ms | Pending v1.0.0 manual measurement |
| Steady-state FPS（EPUB 5MB，连续滚动 30s） | ≥ 55 fps | Pending v1.0.0 manual measurement |
| 内存（idle，刚启动空库） | < 150MB | Pending v1.0.0 manual measurement |
| 内存（打开 100 页书后） | < 250MB | Pending v1.0.0 manual measurement |

> **Target 收紧说明**：原 §9.1–9.3 用的是 < 2000ms / ≥ 55fps / < 500MB（含 50MB PDF）。M1.6 plan §3.T15 把 cold start 收到 < 500ms、把内存拆成 idle / opened 两档（更细），PDF 50MB 那条保留在 §9.3 作为压力测试参考，不进 v1.0.0 release baseline。两个文档门限的差异是历史遗留，以本表为准；后续 release 视实测再回填。

### 9.5 为什么自动化测量被阻塞（必读）

子代理 / CI 目前**无法**自动跑 §9.1–9.3 三个场景并把数字写回本文件，原因有两条：

1. **中文路径阻断 release / profile build**。仓库根目录是 `H:\projiect\电子书阅读平台`，含 CJK 字符。Flutter Windows toolchain 在打包 `app.dill` 时把路径串过 GBK↔UTF-8 转码层，导致 mojibake、build 失败。M1.6 T14 已确认这影响 release build；profile build 走同一套 toolchain，假定同样阻塞。详见 §3 与 T14 记录。
2. **GUI 测量需要人**。FPS / 内存"打开书 + 滚动 30s + 等 steady state"要操作 reader UI、连 DevTools、手动 Take snapshot，这些步骤子代理无法驱动。

**结论**：performance baseline 是 **release-day 手动步骤**，由 release engineer 在每次 release（或重大重构后）按 §9.6 流程跑一次，把数字填进 §9.4 的表里。Methodology 必须能被任意 maintainer 重复——下面 §9.6 给出完整步骤。

### 9.6 手动测量流程（release-day checklist）

> 假设：测量者在本机 Windows 上有 Flutter SDK + Android Studio（DevTools 自带）。

#### Step 0：把项目复制到 ASCII 路径（绕开中文路径坑）

中文路径下 profile / release build 会失败（§9.5）。测量前先把仓库 copy 到纯 ASCII 路径。**只 copy 不 move**——原仓库继续作为工作目录。

```bash
# 假设原仓库在 H:\projiect\电子书阅读平台
# 目标 ASCII 路径：C:\dev\zhiyue-perf
mkdir -p /c/dev/zhiyue-perf
# 用 robocopy 比 cp -r 快很多（Windows）。/E 包含空目录，/MIR 镜像
robocopy "H:\projiect\电子书阅读平台" "C:\dev\zhiyue-perf" /E /MIR /XD .git build .dart_tool
cd /c/dev/zhiyue-perf/app
/c/flutter/bin/flutter.bat pub get
```

> **注意**：robocopy `/XD .git build .dart_tool` 排除了这三个目录——`.git` 不需要（只测量不 commit），`build` 和 `.dart_tool` 会被中文路径污染过，让 Flutter 重新生成。第一次 `pub get` 会触发 codegen（drift / riverpod），稍等。

#### Step 1：冷启动（cold start）

```bash
cd /c/dev/zhiyue-perf/app
/c/flutter/bin/flutter.bat run --trace-startup --profile -d windows
```

App 启动后**立即自动退出**（`--trace-startup` 的行为）。trace 写到 `build/windows/x64/runner/Debug/flutter_01.json`（路径可能随 Flutter 版本变；搜 `flutter_*.json` 即可）。

读 JSON：

- `engineEnterTimestampMicros` → 启动起点
- `timeToFrameworkSetupMicros` → framework 初始化完成
- **首帧**：找 `firstFrameRasterizedMicros`（或老版本里的 `timeToFirstFrameMicros`）
- **报告指标**：`firstFrameRasterizedMicros - engineEnterTimestampMicros`，单位 µs → 除以 1000 得 ms
- 目标：< 500ms。把数字填进 §9.4 表第一行。

> 重复 3 次取中位数，避免 SSD 冷缓存影响首次启动。第二次以后 Windows 会缓存 DLL，第三次数据最稳定。

#### Step 2：稳态 FPS（EPUB 滚动）

```bash
/c/flutter/bin/flutter.bat run --profile -d windows
```

App 启动后：

1. 打开 DevTools（IDE 里点 Flutter DevTools 按钮，或 `flutter pub global run devtools` 后浏览器打开）。
2. DevTools → **Performance** tab → 找 **"Show Performance Overlay"** 开关，打开。App 右上角出现 FPS + GPU 折线。
3. 在 app 里导入一本 ~5MB EPUB（用 `docs/superpowers/fixtures/` 或仓库自带样书），打开进入 reader。
4. 用鼠标滚轮连续滚动 30s（混合快慢，模拟真实阅读）。
5. 看 overlay 顶部的 **FPS** 数字（不是 GPU），取 30s 内**最低**值（jank 帧）。
6. 目标：≥ 55 fps。把数字填进 §9.4 表第二行。

> 如果没有现成 5MB EPUB，用任何一本中等篇幅的中文小说 EPUB 即可——目标是测稳态渲染，不是测特定书。记录用的什么书 + 大小，写进 release notes。

#### Step 3：内存（idle + 打开 100 页书）

继续 Step 2 的 profile session（不用重启）。

**3a. Idle 测量**：

1. DevTools → **Memory** tab。
2. 点 **"Resume"** 让 app 跑（如果 paused）。
3. 等 5 秒让启动 GC 完成，看左下 **"RSS"** 或 **"Total"** 数值（单位 KB 或 MB，看版本）。
4. 点 **"Take a snapshot"** 保留参考点。
5. 目标：< 150MB。填 §9.4 第三行。

**3b. 打开书后测量**：

6. 在 app 里导入并打开一本 ≥ 100 页的书（EPUB 或 PDF 都行，记录哪种 + 大小）。
7. 翻 10 页让渲染缓存填充。
8. 回 DevTools Memory tab，等 3 秒，记 RSS。
9. 目标：< 250MB。填 §9.4 第四行。

> **关于"100 页书"**：plan §3.T15 原文是 "100-page book"。EPUB 章节短可能不到 100 页，用 PDF 更容易（PDF 页数明确）。如果只有 EPUB，记 100 页约等于多少章节并说明。

#### Step 4：回填 §9.4 + release notes

1. 把上面三个数字填进 §9.4 表的 "Pending v1.0.0 manual measurement" 位置。
2. 如果任何一项**没达标**，必须在 release notes 显式说明（CHANGELOG.md + Gitee Release body），写清：实测值、目标值、可能原因、是否 block release。
3. commit 这份 runbook 改动：`docs(m1.6/perf): backfill v1.0.0 perf baseline measurements`。

### 9.7 何时复测

- **每个 minor / major release**（v1.0.0 → v1.1.0）：必测。
- **patch release**（v1.0.0 → v1.0.1）：不强制，除非 patch 触及渲染 / DB / 同步路径。
- **重大重构后**（如换渲染引擎、改 drift schema、重写 reader）：必测，即使没 release。
- **怀疑回归时**（用户报"变卡了"）：先测 cold start + FPS，再排查。

### 9.8 在 DevTools 里 toggle PerformanceOverlay（无需改代码）

代码里**没有**内建的 debug toggle（v1.0.0 决定不加，YAGNI——DevTools 已经能做）。如需在 app 内常驻 overlay：

1. 短期：用 §9.6 Step 2 描述的 DevTools **"Show Performance Overlay"** 开关。
2. 长期（如果未来要做 dev settings 页）：在 `MaterialApp` 上加 `showPerformanceOverlay: debugPerfOverlay`，把 `debugPerfOverlay` 放进 `SettingsService` 的 dev-only 段。这是后续 milestone 的事，不在 v1.0.0 范围。

---

## 10. M2.1 章节回顾 + 批量导出

### 10.1 BookReviewer 缓存命中规则

`ai_summaries` 表中 `mode='review'` 的行的 sourceHash 由两部分组成：

```
sourceHash = sha256( truncatedChapterText + '::' + highlightsSignature )
highlightsSignature = sha256( join( '\n', sort_by_createdAt( chapter_highlights.quote ) ) )
```

**与 AiGuide 的关键差异**：AiGuide 的 sourceHash 只 hash 章节文本，不包含用户状态——所以高亮变化也能命中旧缓存。BookReviewer 独立计算 hash 就是为了让"新增高亮 → 下次回顾强制 miss → 重新生成"成为默认行为。

**调试技巧**：用户报告"加了高亮但回顾没变"时：
1. 查 `ai_summaries` 表中 `mode='review'` 且 `book_id=X` 的行
2. 比对 `source_hash` 与代码实时算的 hash
3. 若一致但内容旧，说明 highlightsSignature 没正确包含新 quote（检查 `_loadChapterHighlights` 的过滤逻辑）

### 10.2 幂等保存前缀约定

`book_notes` 表中 AI 写入的内容有两个 sentinel：

| 字段 | AI 写入格式 | 用户手动内容特征 |
|---|---|---|
| `keyTakeaways` | `【第N章】 <内容>` | 不以 `【第N章】 ` 开头 |
| `summary` | `## 第 N 章 · <标题>` 起的段落 | 不以 `## 第 N 章` 开头 |

`NotesRepository.applyChapterReview` 实现"删旧加新"：
- 删除该章节前缀的旧条目 / 旧段落
- 追加新条目 / 新段落
- 保留所有不带前缀的内容（用户手动加的 takeaway、用户手动写的 summary 段落）

**幂等性**：同章重复回顾 N 次，最终 keyTakeaways 中该章节仍只有最新一批 AI 内容（不会累积）。

### 10.3 批量导出文件命名与覆盖

`VaultExporter` 写入路径：
```
<targetDir>/<sanitizeForFilename(book.title)> - 读书笔记.md
<targetDir>/index.md
```

**与单书导出 (`NoteFileWriter.saveMarkdownFile`) 的差异**：
- 单书导出：通过 `file_picker` 的 `saveFile` 走系统对话框，遇同名会提示用户
- 批量导出：直接 `File.writeAsString`，**同名强制覆盖**（保证 vault 状态一致性，避免半新半旧）

调试：用户报告"批量导出后旧笔记丢了"，确认是不是同名书覆盖（两本同名不同 ID 的书会互相覆盖）。

### 10.4 PDF 书不支持回顾

按 M4 Page-as-Chapter 设计，PDF 的"章"就是页——回顾单页意义不大。所以：
- TOC 抽屉：`engine is PdfReaderEngine ? null : _onOpenReview`，PDF 时 IconButton 不渲染
- 阅读器溢出菜单：`onOpenReview` 为 null 时 PopupMenuItem 不渲染

**注意**：批量导出对 PDF 仍然生效（只要有 book_notes 内容），因为 Markdown 导出基于 `book_notes` 表而非章节模型。

### 10.5 BatchExportDialog 测试时序坑

`BatchExportDialog._runExport` 在 `addPostFrameCallback` 中启动，调用 `VaultExporter.export` 走 `dart:io` 的 `File.writeAsString`。

在 `flutter_test` 中，`FakeAsync` zone 与真实 I/O 不兼容——`await` 永远不返回，导致：
- `onCompleted` 不被调用
- 临时文件被 tearDown 锁住（`PathException` errno 32）

**测试 setup 必须**：用 `tester.binding.runAsync(() async { await tester.pumpWidget(...); await tester.pump(); await Future.delayed(...); })` 把整个 mount + pump + I/O 链放在真实异步 zone 中。参考 `test/features/library/widgets/batch_export_dialog_test.dart`。

### 10.6 promptVersion bump 的影响

T3 把 `PromptBuilder.promptVersion` 从 1 改为 2。**现有缓存不会失效**，因为：
- 现有 ai_summaries 行的 `prompt_version=1`，`mode` 是 `full` / `chapter` / `selection`
- review 查询用 `mode='review'` + `prompt_version=2`，不会命中旧行
- 旧行的 `mode` 查询也不会要 `prompt_version=2`

只有当未来再次修改 prompt 时（bump 到 3），review 行才会失效——届时按本节逻辑再次 bump 即可。

---

## 11. Glossary

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

## 12. 相关文档

- 整体设计：`docs/superpowers/specs/2026-06-24-ebook-platform-design.md`
- Phase 2 路线图：`docs/superpowers/specs/2026-06-28-phase2-roadmap-design.md`
- M1.6 spec：`docs/superpowers/specs/2026-06-30-m1.6-polish-sweep-design.md`
- M1.6 plan：`docs/superpowers/plans/2026-06-30-m1.6-polish-sweep.md`
- M2.1 spec：`docs/superpowers/specs/2026-06-30-m2-1-chapter-review-batch-export-design.md`
- M2.1 plan：`docs/superpowers/plans/2026-06-30-m2-1-chapter-review-batch-export.md`
- 发布流程：`docs/release-procedure.md`
- Android SDK setup：`docs/setup-android-sdk.md`
- 最新 review：`docs/superpowers/reviews/`
- CHANGELOG：`CHANGELOG.md`
