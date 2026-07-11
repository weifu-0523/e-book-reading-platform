# 坚果云 WebDAV MKCOL 409 AncestorsNotFound 调研

> **日期**：2026-07-11
> **作者**：S3 WS1 Task 1
> **目的**：为 S3 Task 2（`mkcol` 增加 409 容忍 + PROPFIND 验证）提供根因证据与设计依据
> **关联**：
> - 触发 bug：v1.9.2-alpha 桌面端 `WebDavException(409 at /zhiyue): AncestorsNotFound` at MKCOL stage
> - 设计 spec：`docs/superpowers/specs/2026-07-11-mobile-mvp-s3-design.md` §2.2（4 个假设 H1-H4）、§2.3（4 条修复路径 A-D）
> - 后续 task：Task 2 实现 Fix A（mkcol disambiguation）、Task 4 写 setup-webdav.md「首次配置」段（Fix C）

---

## 1. 背景

桌面端在 v1.9.2-alpha 推送后报告 sync 失败，错误为：

```
WebDavException(409 at /zhiyue): AncestorsNotFound
```

发生位置在 `WebDavClient.mkcol('/zhiyue')` 阶段（`ensureAncestors` 链式创建根目录时）。这与 v1.9.2-alpha Bug 1（已修）不同：Bug 1 修的是 `pushOnly` 初始 GET `/zhiyue/snapshots/<id>.jsonl` 返 409，桌面新报的是 MKCOL `/zhiyue` 返 409。spec §2.2 列出 4 个根因假设 H1-H4，本调研对各假设给出基于公开证据的评估。

## 2. RFC 4918 §9.3 基线（标准行为）

WebDAV RFC 4918 §9.3 对 MKCOL 的状态码定义（来源：[datatracker.ietf.org](https://datatracker.ietf.org/doc/html/rfc4918#section-9.3)）：

- **201 Created**：集合创建成功
- **405 Method Not Allowed**：MKCOL 只能在未映射的 URL 上执行，即目录**已存在**时返 405（MUST 失败）
- **409 Conflict**：**祖先不存在**时返 409（"A collection cannot be made at the Request-URI until one or more intermediate collections have been created"）；服务器 MUST NOT 自动创建中间集合
- **403 Forbidden**：服务器不允许在该位置创建集合，或父集合存在但不能接受成员
- **415 Unsupported Media Type**：不支持请求体类型

**关键**：按 RFC，目录已存在时**应**返 405，祖先缺失时**才**返 409。智阅当前 `mkcol` 实现只接受 `{201, 200, 405}`，把 409 当致命错误抛出，是 RFC-compliant 行为。

## 3. 坚果云实际行为（证据汇总）

坚果云的 WebDAV 行为在多个独立来源中被报告**偏离 RFC 4918**：

### 3.1 Joplin issue #3714（最直接证据）

Joplin 用户在 Win10 20H1 同步到坚果云时遇到**完全相同**的错误字符串：

```
Error: GET .sync/version.txt: The ancestors of this location does not
found (Exception AncestorsNotFound) (409): <d:error xmlns:d="DAV:"
xmlns:s="...">ancestors of this location does not found</s:message></d:error>
```

注意错误信息里的 `AncestorsNotFound` 与本项目报错**字符串完全一致**——这表明坚果云服务端用同一个内部异常类型，且在多种场景下（GET 路径不存在、MKCOL 父目录不存在）都返这个 XML 节点 + 409。来源：[github.com/laurent22/joplin/issues/3714](https://github.com/laurent22/joplin/issues/3714)。

### 3.2 anx-reader issue #410（重复创建场景）

anx-reader（另一款 Flutter 阅读器）报告：在坚果云**已存在**的 BOOKS 文件夹下 MKCOL 时返 409 Conflict，导致同步失败。标题原文「使用坚果云 WebDAV 同步时，因**重复创建目录**导致 409 Conflict 错误而同步失败」。来源：[github.com/Anxcye/anx-reader/issues/410](https://github.com/Anxcye/anx-reader/issues/410)。

这条证据**直接证明 H2**：坚果云在「目录已存在」场景下偏离 RFC 返 409（而非 RFC 要求的 405）。

### 3.3 all-api-hub issues #633 + #665

浏览器扩展 all-api-hub 在坚果云 WebDAV 上「测试连接通过，但无法上传/下载，状态码 409」。来源：[github.com/qixing-jk/all-api-hub/issues/633](https://github.com/qixing-jk/all-api-hub/issues/633)、[issues/665](https://github.com/qixing-jk/all-api-hub/issues/665)。同样表明坚果云在多种场景下用 409 作为通用错误码（而非 RFC 严格定义的「祖先缺失」）。

### 3.4 Koodo Reader 文档（H4 旁证）

Koodo Reader 官方文档明确指引：「**创建 Koodo Reader 文件夹**：登录您的坚果云账号，在网盘根目录创建名为 `KoodoReader` 的文件夹」——即在客户端连接**之前**手动在 web UI 创建文件夹。来源：[koodoreader.com/zh/add-source](https://koodoreader.com/zh/add-source)。

类似地，Zotero 文档提到首次同步时「会提示在坚果云里自动创建一个名叫：zotero 的文件夹」。来源：[help.jianguoyun.com?p=3168](https://help.jianguoyun.com?p=3168)。这表明部分客户端通过「自动 + 优雅降级」实现，而部分（如 Koodo）通过「要求用户预先创建」规避。

### 3.5 坚果云官方文档（限制清单）

坚果云帮助中心 §「第三方应用访问的限制」（来源：[help.jianguoyun.com?p=2064](https://help.jianguoyun.com?p=2064)）列出：

- 文件上传大小限制：默认 500M
- 访问频率限制：免费版 600 次/30 分钟；付费 1500 次/30 分钟
- 单次请求文件数：750 个（含分页）

**官方文档未提**：
- MKCOL 的具体行为（已存在返什么）
- 根级目录创建是否需要 web UI 预创建
- 应用密码是否有目录级权限范围

这是 H1 / H4 无法从官方文档直接证实的原因。

## 4. 假设评估

### H1：app password 权限不含根目录写 → 不太可能

**证据**：
- 坚果云官方文档（[p=2064](https://help.jianguoyun.com?p=2064)）描述应用密码时**未提**目录级权限范围，所有应用密码都映射到全账号
- 多个第三方应用（FolderSync、KeePass、WPS、Notability、Scanner Pro、Zotero）都使用同一应用密码机制且能正常写入根目录，未见报告「权限范围」类问题

**评估**：未证实。无证据表明坚果云应用密码有目录级权限模型。**不太可能是根因**。

### H2：坚果云 MKCOL 行为偏差（父存在也返 409）→ 强证据支持

**证据**：
- anx-reader issue #410 明确报告「重复创建目录导致 409 Conflict」——即目录已存在时返 409 而非 RFC 要求的 405
- all-api-hub issue #633 报告 GET 阶段也返 409（与 v1.9.2-alpha Bug 1 一致），证明坚果云用 409 作为通用「路径不存在 / 路径已存在 / 父目录缺失」错误码
- Joplin issue #3714 的 `AncestorsNotFound` 字符串与本项目错误字符串**完全一致**，证明这是坚果云服务端固定异常类型

**评估**：**已证实**。坚果云确实偏离 RFC 4918 §9.3——至少在「目录已存在」场景下返 409 而非 405。但**本项目当前 bug 的具体场景**（MKCOL `/zhiyue`，且 `/zhiyue` 不存在）究竟返 409 还是 201，**尚无直接的公开证据**。可能性：

- 若返 409 = 真的祖先缺失（与 RFC 一致）→ 当前 bug 不是 H2，更可能是 H4（根级目录特殊）
- 若返 409 = 偏差（即便 `/zhiyue` 不存在也返 409）→ 当前 bug 是 H2

无论哪种，Fix A（mkcol 增加 409 容忍 + PROPFIND 验证）都能覆盖。

### H3：URL 编码问题 → 最不可能

**证据**：
- 项目 baseUrl 形如 `https://dav.jianguoyun.com/dav/<username>`，username 是用户邮箱，常规情况下无特殊字符
- 错误信息明确是 `AncestorsNotFound at /zhiyue`，路径段是 ASCII 字面量 `zhiyue`，无编码空间
- v1.9.2-alpha 修复中 GET 阶段同 `_uri()` 路径生成能命中正确路径（否则会返 401 / 404 而非 409）

**评估**：未证实，**最不可能**。`/zhiyue` 路径段不含特殊字符，且 `_uri()` 在 v1.9.2-alpha GET 修复中已被间接验证可用。

### H4：坚果云必须 web UI 预创建根级目录 → 部分支持

**证据**：
- Koodo Reader 文档明确要求用户预先在 web UI 创建 `KoodoReader` 文件夹（[koodoreader.com/zh/add-source](https://koodoreader.com/zh/add-source)）
- Zotero 客户端在首次同步时会自动触发文件夹创建（暗示根级目录创建可能存在某种约束）
- 项目用户报告的错误**正好发生在 `/zhiyue` 这一级**（root 的直接子目录），与 H4 模式吻合
- 但：缺少官方文档明确说明「根级目录必须 web UI 创建」，也无社区帖子直接证明这一点
- 也可能：根本不是「根级」特殊，而是坚果云对**所有** MKCOL 都偏向返 409（H2 的更广义形式）

**评估**：部分支持，但**无法完全证实**。H4 和 H2（广义版）的实际表现对用户而言相同——MKCOL `/zhiyue` 失败。Fix A + Fix C 组合能同时覆盖两种情况。

## 5. 最可能根因综合判断

基于现有证据，**最可能的根因是 H2（广义版）+ 部分 H4 的组合**：

1. 坚果云 WebDAV 服务端在 MKCOL 时**返 409 作为多种错误的通用码**（已存在、祖先缺失、可能也包括根级目录创建约束）——这是已证实的行为偏差
2. 项目当前 bug `AncestorsNotFound at /zhiyue` 中，`AncestorsNotFound` 字符串**字面上**暗示「祖先缺失」，但对于 `/zhiyue`（root 的直接子目录），「祖先」就是 root 本身（`/dav/<username>/`），而 root 一定存在（否则前面的 GET 也会失败）——这表明坚果云的 `AncestorsNotFound` 异常字符串与实际语义**不完全对应**，更像是服务端 catch-all 错误
3. 不能完全排除 H4（坚果云对根级目录 MKCOL 有特殊限制），但即便如此，Fix A 的 PROPFIND 验证仍能正确分支（用户 web UI 创建后，MKCOL 返 409，PROPFIND 返 207 → 视为已存在 → OK）

**未证实的开放问题**（需 Task 2 真机验证或用户手动 curl 才能完全确定）：
- 在完全空的坚果云账号上 MKCOL `/dav/<username>/zhiyue` 实际返什么状态码？
- 若用户已在 web UI 创建 `/zhiyue`，再次 MKCOL 返 405 还是 409？
- `AncestorsNotFound` 是否在「目录已存在」场景也会出现（即与 H2 的 anx-reader case 是否同一异常类型）？

## 6. 推荐 curl 复现命令（**用户手动执行**，禁止子代理运行）

> **警告**：以下命令包含真实坚果云凭据，必须由用户在自己的终端运行。子代理不得执行。

```bash
# 步骤 1：确认账号根目录可访问（PROPFIND）
curl -v -X PROPFIND \
  -u "<username>:<app-password>" \
  -H "Depth: 0" \
  https://dav.jianguoyun.com/dav/<username>/

# 步骤 2：在 root 直接子级 MKCOL（复现 bug 场景）
curl -v -X MKCOL \
  -u "<username>:<app-password>" \
  https://dav.jianguoyun.com/dav/<username>/zhiyue

# 步骤 3：再次 MKCOL 同一路径（验证 H2：已存在是否也返 409）
curl -v -X MKCOL \
  -u "<username>:<app-password>" \
  https://dav.jianguoyun.com/dav/<username>/zhiyue

# 步骤 4：PROPFIND 验证（无论 MKCOL 返什么，验证目录是否真的存在）
curl -v -X PROPFIND \
  -u "<username>:<app-password>" \
  -H "Depth: 0" \
  https://dav.jianguoyun.com/dav/<username>/zhiyue

# 步骤 5：清理（DELETE）
curl -v -X DELETE \
  -u "<username>:<app-password>" \
  https://dav.jianguoyun.com/dav/<username>/zhiyue
```

**预期结果与假设对应**：

| 步骤 | RFC-compliant 期望 | 若 H2 成立（偏差） | 若 H4 成立（根级特殊） |
|---|---|---|---|
| 步骤 2（首次 MKCOL）| 201 Created | 201 或 409 | 409 AncestorsNotFound |
| 步骤 3（再次 MKCOL）| 405 Method Not Allowed | **409 Conflict** | 409 Conflict |
| 步骤 4（PROPFIND 已存在）| 207 Multi-Status | 207 | 207 |
| 步骤 4（PROPFIND 不存在）| 404 | 404 或 409 | 409 |

**关键观察点**：步骤 3 是否返 409 而非 405——这是 H2 的决定性证据。若步骤 3 返 409，Fix A 的 PROPFIND disambiguation 是必须的；若返 405，当前 `mkcol` 已能处理（405 已在白名单）。

## 7. 推荐修复路径

按 spec §2.3 的 4 条路径（A/B/C/D）评估：

### Fix A：mkcol 增加 409 容忍 + PROPFIND 验证 → **强推荐**（核心修复）

**理由**：
- 同时覆盖 H1 / H2 / H4 三种假设，不依赖单一根因证实
- 与 RFC 4918 兼容（RFC 服务器本就返 405，新增 409 分支不影响）
- Joplin issue #3714 评论中其他用户反馈 PROPFIND disambiguation 是处理坚果云 409 偏差的标准做法
- 已有现成测试设计（spec §2.4 表格）

**实现要点**（供 Task 2 参考）：
- 409 → 立即 PROPFIND 同一路径（Depth: 0）
- PROPFIND 207 → 视为已存在，return（不抛）
- PROPFIND 404 / 409 / 其他非 207 → rethrow 原 409（真正的祖先缺失，不能掩盖）
- 必须保留 201/200/405 的 fast path（避免对 RFC-compliant 服务器产生多余 PROPFIND 请求）

### Fix B：ensureAncestors 加每段日志 → **推荐**（调试辅助）

**理由**：production 环境下用户报错时，目前只有最外层 409 信息，无法分辨是 `/zhiyue` 段失败还是 `/zhiyue/snapshots` 段失败。Fix B 让每个 MKCOL 段都记录 status + body，便于后续 jianguoyun 行为继续变化时快速定位。低成本，高 ROI。

### Fix C：setup-webdav.md 加「jianguoyun 首次配置」段 → **推荐**（用户兜底）

**理由**：
- 若根因确实是 H4（根级目录必须 web UI 创建），Fix A 仍会失败（PROPFIND 也返 409 → rethrow）——Fix C 是这种情况下的唯一兜底
- Koodo Reader 的做法证明这是社区接受的 workaround
- 即使根因不是 H4，预先创建 `/zhiyue` 也不会有害（Fix A 会走「已存在」分支）
- 任务分配：Task 4 实现

### Fix D（spec 未明确，但隐含在 Fix C 内）：首次启动检测 + 对话框

**理由**：spec §7 R5 提到「jianguoyun 在 PROPFIND 上也返 409」的风险。若 Fix A + Fix C 都失败，应在 sync 配置完成后首次 sync 时检测到 MKCOL+PROPFIND 双 409，弹对话框「请在坚果云 web UI 创建 `/zhiyue` 文件夹后重试」。**优先级低于 A/B/C，可在 Task 4 后视真机测试结果决定是否需要**。

**综合推荐**：Task 2 实现 Fix A + Fix B；Task 4 实现 Fix C；Fix D 视真机测试结果决定。

## 8. 对 Task 2 实现的具体建议

1. **测试矩阵必须包含的 4 个 case**（与 spec §2.4 一致）：
   - mkcol 201/200 → return（无副作用）
   - mkcol 405 → return（已存在，RFC 路径）
   - mkcol 409 + PROPFIND 207 → return（H2 偏差路径）
   - mkcol 409 + PROPFIND 非 207 → rethrow（真祖先缺失）
   - mkcol 500/401/403 → throw（不被静音）

2. **listFiles 复用**：spec 草稿用 `listFiles(path)` 做 PROPFIND，但 `listFiles` 默认 Depth: 1 会拉取所有子项（成本高）。建议新增 `exists(path)` 方法用 Depth: 0，仅检查资源存在性。这是 spec 的一个**小优化建议**——若 Task 2 实施时发现 `listFiles` 性能问题或返回 schema 解析复杂，可改用 `exists`。

3. **错误信息保留**：rethrow 时保留原始 409 的 body（含 `AncestorsNotFound` XML），便于日志和未来调试。不要用 PROPFIND 的错误覆盖原错误。

4. **不要尝试自动重试 MKCOL**：409 → PROPFIND 207 → return 即可，不要再发第二次 MKCOL（避免触发坚果云频率限制 600/30min）。

## 9. 来源清单

1. RFC 4918 §9.3 MKCOL - [datatracker.ietf.org/doc/html/rfc4918#section-9.3](https://datatracker.ietf.org/doc/html/rfc4918#section-9.3) — 标准 WebDAV MKCOL 状态码语义
2. Joplin issue #3714 - [github.com/laurent22/joplin/issues/3714](https://github.com/laurent22/joplin/issues/3714) — 坚果云 WebDAV AncestorsNotFound 409 同类案例（Win10 客户端）
3. anx-reader issue #410 - [github.com/Anxcye/anx-reader/issues/410](https://github.com/Anxcye/anx-reader/issues/410) — 坚果云 MKCOL 重复创建导致 409（Flutter 阅读器同类项目）
4. all-api-hub issue #633 - [github.com/qixing-jk/all-api-hub/issues/633](https://github.com/qixing-jk/all-api-hub/issues/633) — 坚果云 WebDAV 上传/下载 409
5. all-api-hub issue #665 - [github.com/qixing-jk/all-api-hub/issues/665](https://github.com/qixing-jk/all-api-hub/issues/665) — 坚果云 WebDAV 状态码 409 后续报告
6. 坚果云官方：第三方应用授权 WebDAV 开启方法 - [help.jianguoyun.com?p=2064](https://help.jianguoyun.com?p=2064) — 应用密码机制与速率限制
7. 坚果云官方：Zotero 设置 WebDAV - [help.jianguoyun.com?p=3168](https://help.jianguoyun.com?p=3168) — 首次同步自动创建文件夹
8. Koodo Reader 添加数据源 - [koodoreader.com/zh/add-source](https://koodoreader.com/zh/add-source) — 要求用户预先在 web UI 创建文件夹
9. janbar 博客：学习 WebDav - [cnblogs.com/janbar/p/13804097.html](https://www.cnblogs.com/janbar/p/13804097.html) — 坚果云 WebDAV curl 命令示例
10. WebDAV 概览（http.dev）- [http.dev/webdav](https://http.dev/webdav) — MKCOL/PROPFIND 通用语义参考

## 10. 摘要（一句话）

坚果云 WebDAV 在 MKCOL 时返 409 作为通用错误码（偏离 RFC 4918 §9.3 要求的 405），且 `AncestorsNotFound` 异常字符串出现在多种场景（已存在 / 祖先缺失 / 可能含根级目录约束）；推荐 Fix A（mkcol 409 + PROPFIND disambiguation）+ Fix B（ensureAncestors 日志）+ Fix C（setup 文档预创建指引）组合，对 Task 2 实现给出 5 个测试 case 和 4 条实现要点。
