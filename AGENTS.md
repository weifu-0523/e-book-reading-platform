# 项目指令 (AGENTS.md)

本文件用于指导 AI 助手在本项目中的行为。所有会话开始时自动加载。

---

## 联网搜索：主备切换约定

本平台配置了两套联网搜索能力，遵循"主搜索优先、限额不可用时切换备用"的规则。

### 搜索工具优先级

| 优先级 | 工具 | 触发条件 |
|--------|------|----------|
| **主搜索** | 内置 WebSearch / web_search 工具 | 默认使用 |
| **备用搜索** | Tavily MCP（`mcp__tavily__*`） | 仅在主搜索不可用时使用 |

### 切换规则（必须遵守）

执行联网搜索时，按以下顺序判断：

1. **优先使用主搜索**（内置 WebSearch / `web_search_prime`）。
2. **当出现以下任一情况**，判定主搜索"不可用"，立即切换到备用 Tavily MCP：
   - 主搜索返回额度/限额相关错误（如 `quota`、`rate limit`、`429`、`配额`、`限额`、`额度不足`、`unauthorized` 等）；
   - 主搜索连续报错或超时无结果；
   - 主搜索工具本身缺失或调用失败。
3. **使用 Tavily 时**：调用 `mcp__tavily__tavily-search`（或 Tavily 暴露的搜索类工具），不要假装搜索或编造结果。
4. 切换后在回复中简要说明一句，例如："（内置搜索暂不可用，已切换到备用 Tavily 搜索）"。

### 不要做的事

- ❌ 不要在主搜索正常时优先使用 Tavily（保留 Tavily 额度作为备用）。
- ❌ 不要在两个工具都失败时编造搜索结果——应如实告知用户当前联网搜索不可用。
- ❌ 不要把 Tavily 的 API Key 明文打印到回复中。

### Tavily 配置位置（参考）

- 配置文件：`~/.zcode/cli/config.json` → `mcp.servers.tavily`
- 连接方式：本地 `npx -y tavily-mcp@latest`（stdio）
- API Key 通过 `env.TAVILY_API_KEY` 注入，已内置，无需手动传入。
- 若 Tavily 自身也连接失败，检查 `/mcp` 状态并确认 Node.js / npx 可用。

---

## 开发环境（conda env: ebook）

本项目所有开发工作都在 conda 环境 **`ebook`** 中进行。激活该环境会自动配置 Flutter PATH、中国镜像、Android SDK 与 JDK。

### 激活方式

每次开始开发前：

```bash
conda activate ebook
```

激活后自动生效（由 `etc/conda/activate.d/zzz_ebook_flutter.{sh,bat}` 注入）：

| 变量 | 值 | 用途 |
|------|-----|------|
| `PATH` | 前置 `C:\flutter\bin` | runbook §3.3 PATH 未持久化问题的根治 |
| `FLUTTER_STORAGE_BASE_URL` | `https://storage.flutter-io.cn` | Flutter 引擎/产物中国镜像（runbook §2.3） |
| `PUB_HOSTED_PUB` | `https://pub.flutter-io.cn` | Dart 包中国镜像（runbook §2.3） |
| `ANDROID_HOME` / `ANDROID_SDK_ROOT` | `C:\Android\sdk` | Android SDK 34 所在 |
| `JAVA_HOME` | `$CONDA_PREFIX/Library/lib/jvm`（openjdk 17） | Gradle 构建所需 |

### 关键路径

- **Flutter SDK**：`C:\flutter`（Gitee 镜像 `gitee.com/mirrors/Flutter.git`，stable 频道）
- **Android SDK**：`C:\Android\sdk`（cmdline-tools 方案；已装 platform-tools + android-34 + build-tools 34.0.0）
- **conda 环境**：`C:\Users\Administrator\miniconda3\envs\ebook`

### Windows bash 注意（runbook §3.2）

- 用 `/c/flutter/bin/flutter.bat` 与 `/c/flutter/bin/dart.bat`，**不是** `.exe`。
- `conda activate ebook` 后 `flutter` / `dart` 已在 PATH，可直接调用（在 git-bash 中需 `flutter.bat` 全名）。
- 静态分析用 `dart analyze`，**不要**用 `flutter analyze`（中文路径 LSP 崩溃，runbook §3.1）。
- 测试用 `flutter test --concurrency=1`（drift native 库并发冲突，runbook §4.1）。

### Gradle 镜像（Android 构建用）

`maven.google.com` 在国内被墙，Gradle 拉 Android 依赖会超时。已配置 `~/.gradle/init.gradle`（runbook §2.3），把 Maven Central + Google 重定向到阿里云镜像：

```
~/.gradle/init.gradle → maven.aliyun.com/repository/{public,google,central}
```

`flutter build apk` 时 Gradle 自动走阿里云，无需额外操作。

### flutter doctor 最终状态

```
[√] Flutter (3.44.4, Dart 3.12.2, Gitee mirror)
[√] Windows Version (11 专业版 22H2)
[√] Android toolchain (SDK 36.0.0, JDK Zulu 17 via conda, all licenses accepted)
[√] Visual Studio (Build Tools 2022, Win SDK 10.0.26100)
[√] Connected device (Windows desktop)
[X] Chrome — 仅 web 开发需要，本项目不涉及，可忽略
[!] Network maven.google.com — 已通过 ~/.gradle/init.gradle 阿里云镜像解决
```

### 已装工具链清单

| 组件 | 版本 | 状态 |
|------|------|------|
| Flutter | 3.44.4 stable（Dart 3.12.2） | ✅ |
| Visual Studio Build Tools 2022 | MSVC 14.44 + Win SDK 10.0.26100 | ✅（Windows native build） |
| Android SDK | platform-tools 37 / android-34 + 36 / build-tools 34.0.0 + 36.0.0 | ✅ |
| JDK | Zulu OpenJDK 17（conda ebook 注入） | ✅ |
| Gradle 镜像 | `~/.gradle/init.gradle`（阿里云） | ✅ |
| Inno Setup 6 | 安装包已下载到 `~/Downloads/innosetup-6.7.3.exe` | ⚠️ 需手动双击安装（release 打包时才需要） |

---

## 文档纪律：superpowers 工作流（必须遵守）

本项目遵循 **superpowers** 方法论。所有里程碑（milestone）的实现都必须留下可追溯的三件套文档：**spec（设计）→ plan（实现计划）→ CHANGELOG（交付记录）**。三者缺一不可，且 spec 必须在 plan 之前产出。

### 文件结构与命名约定

```
docs/superpowers/
├── specs/    # 设计文档（plan 之前先写）
│   └── YYYY-MM-DD-<milestone>-<topic>-design.md
├── plans/    # 实现计划（按 spec 执行）
│   └── YYYY-MM-DD-<milestone>-<topic>.md
└── reviews/  # 里程碑评审（可选，重大里程碑写）
    └── YYYY-MM-DD-<milestone>-<phase>-review.md

CHANGELOG.md  # 交付记录（[Unreleased] 区段追加）
```

**命名规则**：
- spec 与 plan **同名**，仅 spec 多一个 `-design` 后缀（保证成对可检索）。
- `<milestone>` 用项目的 milestone 编号（如 `m2-6`、`m2.8`、`m3.2`），`<topic>` 简短英文 slug（如 `epub-dual-page`、`emergency-bug-fix`）。
- 示例（M2.8 + M2.9 合并冲刺）：
  - spec：`docs/superpowers/specs/2026-07-04-m2.8-bugfix-and-m2.9-dual-page-design.md`
  - plan：`docs/superpowers/plans/2026-07-04-m2.8-bugfix-and-m2.9-dual-page.md`
  - changelog：`CHANGELOG.md` 的 `[Unreleased]` 区段下 `### M2.8 — 2026-07-04` 条目

### 何时写哪份

| 阶段 | 产出 | 必填内容 |
|------|------|----------|
| **动手写代码前** | **spec** | Context（为什么做）、Goals、Non-Goals、根因分析（bug 类）或方案选型（feature 类）、Architecture Decisions（A1/A2…）、Risks、Success Criteria |
| **动手写代码前 / 过程中** | **plan** | Goal + Architecture + Pre-flight Checklist + File Structure + Task N（Files / Background / Steps `- [ ]` checkbox / Verification）。plan 是执行清单，spec 是设计依据 |
| **代码写完、测试通过后** | **CHANGELOG** | `[Unreleased]` 区段追加 `### <milestone> — YYYY-MM-DD` 条目，按 Keep a Changelog 格式（Added/Changed/Fixed/Removed + Lessons） |

**铁律**：
1. **spec 先于 plan**。没有 spec 不写 plan，没有 plan 不动代码。即便是 bug 修复，也要先在 spec 里记根因 + 三件套防御思路，再在 plan 里拆 Task。
2. **spec 与 plan 成对**。一份 spec 对应一份 plan（合并冲刺可一份 spec 配一份合并 plan，如本例 M2.8+M2.9）。
3. **plan 的 checkbox 反映真实进度**。已完成的 Step 标 `- [x]`，未完成标 `- [ ]`。不要伪造进度。
4. **CHANGELOG 倒序**。`[Unreleased]` 区段内，最新的 milestone 在最上面（紧接 `v1.5.1-alpha 之后的新变更将记在此处` 那行之后）。

### 不遵守纪律的后果

- ❌ 直接改代码不留 spec → 下次回归时无法追溯根因/方案选型依据，重复踩坑。
- ❌ 只有 plan 没有 spec → plan 沦为执行清单，丢失"为什么这么选"的决策上下文。
- ❌ 不写 CHANGELOG → release 时无法生成 release notes，用户不知道改了什么。

### 参考样板

- spec 范本：`docs/superpowers/specs/2026-07-04-m2.8-bugfix-and-m2.9-dual-page-design.md`（feature + bugfix 混合）、`docs/superpowers/specs/2026-07-03-m2-6-emergency-bug-fix-design.md`（纯 bugfix）
- plan 范本：`docs/superpowers/plans/2026-07-04-m2.8-bugfix-and-m2.9-dual-page.md`、`docs/superpowers/plans/2026-06-30-m1.6-polish-sweep.md`
- CHANGELOG 范本：`CHANGELOG.md` 的 `[Unreleased]` 区段 `### M2.8` / `### M2.9` 条目

### epub_view 包测试运行注意事项

`reader_engine_epub_view` 包的 `flutter pub get` 在中国镜像下会 hang（`flutter_widget_from_html` 依赖解析慢）。运行该包测试的 workaround：

1. 从 app 包（已解析 epub_view 作为 path dependency）拷贝 `.dart_tool/package_config.json` + `package_graph.json` + `version` + `flutter_build/` + `hooks_runner/`。
2. 重写 `package_config.json` 的 `rootUri`：原值相对于 app 的 `.dart_tool/`，需转成相对于 epub_view 的 `.dart_tool/`；并把 `reader_engine_epub_view` 自身条目的 `rootUri` 改为 `../`。
3. 运行：`flutter test --no-pub --concurrency=1 test/<file>`。

详见 `docs/superpowers/specs/2026-07-04-m2.8-bugfix-and-m2.9-dual-page-design.md` 的 "epub_view package test runner workaround"。

