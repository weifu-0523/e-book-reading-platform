# 智阅 v1.10.1-alpha Release Notes

**发布日期**：2026-07-12
**性质**：紧急 hotfix——坚果云 WebDAV baseUrl bug 修复
**Tag**：`v1.10.1-alpha`
**桌面稳定锚点**：`desktop-stable-pre-mobile`（保持）
**Schema 版本**：v13（沿用，无变更）

## 概述

1 行代码修复一个**从 day 1 就存在的 P0 bug**——同步功能的 baseUrl 错误地
把 username 段塞进 URL 路径，导致坚果云 WebDAV 同步从 v0.6.0-alpha（M2.0a
首次引入同步）起到 v1.10.0-alpha 一直失效。

## 修复

### 坚果云 WebDAV baseUrl 必须不含 username 路径段

**症状**：

用户配置好坚果云账号 + 应用密码后，点「立即同步」始终失败：

```
状态: 同步失败
WebDavException(409 at /zhiyue): <?xml version="1.0"?>
<d:error xmlns:d="DAV:"><s:exception>AncestorsNotFound</s:exception>
<s:message>The ancestors of this location does not found</s:message></d:error>
```

**根因**：

`app/lib/features/sync/providers/sync_controller.dart:146` 把 baseUrl 拼成：

```dart
// 错的（v0.6.0-alpha ~ v1.10.0-alpha）
final baseUrl = 'https://dav.jianguoyun.com/dav/${creds.username}';
```

但坚果云 WebDAV 通过 HTTP Basic Auth 解析账号，URL 路径里**没有** username
段。错的 URL 导致：

- `PROPFIND https://dav.jianguoyun.com/dav/<邮箱>/` → **404**（根不存在）
- 所有 `/dav/<邮箱>/zhiyue/...` 路径下的 MKCOL/PUT/GET → **409
  AncestorsNotFound**（因为整个父级路径都不存在）

**修复**：

```dart
// 对的（v1.10.1-alpha）
final baseUrl = 'https://dav.jianguoyun.com/dav';
```

**验证**（2026-07-12 用真实账号直接 curl 探测坚果云生产环境）：

| 探测 | URL | 错 baseUrl 结果 | 对 baseUrl 结果 |
|---|---|---|---|
| 根 PROPFIND | `…/dav/` 或 `…/dav/<邮箱>/` | 404 | **207 ✓** |
| `/zhiyue` PROPFIND | `…/dav/zhiyue/` | 409 | **207 ✓** |
| `/zhiyue` MKCOL | `…/dav/zhiyue` | 409 | **201 ✓** |
| `/zhiyue/snapshots/x.jsonl` PUT | 同上 | 409 | **201 ✓** |
| DELETE | 同上 | — | **204 ✓** |

dev 机端到端实测：填入相同凭据，点同步，状态变「同步成功」，坚果云
`/zhiyue/snapshots/<deviceId>.jsonl` 写入完整 snapshot（书 / 高亮 / 进度）。

## 影响

**此 bug 影响所有版本**（v0.6.0-alpha 至 v1.10.0-alpha，约 6 周）：
- 坚果云同步功能从未真正工作过
- 期间所有「坚果云 AncestorsNotFound」报告（v1.9.0-alpha Bug 1、v1.9.2-alpha
  Bug 1、v1.10.0-alpha S3 WS1）都是这个 baseUrl bug 的症状
- S3 WS1（commit `d76aca8`）的 PROPFIND disambiguate 修复建立在错误前提上
  （研究文档 §6 curl 命令本身带错 URL，所以「坚果云偏离 RFC 4918」结论是误判）

**Dead code 留待清理**：S3 WS1 PROPFIND disambiguate 在 v1.10.1-alpha 后成
为 dead code（用正确 URL 时坚果云 MKCOL 始终返 201，永远进不了 409 分支）。
清理延后到 v1.11.0-alpha。

## Commit 清单（v1.10.0-alpha 之后）

- `0852bd8` fix(sync): jianguoyun WebDAV baseUrl must not include username segment
- （本 release notes + CHANGELOG + README badge 更新）

## 测试覆盖

无新增测试——bug 是配置错（baseUrl 字符串），不是逻辑错，单测无法捕获。
（mock HTTP client 不关心 URL 路径格式。）

113 sync 单元测试 + 3 sync 集成测试全过（沿用 v1.10.0-alpha 基线）。

## 已知问题

- S3 WS1 PROPFIND disambiguate 是 dead code，待清理（v1.11.0-alpha）
- `docs/setup-webdav.md` 的「预先创建 zhiyue 文件夹」步骤已不必要（v1.10.1-alpha
  后 app 能自己 MKCOL），文档清理延后

## 升级

- **桌面**：直接覆盖安装 `zhiyue-setup-1.10.1-alpha.exe`，无 schema 变更
- **Android**：sideload 新 APK；无 schema 变更
- **WebDAV**：协议未变。升级后第一次「立即同步」会把之前堆积的 outbox
  一次性 flush 到云端

## 下一节点

- **M2.8 跨端续看续聊**（v1.11.0-alpha）：书籍文件 binary 同步 + AI 聊天
  历史 + 书籍标签，让"在电脑上看的书和聊天可以在手机上接着"
- S3 WS1 PROPFIND disambiguate dead code 清理
- `docs/setup-webdav.md` 同步部分简化
