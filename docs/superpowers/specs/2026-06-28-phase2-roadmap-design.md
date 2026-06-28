# 智阅 Phase 2 路线 Design Doc

**日期**：2026-06-28
**作者**：wf + Claude（brainstorming session）
**前置**：Phase 1 (M0-M8) 完成，v0.5.0 已 tag，579 tests + 2 skip，详见 `project_zhiyue_m8_complete.md` memory
**目标读者**：phase 2 期间的执行者（主要是 subagent）+ 未来的维护者

---

## 1. 目标

Phase 2 在 phase 1（单设备 v0.5.0）的基础上，交付**多端 v1.0**：AI 导读 + 同步 + 全方位 polish。

**完成态**（双轨）：
- AI 导读（中等深度）：摘要 + 章节导读 + 高亮点评 + 同书问答（带引用），跨书 AI 伴读预留 UI 占位（phase 3+）
- v1.0 polish：防御型（旧债）+ UX 打磨 + 性能优化

**Phase 3 入口**：见 §6。

---

## 2. 执行策略：螺旋式 MVP + 迭代

3 个 milestone（M2.0 Sync / M1.5 AI / M1.6 Polish）切成 6 个螺旋顺序交付：

```
Phase 1 (DONE, v0.5.0)
  │
  ▼
Spiral 1: M2.0a Sync MVP                  → v0.6.0-alpha
Spiral 2: M1.5a AI MVP                    → v0.6.0
Spiral 3: M2.0b Sync 双向 + 冲突           → v0.6.1
Spiral 4: M1.5b AI 章节 + 点评             → v0.7.0
Spiral 5: M1.5c AI 同书问答 + 引用         → v0.7.1
Spiral 6: M1.6 Polish sweep → v1.0        → v1.0.0
  │
  ▼
Phase 3: Android APK + 跨书 AI + (可能的) iOS
```

**为什么螺旋而非大块垂直切片**：
- Phase 1 review 暴露结构性风险（reader_page.dart 628 行、Windows native 无 smoke test），小切片更易暴露集成问题
- 每 1-2 周一个 shippable，节奏匹配既有 dev velocity
- Polish 放最后，避免被新 feature 弄脏

**为什么 Sync 在 AI 前**：
- AI 元数据（生成的摘要/点评）需要 sync 才能多端
- Sync Repository 抽象在 phase 1 已设计，风险最低，先验证

---

## 3. Spiral 详图

### Spiral 1 — M2.0a Sync MVP (→ v0.6.0-alpha)

**范围**：
- 抽象 sync engine + 坚果云 WebDAV adapter
- 单向 push（设备 → 云），覆盖高亮/笔记/进度/书签
- last-write-wins per record（按 mtime），无交互式冲突解决
- outbox 持久化（断网暂存）

**新增文件**：
- `app/lib/services/sync/sync_engine.dart`
- `app/lib/services/sync/webdav_client.dart`
- `app/lib/services/sync/repository_sync.dart`
- `app/lib/models/sync/sync_record.dart`
- `app/test/services/sync/*`

**数据流**：
```
Repository.save(highlight)
  → 同时写 local DB（既有）+ outbox 表（新）
  → SyncEngine.flush()
  → WebDavClient.push(/zhiyue/snapshots/<device_id>.jsonl)
  → 设备 B 启动时 SyncEngine.pull() → diff → 应用到本地 DB
```

**关键决策**：
- **payload 格式**：JSON Lines（每行一条 record），支持增量 append
- **WebDAV 路径**：`/zhiyue/snapshots/{device_id}.jsonl`（per-device file，避免多端写同一文件）
- **认证**：坚果云"应用密码"（不是用户主密码），存 `flutter_secure_storage`
- **冲突策略 v1**：last-write-wins per record（按 `mtime`），不做 merge

**验收**：在设备 A 改高亮 → push → 设备 B pull → 看到，无数据丢失。

---

### Spiral 2 — M1.5a AI MVP (→ v0.6.0)

**范围**：
- DeepSeek client（BYOK）
- Settings 页 API key 入口 + 加密存储
- 全书摘要（一次性，300 字，按章节拼接 prompt）
- "AI 导读" 入口（Library 长按 + Reader 菜单）

**新增文件**：
- `app/lib/services/ai/deepseek_client.dart`
- `app/lib/services/ai/api_key_store.dart`
- `app/lib/services/ai/summarizer.dart`
- `app/lib/ui/widgets/ai_summary_sheet.dart`
- `app/lib/ui/pages/settings/api_key_page.dart`

**数据流**：
```
用户点 "AI 导读"
  → ApiKeyStore.get()
    → 无 key：弹 Settings 引导
    → 有 key：Summarizer.run(book)
      → 取 book 全文（drm_free 已解压）
      → 截断到 8K token（首中尾各 1/3）
      → 拼 prompt："请用 300 字总结这本书的核心论点..."
      → DeepSeekClient.chat(prompt) → 流式接收
      → 显示在 bottom sheet（可复制/导出 Markdown）
```

**关键决策**：
- **token 截断**：超过 8K 时取首 + 中 + 尾各 1/3
- **加密存储**：`flutter_secure_storage`（Android Keystore / Windows DPAPI）
- **错误 UX**：401（key 错）→ 跳 Settings；429（限流）→ "稍后再试"；网络 → 重试 3 次
- **跨书 AI 伴读占位**：Settings 页一个 disabled 入口 "跨书 AI 伴读（即将推出）"，不动核心架构

**验收**：用户填 key → 任意书 → 一键生成摘要。

---

### Spiral 3 — M2.0b Sync 双向 + 冲突 (→ v0.6.1)

**范围**：
- 双向 pull/push
- 冲突策略：last-write-wins per record + 用户可见冲突日志
- 后台定时同步 + 手动触发
- 离线队列持久化

**改动**：
- `sync_engine.dart` 增 `pullAndMerge()` 方法
- 新增 `app/lib/services/sync/conflict_resolver.dart`
- 新增 `app/lib/ui/pages/sync/sync_status_page.dart`
- outbox 持久化（sqflite）

**冲突日志格式**：
```json
{
  "record_id": "...",
  "type": "highlight",
  "winner_device": "A",
  "loser_device": "B",
  "timestamp": "...",
  "diff": "..."
}
```
用户可在 sync_status_page 看到，**不交互式解决**（v1 简化）。

**验收**：A B 同时改同一高亮 → 不丢数据 + 冲突 UI 可见。

---

### Spiral 4 — M1.5b AI 章节 + 点评 (→ v0.7.0)

**范围**：
- 章节导读（每章 1-2 句，批量预处理缓存）
- 高亮选中 → "AI 点评"（流式输出）
- 成本估算 UI（每次调用前显示 token 估算）

**改动**：
- `summarizer.dart` 增 `summarizeChapter(chapter)`
- 新增 `app/lib/services/ai/highlight_commenter.dart`
- 章节导读批量预处理：导入书时后台生成所有章节摘要，缓存在 sqflite
- 成本估算：调用前 `TokenEstimator.estimate(prompt)` 显示 "约 0.001 元"

**验收**：章节 drawer 显示导读；选中文字出 AI 点评；调用前看到成本估算。

---

### Spiral 5 — M1.5c AI 同书问答 + 引用 (→ v0.7.1)

**范围**：
- 同书内 FTS5 检索 → 拼 context → DeepSeek
- 回答带页码/章节引用（点击跳转）
- 历史 Q&A 列表（per-book）
- 跨书 AI 伴读 UI 占位（disabled menu，标 "phase 3+"）

**改动**：
- 新增 `app/lib/services/ai/book_qa.dart`
- 流程：用户问 → FTS5 检索本书 → top-K 段落 → 拼 context → DeepSeek
- 引用：每段 context 带 `[ch=N, p=M]` 标记，模型回答里要求保留 → 解析回跳转
- 历史：`qa_history` 表（per-book）

**验收**：问 "这本书怎么定义 X" → 带引用回答；点击引用可跳转。

---

### Spiral 6 — M1.6 Polish sweep → v1.0 (→ v1.0.0)

**子任务**（每项独立可并行）：
- 拆 `reader_page.dart` 628 行 → `reader_page.dart` + `reader_controller.dart` + `reader_presenter.dart` + `reader_shortcuts.dart`（目标 ≤300 行/文件）
- Windows native smoke test：C++ 单元测试覆盖 main.cpp 的 Mutex/EnumWindows + flutter_window.cpp 的 WM_COPYDATA 路径
- 3 张 deferred 截图（library / pdf_reader / notes）
- `docs/maintainers-runbook.md`：从 memory 文件沉淀（中文路径、镜像、签名、release 流程、常见 bug 修复）
- UX 统一：loading/empty/error states 全覆盖（清单：library / reader / notes / search / settings）
- Perf：冷启动 < 2s；5MB EPUB 60fps 滚动；PDF 大文件内存峰值

**验收**：
- 所有 spiral 回归测试通过
- profile 报告达标
- maintainer's runbook 能让另一个 Claude 实例从零接手

---

## 4. 风险清单

### 高优（spiral 启动前必须有 mitigation）

| # | 风险 | 等级 | 影响螺旋 | 缓解 |
|---|---|---|---|---|
| R1 | 坚果云 WebDAV 限流（免费档每天 1G 流量 / 每分钟 30 次） | HIGH | S1, S3 | 节流：每次 push 间隔 ≥2s；记录 last-request 时间；超限退避 5 分钟 |
| R2 | DeepSeek API 不稳定 / 限流 | HIGH | S2, S4, S5 | 流式输出 + 自动重试（指数退避，最多 3 次）；超时 30s；用户可见错误 |
| R3 | API key 泄露（reverse engineering APK） | HIGH | S2 | flutter_secure_storage（OS 级加密）；不写日志；用户文档明确警告 |
| R4 | reader_page.dart 628 行重构破坏既有 reader | HIGH | S6 | S6 启动前加 "reader 回归测试套件"（既有 69+36 测试 + 新增 deep-link/scroll/annotation 边界） |
| R5 | 中文路径继续咬人（Gradle / MSBuild） | MEDIUM | S1, S6 | WebDAV unit test 用 ASCII 路径；Windows native smoke test 也在 ASCII 路径跑 |
| R6 | sync 冲突数据丢失 | HIGH | S3 | 冲突日志 + last-write-wins + 单元测试覆盖 N 种 race；永不物理删除（tombstone） |
| R7 | AI 输出不当内容（PII/政治敏感） | MEDIUM | S2, S4, S5 | DeepSeek 自带 content moderation；客户端不传用户隐私（只传书内容 + 用户选中文字） |
| R8 | bus factor = 1（review 警告） | MEDIUM | 所有 | S6 maintainer's runbook 必须写到能让"另一个 Claude 实例从零接手" |

### 中优（监控）

- R9: epubx_patched fork upstream drift（每 spiral 启动前 `git log --since=3.months` 检查 upstream）
- R10: pdfrx 升级破 selection API（pin 版本，升级前跑回归）
- R11: 用户超 8K token 的厚书摘要质量差（S2 截断首中尾；S4 章节摘要不受影响）
- R12: 离线 outbox 无限增长（S3 加 7 天清理 + 大小阈值警告）

---

## 5. Testing 策略

- **AI**：mock DeepSeek client（不真调 API，CI 不花钱），真实调用只在本地手动烟测
- **Sync**：mock WebDAV（http_mock_adapter）；集成测试用本地 WebDAV server（CI 不跑，手动跑）
- **跨设备 sync 集成**：手动测试（2 台 Windows 机器）
- **Windows native**：C++ smoke test（GoogleTest 或简易 assert main），CI 跑

---

## 6. Phase 3 入口判定（"phase 2 完成"硬标准）

**必须**：
- [ ] 6 个 spiral 全部交付，各自 tag 上 Gitee
- [ ] 全测试套件 ≥ 700 通过（phase 1 = 579，预计新增 ~150）
- [ ] v1.0.0 在 Gitee Release 上线，含 Windows 安装器 + portable zip
- [ ] maintainer's runbook 写完
- [ ] 2 台真实 Windows 机器完成 sync 端到端验证（设备 A 改 → B 看到）
- [ ] 用真实 DeepSeek key 跑通 AI 全功能（摘要 + 点评 + Q&A）
- [ ] 性能 baseline：冷启动 < 2s，5MB EPUB 滚动 ≥ 55fps

**不阻塞 phase 3**（推到 phase 3）：
- Android APK 打包（用 S1 sync engine）
- 跨书 AI 伴读（用 S5 占位 UI）
- iOS（如果决定做）
- 注释/markdown 导出格式扩展
- 真正的 merge 冲突解决（v1 是 last-write-wins）

---

## 7. 执行模型

- **每个 spiral = 1 个 plan + subagent-driven-development**
  - plan 写到 `docs/superpowers/plans/YYYY-MM-DD-m{X.Y}-<feature>.md`
  - 每 task 新 implementer + 两阶段 review（spec compliance → code quality）
  - 每 commit 推 Gitee（既有规则）
- **Spiral 启动前 checklist**：
  - [ ] spiral 内 design doc 通过用户 review
  - [ ] writing-plans 产出 plan
  - [ ] spiral 内风险（§4 表中对应行）确认有 mitigation
- **subagent 模型分配**：14-18 点用 haiku，其他时段 opus；C++ / Windows native / WebDAV HTTP 用 sonnet
- **每 spiral 完成交付物**：
  - 代码 + 测试
  - Gitee tag（`m2.0a-complete`, `m1.5a-complete` 等）
  - 更新 `CHANGELOG.md`
  - 1 段 memory 写入（`project_zhiyue_<spiral>_complete.md`）

---

## 8. 开放问题（推迟到各 spiral spec）

| 问题 | 推迟到 |
|---|---|
| sync engine 是否抽象到支持 Dropbox/OneDrive？ | S1 spec（倾向：抽象接口但只实现 WebDAV，YAGNI） |
| DeepSeek 还是同时支持 OpenAI-compatible？ | S2 spec（倾向：DeepSeek only，YAGNI） |
| AI 摘要的 prompt 工程细节（中文/英文/文学/技术书分别怎么 prompt） | S2 spec |
| sync 冲突 UI 是否允许用户手动选 winner？ | S3 spec（v1 倾向：不允许，只展示日志） |
| 章节摘要缓存失效策略（书更新时） | S4 spec |
| Q&A 引用的跳转精度（offset vs chapter+paragraph） | S5 spec |
| reader_page.dart 拆分粒度（controller/presenter/state/shortcuts） | S6 spec |
| perf 目标的具体测量方法（哪些工具、哪些场景） | S6 spec |

---

## 9. 工期估算

| Spiral | 估算 | 累计 |
|---|---|---|
| S1 Sync MVP | 5-7 天 | 5-7 |
| S2 AI MVP | 3-4 天 | 8-11 |
| S3 Sync 双向 | 4-5 天 | 12-16 |
| S4 AI 章节+点评 | 3-4 天 | 15-20 |
| S5 AI 问答 | 5-6 天 | 20-26 |
| S6 Polish sweep | 5-7 天 | 25-33 |
| **总计** | **25-33 天** | — |

比 phase 1（M0-M8 共 ~3 天）长 10 倍，因为：(1) sync/AI 是新领域需要探索；(2) perf 和 UX polish 不能赶；(3) v1.0 质量门槛。

---

## 10. Scope 升降级触发

- **升级触发**：phase 2 期间若用户反馈"AI 价值远超预期"，可考虑把跨书 AI 从 phase 3 拉回（占位 UI 已留好）
- **降级触发**：若 S5 (Q&A) 工期超 8 天仍未稳定，把 Q&A 推到 v1.1，phase 2 止于 S4

---

## 11. Phase 1 经验沿用

- `dart analyze`（不用 `flutter analyze`，中文路径 LSP 冲突）
- Windows native build 复制到 ASCII 路径 `/c/dev/zhiyue` 绕 MSBuild UTF-8↔GBK 冲突
- Gradle 中国镜像（用户级 `~/.gradle/init.gradle`）
- Commits via HEREDOC ending `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`
- 每 commit 推 Gitee `gitee.com:weifu0523/e-book-reading-platform.git`
- AGPLv3 license
- 不用 `--no-verify` / force push / amend
