# WebDAV 配置指南

智阅通过 WebDAV 协议支持跨设备数据同步（高亮、笔记、阅读进度、AI 会话等）。本文档列出已验证的 WebDAV 服务商首次配置步骤与故障排查。

> 同步原理：每个设备在 `/zhiyue/snapshots/<deviceId>.jsonl` 维护自己的快照，最后写入胜（last-write-wins）。冲突会在「设置 → 数据同步 → 冲突日志」中提示。

---

## jianguoyun (坚果云) 首次配置

### 配置步骤

**步骤 1**：在 jianguoyun 网页版 `https://www.jianguoyun.com` 登录账号，进入根目录（「我的资料」）。

**步骤 2**：手动创建名为 `zhiyue` 的文件夹（全小写，无空格）。

> 智阅的 WebDAV 数据全部存在 `/zhiyue/snapshots/<deviceId>.jsonl`。
> 坚果云 WebDAV 对根级目录创建有特殊行为（详见 [research](superpowers/research/2026-07-11-jianguoyun-mkcol-409-research.md)），未在 web UI 预先创建此文件夹，首次同步可能报 `WebDavException(409 at /zhiyue): AncestorsNotFound`。

**步骤 3**：在 jianguoyun「账户信息 → 安全选项 → 第三方应用管理」生成「应用密码」，权限保持默认（读写）。

> 应用密码与登录密码不同，是专门给第三方客户端用的。账号填写邮箱全称（例如 `user@example.com`），密码填应用密码。

**步骤 4**：在智阅「设置 → 数据同步」填入账号（邮箱）+ 应用密码，点「立即同步」。首次同步成功后会显示 `同步成功` 与最后同步时间。

### 故障排查

- **`WebDavException(409 at /zhiyue): AncestorsNotFound`**
  99% 是 `zhiyue` 文件夹未在坚果云 web UI 创建。登录网页版创建后重试。
  若仍失败，可能为账号换了应用密码但智阅未更新 — 在「数据同步」页重新输入。

- **`WebDavException(401 at ...)`**
  应用密码错误，或账号填错（账号是邮箱全称）。重新生成应用密码并粘贴（注意首尾空格）。

- **`WebDavException(404 from /dav/<user>)`**
  账号 URL 段错误。坚果云 baseUrl 是 `https://dav.jianguoyun.com/dav/<邮箱全称>`，邮箱内的特殊字符（如 `+`、`.`）需要 URL 编码。智阅会自动处理，但若手动改过 baseUrl 须检查。

- **同步卡住、超时**
  坚果云免费版限制：600 次请求 / 30 分钟。大量导入书籍或连续手动同步会触发限流，等 30 分钟即可。

### 已知行为偏差

坚果云 WebDAV 偏离 RFC 4918：
- 对「目录已存在」的 MKCOL 返回 409 Conflict（RFC 要求 405 Method Not Allowed）
- 对「父目录缺失」的 GET 返回 409 AncestorsNotFound（RFC 要求 404 Not Found）

智阅 `WebDavClient` 已针对这两种偏差做容错处理（v1.9.2-alpha + v1.10.0-alpha），无需用户介入。

---

## 其他 WebDAV 服务商

智阅兼容任何标准 WebDAV 服务（Nextcloud、ownCloud、Synology Drive、Box 等）。配置步骤类似：

1. 在服务商处获取 WebDAV baseUrl（如 `https://cloud.example.com/remote.php/dav/files/<user>/`）
2. 创建顶级目录 `zhiyue`（部分服务商会自动创建，无需手动）
3. 在智阅填入 baseUrl + 账号 + 密码

如遇兼容性问题，请到 [Gitee Issues](https://gitee.com/your-org/zhiyue/issues) 报告。
