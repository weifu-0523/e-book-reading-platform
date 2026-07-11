# 智阅 Mobile MVP Spiral 3 (S3) Design

> **状态**：draft（pending user review）
> **前置**：S2 部分交付（v1.9.0→v1.9.2-alpha hotfix chain，5 + 3 + 5 = 13 bug 修复）
> **目标 tag**：`v1.10.0-alpha` + `m-mobile-s3-complete`（双 tag）
> **桌面稳定锚点**：`desktop-stable-pre-mobile` —— 桌面 byte-for-byte 不变，sync 修复属「修 bug」不属「行为变更」

---

## 1. 目标与范围

### 1.0 术语

- **`isMobile`** = `Platform.isAndroid || Platform.isIOS`（与 reader_body.dart 现有 `_isDesktopPlatform` 反向一致）
- **`isDesktop`** = `!isMobile`（Windows / macOS / Linux）
- **firstPush** = 设备首次同步（远程没有 `/zhiyue/snapshots/<deviceId>.jsonl`）
- **ensureAncestors** = WebDavClient.mkcol 链式调用，逐段创建 `/zhiyue` → `/zhiyue/snapshots`
- **MKCOL 409** = jianguoyun 在 MKCOL 时返 409 AncestorsNotFound（与 RFC 4918 §9.3 偏差，本 spec 核心问题之一）

### 1.1 触发原因

v1.9.2-alpha 推送后用户报告 5 个 bug 全闭，但同时暴露两个深层信号：

1. **桌面 WebDAV「还没测通」**：错误 `WebDavException(409 at /zhiyue)` —— 这是 v1.9.2-alpha Bug 1 同类错误但**不同位置**：v1.9.2 修的是 GET `/zhiyue/snapshots/<id>.jsonl` 的 409（pushOnly 初始 GET），桌面新报的是 MKCOL `/zhiyue` 的 409（`ensureAncestors` 阶段）。**说明 v1.9.2-alpha 的修复不完整**，sync 链路上还有至少一个未 catch 的 409。
2. **桌面 + 移动 sync 路径需要统一审计**：用户原话「桌面端的 WebDAV 还没测通，需要和移动端合并解决云同步问题」—— sync engine 是单一代码路径（WebDavSyncEngine），桌面 bug 必然也是移动 bug，反之亦然。

加上 S2 Part 2 carry-over（5 plugin / IME / 全屏 / I1-I4）+ AI 流式优化 + TTS 探索，S3 整合为一个 ~35-45 tasks 的大 spiral。

### 1.2 S3 完整范围（5 work stream）

| WS | 主题 | 子项 | 工时（实现+测试） | 优先级 |
|---|---|---|---|---|
| **WS1** | WebDAV 跨端修复（P0） | mkcol 409 + ensureAncestors 验证 + setup 文档 | 1.5d | P0 |
| **WS2** | 移动 WebDAV 深度 | bg timer + 冲突 UI + pull UX | 2.0d | P1 |
| **WS3** | 清账 S2 Part 2 | 5 plugin + IME + 全屏 + I1-I4 | 2.5d | P1 |
| **WS4** | AI 流式渲染优化 | markdown 增量 + 自动滚动 + 中断重生 + stream 生命周期 | 2.0d | P1 |
| **WS5** | TTS 可行性调研 | research doc only，无代码 | 0.5d | P2 |
| **REL** | 发版 | pubspec/CHANGELOG/README/notes/tag/APK/installer | 0.5d | - |

**总工时约 9 天**（不含真机测试等待）。规模与 M2.7（32 tasks）相当，单 tag `v1.10.0-alpha`。

### 1.3 序列与并行

```
WS1 (P0, sync 修复) ─────────┐
                              ├─→ REL → v1.10.0-alpha
WS2 (移动 sync 深度) ─────────┤      (依赖 WS1 的 sync engine 稳定)
                              │
WS3 (清账 S2 Part 2) ─────────┤      (与 WS1/WS2 完全独立，可并行)
                              │
WS4 (AI 流式优化) ────────────┤      (与 sync 独立；与 WS3 IME 部分共享 AiInputComposer 焦点逻辑)
                              │
WS5 (TTS 调研) ───────────────┘      (research-only，无代码依赖)
```

- **WS1 必须先于 WS2 完成**：WS2 依赖 sync engine 稳定，否则 bg timer 等于在烂地基上盖房
- **WS3 / WS4 / WS5 与 WS1 并行**：互不依赖
- **WS4 与 WS3 的 IME 子项**有微弱耦合（AiInputComposer 焦点），先做 WS4 再做 WS3-IME 可避免冲突

### 1.4 范围外

- **iOS build / Mac CI**：推 S4+（用户无 macOS，scaffold-only 维持）
- **EPUB 双页渲染**（桌面 v1.6 遗留）：推后
- **桌面 deferred 功能移动对齐**（章节学习回顾 / Markdown 批量导出）：用户未提，推 S4+
- **手势导航 / 长按菜单 / 分享 sheet**：推 S4+
- **TTS 实现**：本 spiral 仅 research，实现推 S4+

---

## 2. WS1：WebDAV 跨端修复（P0）

### 2.1 现状（实证）

**已修**（v1.9.2-alpha Bug 1，commit `4757752`）：`pushOnly` 初始 GET 阶段 catch 404 + 409 → firstPush = true。

**未修**（v1.9.2-alpha 之后用户报告）：`ensureAncestors` → `mkcol('/zhiyue')` 阶段 409 → `mkcol` line 118 只接受 {201, 200, 405}，409 抛出 → 同步失败。

```dart
// web_dav_client.dart 现状（line 112-121）
Future<void> mkcol(String path) async {
  final request = http.Request('MKCOL', _uri(path))
    ..headers['authorization'] = _authHeader['authorization']!;
  final response = await _httpClient.send(request);
  final body = await response.stream.bytesToString();
  final status = response.statusCode;
  if (status != 201 && status != 200 && status != 405) {
    throw WebDavException(status, path, body);  // ← 409 在这里抛
  }
}
```

### 2.2 根因假设（systematic-debugging Phase 1）

| ID | 假设 | 验证手段 | 修复路径 |
|---|---|---|---|
| **H1** | jianguoyun app password 权限不含根目录写 | jianguoyun web UI 查 app password 权限范围 | setup-webdav.md 加「需在 web UI 预创建 /zhiyue 文件夹」段 |
| **H2** | jianguoyun MKCOL 行为偏差（父存在也返 409） | 实测：在已存在的 `/zhiyue` 上 MKCOL 看响应 | `mkcol` 增加 409 容忍 + PROPFIND 验证 |
| **H3** | baseUrl 中 username 段 URL 编码错误（特殊字符） | 日志：打印实际请求 URL | `_uri()` 加 `Uri.encodeComponent` |
| **H4** | jianguoyun 不允许 WebDAV MKCOL 创建根级目录，必须 web UI 创建 | jianguoyun 官方文档 + 实测 | setup-webdav.md + 「首次配置向导」 |

**预期**：H1 或 H4 是最可能的（解释为什么 jianguoyun 在 `/zhiyue` 这一级返 409）；H2 是次要可能；H3 最不可能（已有用户能用其他 WebDAV 客户端访问）。

### 2.3 修复设计（defense in depth）

不论根因是哪个，下列修复链路都对：

#### Fix A：`mkcol` 增加 409 容忍 + PROPFIND 验证

```dart
// web_dav_client.dart 新版 mkcol
///
/// Status code semantics:
/// - 201 Created: directory created
/// - 200 OK: rare
/// - 405 Method Not Allowed: directory already exists (RFC 4918 §9.3)
/// - 409 Conflict: jianguoyun deviation — may mean "already exists" OR
///   "parent missing". Disambiguate via PROPFIND on the same path:
///   - PROPFIND 207 → directory actually exists, MKCOL was spurious → OK
///   - PROPFIND non-207 → truly missing → rethrow original 409
Future<void> mkcol(String path) async {
  final request = http.Request('MKCOL', _uri(path))
    ..headers['authorization'] = _authHeader['authorization']!;
  final response = await _httpClient.send(request);
  final body = await response.stream.bytesToString();
  final status = response.statusCode;
  if (status == 201 || status == 200 || status == 405) return;
  if (status == 409) {
    // Disambiguate.
    try {
      await listFiles(path);
      return; // PROPFIND succeeded → dir actually exists
    } on WebDavException {
      throw WebDavException(status, path, body); // truly missing
    }
  }
  throw WebDavException(status, path, body);
}
```

**为什么这样设计**：
- 不需要先确定 H1/H2/H4 哪个对，PROPFIND 验证统一覆盖
- 即使根因是 H4（必须 web UI 创建），用户 web UI 创建后 MKCOL 返 405 → 走"已存在"分支
- 即使根因是 H2（偏差），PROPFIND 也能验证存在性
- 不会破坏 RFC-compliant 服务器（Nextcloud / ownCloud）：它们本就返 405

#### Fix B：`ensureAncestors` 加日志和降级

`ensureAncestors` 在 mkcol 抛 WebDavException 时记录每个段的 status + body，便于 production 调试。

#### Fix C：setup 文档「首次配置」段

`docs/setup-webdav.md` 加：

> **jianguoyun 首次配置**：登录 jianguoyun 网页版，手动在「我的资料」根目录下创建名为 `zhiyue` 的文件夹（全小写）。首次同步时智阅会自动在该文件夹下创建 `snapshots/` 子目录。若不创建，sync 会报 `WebDavException(409 at /zhiyue): AncestorsNotFound`。

### 2.4 测试设计

新增测试（`web_dav_client_test.dart` + `web_dav_sync_engine_test.dart`）：

| Test | 覆盖 |
|---|---|
| `mkcol returns normally on 201/200/405` | 现有行为不变 |
| `mkcol swallows 409 if PROPFIND verifies existence` | H2 修复 |
| `mkcol rethrows 409 if PROPFIND 404` | 真正缺失不掩盖 |
| `mkcol on 500/401/403 still throws` | 其他错误不被静音 |
| `ensureAncestors logs each segment status on failure` | 调试可见性 |
| Integration: full pushOnly on fresh jianguoyun-shaped mock | 端到端：GET 409 → firstPush → mkcol /zhiyue 409 → PROPFIND OK → mkcol /zhiyue/snapshots 201 → PUT 201 → success |

### 2.5 真机验证（用户）

桌面：清空 jianguoyun 测试账号的 `/zhiyue` 目录 → 配置 sync → 同步应成功（不论 `/zhiyue` 是否预先存在）。

移动：同样路径验证。

---

## 3. WS2：移动 WebDAV 深度

### 3.1 子项

#### WS2-A：Background sync timer（mobile lifecycle 感知）

**现状**：桌面 background timer 已实现（M2.0b），`SyncCoordinator.startPeriodicSync(Duration(minutes: 5))`。移动端目前**不启动** timer（按 kickoff memory「WebDAV sync 推到 S3」）。

**S3 范围**：移动端启用 background timer，但加 lifecycle 适配：

```dart
// 新文件：app/lib/services/sync/mobile_lifecycle_sync_controller.dart
class MobileLifecycleSyncController {
  MobileLifecycleSyncController(this._coordinator, this._lifecycle);
  final SyncCoordinator _coordinator;
  final AppLifecycleAdapter _lifecycle;  // 抽象，便于测试

  StreamSubscription<AppLifecycleState>? _sub;
  Timer? _timer;

  void start({Duration interval = const Duration(minutes: 15)}) {
    _timer = Timer.periodic(interval, (_) => _coordinator.syncNow());
    _sub = _lifecycle.state.listen((s) {
      if (s == AppLifecycleState.resumed) {
        _coordinator.syncNow();  // 即时同步
      } else if (s == AppLifecycleState.paused) {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
  }
}

abstract class AppLifecycleAdapter {
  Stream<AppLifecycleState> get state;
}
```

**默认间隔**：移动 15 分钟（桌面 5 分钟，battery 友好）。

**lifecycle 行为**：
- `resumed`：重启 timer + 立即 sync 一次
- `paused`：取消 timer（不消耗电池）
- `detached` / `inactive`：忽略（短暂状态）
- **不**在 `paused` 状态触发 sync（系统会 kill）

#### WS2-B：冲突解决移动 UI

**现状**：conflict log 表存在（M2.0b），桌面 NotesPage 有 conflict 入口。

**S3 范围**：移动端 Settings drawer 加「同步冲突」入口，复用 `ConflictLogPage`（已有），加 mobile compact 布局：

- 列表项：`[timestamp] [entity type]  local: "... foo"  remote: "... bar"`
- 单条 action：`[Keep Local] [Keep Remote] [Ignore]`
- 不重写 ConflictLogPage，只加 `LayoutBuilder` 紧凑分支

#### WS2-C：Pull UX

**现状**：sync 按钮 press → 无视觉反馈 → success/fail Snackbar。

**S3 范围**：
- 同步进行时：sync icon 转（`RotationTransition` + `AnimatedBuilder`）
- 同步失败：Snackbar 含「重试」按钮
- 同步成功：无 notification（不打扰）
- 同步进行时禁用 sync 按钮（防 re-entry，参考 M2.0b review fixup）

文件：`app/lib/features/sync/widgets/sync_button.dart`（新建，从 settings 内联抽出）

### 3.2 测试设计

| Test | 覆盖 |
|---|---|
| `MobileLifecycleSyncController.start begins timer` | 基础启动 |
| `paused cancels timer; resumed restarts + immediate sync` | lifecycle 适配 |
| `dispose cancels both timer and sub` | 无 leak |
| `ConflictLogPage compact branch matches golden` | 移动布局 |
| `SyncButton shows rotation while syncing` | 视觉反馈 |
| `SyncButton disabled while syncing` | re-entry 防御 |
| `SyncButton retry SnackBar on failure` | 错误恢复 |

### 3.3 桌面行为不变

- 桌面 background timer 间隔仍 5 分钟
- 桌面 ConflictLogPage 布局不变（仅移动加 compact 分支）
- 桌面 sync 按钮无旋转动画（桌面用户期望静态 icon）—— 通过 `PlatformInfo.isMobile` 守卫

---

## 4. WS3：清账 S2 Part 2

### 4.1 子项

#### WS3-A：5 plugin 升级 + 移除 sed 补丁

| Plugin | 当前 | 目标 | breaking |
|---|---|---|---|
| `connectivity_plus` | 6.1.5 | latest stable（>= 6.2，默认 compileSdk 36） | API 检查 |
| `file_picker` | 8.3.7 | latest stable（>= 8.3.x，compileSdk 36） | API 检查 |
| `flutter_secure_storage` | 9.2.4 | latest stable | API 检查 |
| `just_audio` | 0.9.46 | latest stable（>= 0.10.x） | breaking media API |
| `webview_flutter_android` | 3.16.9 | latest stable | API 检查 |

**验证**：移除 `scripts/patch-pub-cache.sh`（如有）+ setup-android-sdk.md 中 sed 段 → `flutter pub get` → `flutter build apk --release` 成功。

**风险**：just_audio 0.10 有 breaking change，需 audit 全部 audio 调用点（当前仅 TTS placeholder？实际未用？）。

#### WS3-B：IME 深度适配

**现状**：S2 Part 1 修了 AiInputComposer 基础避让，但未真测中文输入法。

**S3 范围**：
- 真机测 GBoard 中文拼音 + 搜狗输入法
- 验证 `MediaQuery.viewInsets.bottom` 在 keyboard show/hide/rotate 时正确
- 验证 `Scaffold.resizeToAvoidBottomInset` 全 codebase（reader/library/notes/settings/sync）一致
- Focus 丢失场景：旋转屏 / 切应用 / dismiss keyboard → input 是否保持

**预期改动**：可能需要给 `AiInputComposer` 加 `FocusNode` 自动 retain，或者给 reader Scaffold 加 `resizeToAvoidBottomInset: true` 显式声明。

#### WS3-C：全屏安全区

**现状**：Bug 4 修了 drawer SafeArea，但 fullscreen 模式下 `SystemUiMode.immersive` 与 `SafeArea` 交互未充分验证。

**S3 范围**：
- 验证：reader 进入 fullscreen → status bar hide → content 是否覆盖原 status bar 区
- 验证：landscape 模式下 notch / 灵动岛 边距
- 验证：tap-to-toggle chrome 在 fullscreen 下正确定位（不重叠 status bar 残影）
- 必要时加 `SafeArea(bottom: true)` 给 reader 底部 chrome

#### WS3-D：I1-I4 review 残留

| ID | 问题 | 修法 |
|---|---|---|
| **I1** | `ReaderUiState` 无 `==` / `hashCode`，Riverpod 频繁 rebuild | 加 `==` + `hashCode`（Dart records 或 freezed） |
| **I2** | `PlatformInfo.isMobile` 与 `defaultTargetPlatform` 不一致（test 用 override） | 全 codebase audit：用 `PlatformInfo.isMobile` 替换 raw `defaultTargetPlatform` |
| **I3** | desktop + null-persisted typography 触发冗余 `setTypography` | `TypographyPersister` 加「未变化则跳过」guard |
| **I4** | auto-hide chrome timer 不重启（每次 toggle 都该 reset 3s） | `_showChrome()` 内 `Timer.cancel()` + 重启 |

### 4.2 测试设计

| Test | 覆盖 |
|---|---|
| `ReaderUiState equality + hashCode contract` | I1 |
| `TypographyPersister skips redundant setTypography` | I3 |
| `AutoHideChromeTimer resets on each chrome show` | I4 |
| `apk build succeeds without sed patches` | WS3-A 验证 |
| Integration: AiInputComposer focus retained across rotate | WS3-B |

---

## 5. WS4：AI 流式渲染优化

### 5.1 子项

#### WS4-A：Markdown 增量渲染稳定性

**现状**：每 SSE token → `MarkdownBody` 重建 → 中途状态的代码块 / 列表 / 表格会"跌"（reflow）。

**修法**（Option B：双阶段渲染，最小代价）：

```dart
// ai_chat_message.dart 新结构
class AiChatMessage extends StatelessWidget {
  final String text;
  final bool isStreaming;  // ← 关键

  @override
  Widget build(BuildContext context) {
    if (isStreaming) {
      // 流中：纯 SelectableText，避免 markdown reflow
      return SelectableText(text);
    }
    // 流结束：切 MarkdownBody
    return MarkdownBody(data: text);
  }
}
```

**触发切换**：stream done（subscription done callback）→ setState(isStreaming = false) → MarkdownBody 渲染。

**用户感知**：流期间文本「裸奔」但稳定；流结束瞬间切精美 markdown。

**风险**：长响应（5K+ tokens）流期间无 markdown 视觉提示，可能不直观 → 评估后若不满，推 WS4-A.2 升级为增量 markdown renderer（自研或选 `gpt_markdown`）。

#### WS4-B：聊天列表自动滚动

**现状**：每 token 到达 → `ScrollController.jumpTo(maxScrollExtent)`，打断用户向上滚动阅读历史。

**修法**：

```dart
// ai_drawer_widget.dart
final _scrollController = ScrollController();
bool _userScrolledUp = false;
bool _isAtBottom = true;

@override
void initState() {
  super.initState();
  _scrollController.addListener(() {
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    _isAtBottom = (max - current).abs() < 64;  // 64px tolerance
    _userScrolledUp = current < max - 64;
  });
}

void _onNewToken() {
  if (_isAtBottom) {
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }
  // else: user is reading history, don't auto-scroll
}
```

**user-scroll detection**：用 `_scrollController.position.userScrollDirection != ScrollDirection.idle` 区分程序触发 vs 用户触发（更精确，但需要 `ScrollNotification` 监听）。先用 64px tolerance 简化版。

#### WS4-C：中断与重生

**现状**：SSE 流期间无 cancel button；AI 消息无 regenerate 入口。

**修法**：

```dart
// AiInputComposer 内
// 当 streaming == true 时，send button 变 stop icon
IconButton(
  icon: streaming ? Icon(Icons.stop) : Icon(Icons.send),
  onPressed: streaming ? _cancelStream : _sendMessage,
)

// _cancelStream:
_cancelStream() {
  _currentSubscription?.cancel();
  ref.read(chatStreamProvider.notifier).markCancelled();
}
```

重生：长按 AI message → PopupMenu → "Regenerate" → 用同一 prompt + 历史（去掉被 regenerate 的回答）重新发。

#### WS4-D：stream 生命周期与并发

**现状**：AiDrawerWidget dispose 是否 cancel subscription？需 audit。

**修法**：
- dispose 时 cancel 当前 SSE subscription（防 leak + 防 zombie 写入数据库）
- 后台 sync pull + 前台 AI stream 并发：drift 默认 `PRAGMA foreign_keys = ON` + WAL mode，应该不互锁。加测试验证。

### 5.2 测试设计

| Test | 覆盖 |
|---|---|
| `AiChatMessage shows plain text while streaming` | WS4-A |
| `AiChatMessage switches to MarkdownBody on stream done` | WS4-A |
| `Auto-scroll locks when user scrolls up` | WS4-B |
| `Auto-scroll resumes when user scrolls back to bottom` | WS4-B |
| `Cancel button stops SSE subscription` | WS4-C |
| `Regenerate re-issues same prompt` | WS4-C |
| `AiDrawerWidget dispose cancels SSE` | WS4-D |
| `Concurrent sync + AI stream no deadlock` | WS4-D integration |

---

## 6. WS5：TTS 可行性调研（research-only）

### 6.1 输出

**唯一交付物**：`docs/superpowers/research/2026-07-11-tts-feasibility.md`。

**无代码改动**、无测试、无 release notes 段（或仅一行链接到调研文档）。

### 6.2 调研大纲

1. **plugin 选型对比**
   - `flutter_tts`：cross-platform wrapper，依赖 Android TextToSpeech engine / iOS AVSpeechSynthesizer / Windows SAPI
   - 平台原生（Android `TextToSpeech` / Windows `System.Speech.Synthesis`）通过 platform channel
   - 评估：API 完整度 / 引擎依赖 / 中文支持 / 后台播放 / 锁屏控制
2. **使用场景对比**
   - EPUB 章节朗读：需从 EPUB 渲染管线提取 plain text（与现有 `EpubxRenderer.chapterText` 兼容？）+ locator mapping（朗读到哪 ↔ EPUB locator）
   - AI 响应朗读：字符串已有，直接喂 TTS
3. **高亮跟随**：TTS progress callback ↔ EPUB locator 映射可行性
4. **后台播放 + 锁屏控制**：与 `just_audio` + `audio_service` 整合代价
5. **平台限制**
   - Android：用户需预装 TTS engine（多数手机默认有，但中文质量参差）
   - Windows：System.Speech 中文 voice 需手动安装
   - iOS：基础 voice OK，中文 premium 需下载
6. **S4 实现推荐路径**
   - Phase 1：AI 响应朗读（简单，先验证 UX）
   - Phase 2：EPUB 章节朗读（需 locator mapping）
   - Phase 3：高亮跟随 + 后台播放

### 6.3 验收

文档存在 + 含上述 6 段 + 用户 review 后认为可指导 S4 决策。

---

## 7. 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| **R1**：WS1 根因不是 H1/H2/H4，是更深层 jianguoyun 偏差 | 低 | 中 | defense in depth（PROPFIND 验证）覆盖多种偏差；如仍失败，escalate 到「WebDAV via curl」手动复现 |
| **R2**：WS3-A plugin 升级 breaking change 超 1.5d 工时 | 中 | 中 | 先升 just_audio（最可能 breaking），无问题再升其他；如卡住，可保留 sed 补丁延后到 S4 |
| **R3**：WS4-A 双阶段渲染 UX 不被用户接受（流期间"裸奔"难看） | 中 | 低 | 留 WS4-A.2 升级路径（增量 markdown renderer）；S4 候选 |
| **R4**：WS2-A mobile lifecycle 在 detached 状态导致数据损坏 | 低 | 高 | 不在 detached 触发 sync；paused 也只 cancel 不触发；只有 resumed 触发 |
| **R5**：jianguoyun 在 PROPFIND 上也返 409（即 mkcol+propfind 双失败） | 低 | 高 | setup 文档强制 web UI 预创建 + 首次启动检测 409 → 弹「请先在 jianguoyun 创建 /zhiyue 文件夹」对话框 |
| **R6**：规模超 45 tasks，无法单 spiral 完成 | 中 | 中 | writing-plans 阶段进一步拆分；最坏情况 WS5 推后 |

---

## 8. 测试策略汇总

### 8.1 单元 / widget 测试

按 WS 分布：
- WS1：~6 tests（mkcol 409 disambiguation + ensureAncestors log + integration）
- WS2：~7 tests（lifecycle + conflict UI + sync button）
- WS3：~5 tests（ReaderUiState eq + typography skip + auto-hide reset + IME focus retained + 无 sed build）
- WS4：~8 tests（markdown switch + scroll lock + cancel + regenerate + dispose + concurrency）
- WS5：0 tests

新增总计：~26 tests（与 M2.7 的 30 接近）。

### 8.2 真机验证（用户）

| 场景 | 步骤 | 预期 |
|---|---|---|
| **jianguoyun first sync**（桌面 + 移动） | 清空 jianguoyun 测试账号 `/zhiyue` → 配置 sync → 按 sync 按钮 | 不报 409；同步成功 |
| **MKCOL on existing dir**（桌面） | 已有 `/zhiyue` → 重新 sync | 不报 409 |
| **Mobile background sync**（移动） | 阅读 15 分钟（不操作） | 后台触发 1 次 sync（看 Snackbar 或 Settings「上次同步」时间） |
| **Mobile lifecycle**（移动） | 阅读中切到其他 app 5 分钟再回 | resumed 立即触发 sync |
| **冲突解决**（移动） | 桌面 + 移动改同一条 highlight → 同步 | 移动 Settings「同步冲突」可见条目；可 keep local/remote |
| **Markdown 流稳定性**（移动） | 长篇 AI 响应（5K+ tokens） | 流期间不闪烁；流结束瞬间切 markdown |
| **Auto-scroll lock**（移动） | AI 响应中向上滚 | 不被打回到底；新消息到达不抢 |
| **Cancel + Regenerate**（移动） | 流期间按 stop；长按 AI 消息选 Regenerate | 流停；同一 prompt 重新流 |
| **IME 中文输入**（移动） | GBoard 拼音输入长问题 | 不丢字、不 focus 丢失、keyboard 避让正确 |

### 8.3 桌面 baseline 验证

跑 `flutter test` 全量 + 桌面 release build smoke。预期：
- 测试通过数 ~1293（v1.9.2-alpha 的 ~1267 + ~26 新增）
- pre-existing baseline 失败维持 10 个（router_test 1 / library_golden 2 / reader_page_test 4 / reader_flow_integration timeout 1 / reader_page_pdf_integration load 1 / reader_ai_drawer_integration load 1）
- 桌面 release build 成功

---

## 9. 发版

### 9.1 双 tag

```
m-mobile-s3-complete
v1.10.0-alpha
```

### 9.2 Artifacts

- `zhiyue-setup-1.10.0-alpha.exe`（Windows，Inno Setup）
- `zhiyue-1.10.0-alpha.apk`（Android release，单 APK 不拆 ABI）

构建路径：`C:\zhiyue_build_s3\app`（绕中文路径）。

### 9.3 文档更新

- `pubspec.yaml`：version → 1.10.0-alpha
- `app/windows/installer/zhiyue.iss`：MyAppVersion → 1.10.0-alpha
- `CHANGELOG.md`：[1.10.0-alpha] 段，列 5 WS 全部交付
- `README.md`：版本徽章 + v1.10.0-alpha entry + 测试数更新
- `docs/releases/release-notes-v1.10.0-alpha.md`：完整 release notes
- `docs/setup-webdav.md`：加「jianguoyun 首次配置」段（WS1 Fix C）

### 9.4 Gitee 推送

按 [[project_gitee_workflow]] 规则，commit 一律推 Gitee。tag 也推。Release 上传按用户「完善后」时机。

---

## 10. 验收清单

- [ ] WS1：jianguoyun first sync 桌面 + 移动均成功（用户真机验证）
- [ ] WS1：6 个新测试全过
- [ ] WS2：mobile background sync 真机验证 15 分钟周期
- [ ] WS2：conflict UI 真机验证
- [ ] WS2：sync button 旋转 + 重试
- [ ] WS3：5 plugin 升级后 APK build 成功无 sed 补丁
- [ ] WS3：IME 真机测试中文输入无丢字
- [ ] WS3：fullscreen 安全区真机验证
- [ ] WS3：I1-I4 全部修
- [ ] WS4：长 AI 响应流期间不闪烁（真机或 widget test）
- [ ] WS4：auto-scroll lock + unlock 正确
- [ ] WS4：cancel + regenerate 真机验证
- [ ] WS4：dispose 后 SSE 无 leak（widget test）
- [ ] WS5：调研文档存在 + 6 段齐全
- [ ] 双 tag 推 Gitee
- [ ] 桌面 baseline 测试 0 新增失败
- [ ] CHANGELOG / README / release-notes 完整
- [ ] Windows installer + Android APK 构建并验证签名

---

## 11. 关联

- 前序：[[project_zhiyue_2026_07_11_bug_batch_4_complete]]（v1.9.2-alpha，S3 sync 修复的 bug 来源）
- 前序：[[project_zhiyue_mobile_mvp_s1_complete]] + [[project_zhiyue_m2_s2_part1_complete]]（S1 + S2 Part 1，carry-over 来源）
- 前序：[[project_zhiyue_mobile_mvp_s1_review_fixups]]（I1-I4 来源 + reader_body widget 盲区来源）
- 设计参考：[[project_zhiyue_m2_0b_complete]]（M2.0b sync 引入）+ [[project_zhiyue_m2_0a_complete]]（M2.0a sync MVP）
- 约束：[[feedback_no_dispose_time_fire_and_forget]]（WS2-A lifecycle 必须即时落盘）+ [[project_zhiyue_dev_env_quirks]]（构建路径）+ [[project_gitee_workflow]]（推送规则）
- 后续：S4（iOS Mac CI + TTS 实现 + 桌面 deferred 功能移动对齐 + WS4-A.2 增量 markdown renderer 候选）
