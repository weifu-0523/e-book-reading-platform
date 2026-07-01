# 项目整体 Review 跟踪（2026-07-02 凌晨 catch-up 任务）

**触发**：用户 2026-07-01 21:57 设置定时任务，2026-07-02 凌晨 catch-up 触发。

**Review 范围**：P0/P1 bug、spec drift、测试覆盖、AGPLv3、文档一致性、路线图偏移、lint 残留。

## 已修复（4 个 commit，全 pushed origin master）

| 优先级 | 问题 | Commit | 测试 |
|---|---|---|---|
| Sync P0-3 | `syncNow` 无重入保护，并发 sync 跑两个 engine.sync() 在 per-device jsonl 上互相覆盖 | `cc37f35` | `_GatedFakeEngine` 验证 engine.calls == 1 |
| AI P1-5 | `qa_history._toEntry` 不容错 corrupted citations_json，sync 冲突/手工编辑后会 crash 列表页 | `49aa15e` | 2 测试注入 empty / 非 JSON 字符串 |
| AI P1-2 | selection-mode 缓存 key 漏 chapterTitle，同短语在不同章节会命中错章节的回答 | `a72ad39` | counting HTTP client 验证 llmCalls == 2 |
| AI P0 | SSE 流未跨 TCP 包缓冲，长 JSON 行被切时 `jsonDecode` 抛异常中断流，丢已付 token | `f3548d5` | 2 测试模拟 2-chunk + 3-chunk 切分 |

## 验证为误报（reviewer 报但代码无问题）

| 优先级 | 问题 | 为什么是误报 |
|---|---|---|
| Sync P0-2 | "outbox purge 7 天 vs 文档 30 天" | spec 明确 7 天 outbox + 30 天 conflicts，文档一致；memory 描述不精确已订正 |
| Drift P0-1 | "onUpgrade 缺 7 张基础表（annotations / book_notes / reading_progress / typography_profiles / book_typography_overrides / settings / ...）" | v1 schema 已含这 7 张表（M1 commit `ed3f12e`），onUpgrade 只需创建 v2-v9 新增的 7 张表（已全覆盖） |
| Drift P0-2 | "onUpgrade 事务失败留半升级状态" | drift 2.x 默认把 onUpgrade 包在事务里，异常会回滚（reviewer 误读 drift 行为） |
| Drift P1-1 | "v3→v4 FTS5 INSERT SELECT 假设列已存在" | 该 SELECT 只在 v4 升级路径触发，annotations 表此时已存在（v1 起就有） |
| Sync P1-4 | "regex 解析 PROPFIND XML 遇 `&amp;`/CDATA 会断" | 置信度 low，文件名 URL-encode 不含 XML 实体 |

## 延后（需用户决策或设计工作）

### Sync P0-1 — pushOnly read-modify-write 非原子

- **风险**：deviceId 备份/还原或换机迁移时，两台设备共享 deviceId，并发 push 会后写覆盖先写
- **触发条件**：罕见（deviceId 由 uuid v4 生成并 secure-storage 持久化），但破坏性强
- **修复路径**：
  1. `WebDavClient` 加 If-Match/ETag 头支持
  2. `WebDavSyncEngine.pushOnly` PUT 失败（412）时重新 GET → 合并 → 重试
  3. 验证 jianguoyun WebDAV 是否真支持 ETag（其文档说支持但需实测）
- **建议**：v1.5 同步模块重构时一并处理

### AI P1-3 — baseUrl 无 HTTPS 校验

- **风险**：用户配 `http://attacker.com` 类 URL 时 API key 明文发出
- **触发条件**：BYOK 用户被社工/钓鱼诱导
- **修复路径**：
  1. `_save()` 校验 `Uri.parse(baseUrl).scheme == 'https'`
  2. localhost/127.0.0.1 豁免（开发自测）
  3. 其他 HTTP 弹确认对话框警告"密钥将明文传输"
- **建议**：v1.4 stable 发布前补，避免 alpha 用户被钓鱼

### AI P1-4 — Q&A 无去重/并发/限流

- **风险**：用户连点提交 → 多个并发 LLM stream → 重复扣费 + qa_history 表膨胀
- **修复路径**：
  1. `BookQaService.ask` 入口 `trim()` + 折叠空白
  2. `_inflightQuestions: Set<(String, String)>` 同 (bookId, normalized Q) 在途时拒绝
  3. 共享滑动窗口 rate limiter（10 req/min 之类）
- **建议**：M2.x（用户反馈频繁使用 AI 后）

### Sync P1-1 — RemoteRecordApplier 可变 deviceId 字段

- **设计气味**：`currentRemoteDeviceId` 是 mutable public 字段，无并发保护
- **实际触发**：P0-3 修了之后，外部并发已基本不可能触发该字段被覆盖
- **修复路径**：把 deviceId 作为 `apply(record, deviceId)` 参数传，applier 无状态
- **建议**：M2.x sync refactor 时一并清理

### Sync P1-2 — book pull 不按 fileHash 去重

- **风险**：两设备导入同一本书（同 fileHash 不同 id）→ outbox 各推一条 → 互相 pull 时双方 skip → 库里出现两本重复书
- **修复路径**：`_applyBook` INSERT OR IGNORE 后查 fileHash，已有则 skip
- **建议**：v1.4 stable 前

### Sync P1-3 — listFiles 不区分目录 vs 文件

- **风险**：用户在 `/zhiyue/snapshots/` 建子目录 `backup.jsonl/` → pull 抛异常 → 同步永久失败
- **修复路径**：`pullOnly` 单文件 GET 包 try/catch；或 PROPFIND 加 `<D:resourcetype>` 区分 collection
- **建议**：低优先级

## 测试覆盖空白

按 cron 提示重点核查 sync / AI 缓存 / PDF/EPUB 解析：

- ✅ Sync：核心路径覆盖完整（web_dav_sync_engine_test.dart 6 个、remote_record_applier_test.dart 6 个、sync_controller_test.dart 5 个）；M2.0b P0-3 修后新增并发重入测试
- ✅ AI 缓存：M2.1 修过 reviewer cache hash；M2.4 review 再修 selection mode hash；ai_summaries_dao 完整覆盖
- ✅ AI SSE：M2.4 review 新增 2 个跨包测试；已有 401/429/5xx 覆盖
- ⚠️ PDF/EPUB 解析：reader_engine_pdf_view 和 reader_engine_epub_view 测试覆盖正常路径，但**异常路径**（malformed epub、加密 PDF、超大 PDF）测试覆盖较薄；M5/M6 PDF 增强时补
- ⚠️ Drift migration onUpgrade：现有 5 个 migration 测试只覆盖 fresh-install (onCreate)，**没有真实 from-v1-to-v9 升级测试**；M3.x 数据层稳定后建议补 e2e migration test

## 文档一致性

- ✅ M2.4 spec acceptance 与代码完全对齐
- ✅ dart analyze 真正 0 issues（README 旧称 "131 info" 已订正为 "0 info"）
- ⚠️ README 测试数滞后：812 → 818 已订正（M2.4/T11 prep commit 内一并修）
- ⚠️ MEMORY.md M2.0b 描述 "30天 purge" 模糊：实际是 outbox 7 天 + conflicts 30 天；下次更新 memory 时订正

## AGPLv3 头覆盖率

- ✅ app/lib：production 全覆盖；17 个生成文件（`.g.dart` / `gen_l10n`）按 analysis_options 豁免
- ✅ reader_engine*/lib：production 全覆盖
- ⚠️ test 目录：app/test 177 个 + reader_engine*/test 32 个 = 209 个测试文件缺 SPDX 头
- **建议**：补 SPDX 不阻塞当前 release；但 AGPLv3 合规角度，test 文件也是源码 derivative，应有 license 头。可作为下一次 hygiene sweep 的一项

## 路线图偏移

- ✅ M2.4 严格围绕 release hygiene，未偏离 phase 2 roadmap
- ✅ 4 个 review 修复都是 bug fix，未引入新功能/技术
- ⚠️ SSE 跨包修复 + selection cache 修复 属于"AI 模块正确性提升"，可考虑作为 v1.4 stable 候选 changelog 项

## 总结

- **修了 N=3 个 P0 + 1 个 P1**（实际代码 4 commit）
- **剩余未修复**：1 个 sync P0 + 4 个 P1 + 1 个 P1-design，已列入延后清单
- **是否需要用户介入**：是
  - sync P0-1 (ETag) 需用户确认是否在 v1.5 sync 重构范围
  - baseUrl HTTPS 校验需用户决策 UX（弹窗文案/是否豁免 localhost）
  - test SPDX 头补全需用户决定是否纳入下次 hygiene sweep
  - T8-T11 交互项（截图 / Gitee Release / 烟测 / tag）仍是用户现场操作
