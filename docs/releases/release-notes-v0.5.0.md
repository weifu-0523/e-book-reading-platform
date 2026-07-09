# 智阅 v0.5.0 Release Notes

**发布日期**：2026-06-28
**性质**：release（Windows 安装器 + 多平台分发就绪）
**Tag**：`v0.5.0`
**对应里程碑**：M8 — Release Packaging

## 主要变更

智阅开始正式分发。Windows 端有 Inno Setup 安装包和免安装 Zip，Android 端有真签名 fat APK；同时合规三件套（CHANGELOG / NOTICE / 截图）齐了。

### Added

- Windows Inno Setup 安装包（自动注册 `.epub` / `.pdf` 文件关联、开始菜单快捷方式、卸载项）。
- Windows 便携 Zip 分发（解压即用，免安装）。
- Android fat APK release artifact（真签名 + `apksigner verify`）。
- Windows 单实例 deep-link（命名 mutex + WM_COPYDATA 跨进程 argv 透传）——双击桌面图标二次启动时把 argv 透传给已有实例并前置窗口，而非再开一个进程。
- `BookOpenBridgeOptions.onError` 可选回调 → SnackBar 失败反馈（默认行为向后兼容）。
- `dart_test.yaml` 配置 golden tag（消除 test runner warning）。
- `CHANGELOG.md` + `NOTICE` 三件套（AGPLv3 合规）。
- `docs/setup-android-sdk.md` 安装指南。
- `docs/release-procedure.md` 发布流程手册。
- 4 张主界面截图（library / EPUB reader / PDF reader / Notes；另 3 张延后到 v1.0.0）。

### Changed

- 根 `README.md` 状态刷到 v0.5.0；加下载安装段 + 主界面预览。
- `app/README.md` 从 Flutter 模板骨架重写为开发者操作手册。

### Removed

- `.github/workflows/ci.yml`（项目 remote 在 Gitee，本地手动 build only）。

## Commit 清单

16 个 commit：

- docs：`059e317` spec、`d61ecd3` plan、`79a0664` CHANGELOG + NOTICE、`8f04575` Android SDK 指南、`86891ab` Gitee Release 上传 runbook、`4f71185` README 重写、`e99ddea` Windows 冒烟测试报告、`bfee397` 截图
- chore：`367ecca` drop CI + dart_test.yaml + bump 0.5.0
- feat：`c8e4c60` `onError` 回调、`dadb9a7` scaffoldMessengerKey + SnackBar、`9739fbb` 单实例 mutex、`f4d8568` WM_COPYDATA receiver、`3a3e796` Inno Setup 脚本、`0f06363` 便携 Zip 脚本
- fix：`747136f` C++ 编译错误

## 已知问题

- 仅 4 张截图，其余 3 张留 v1.0.0 用户手动采集。
- Windows release 构建在中文路径（`H:\projiect\电子书阅读平台`）下会失败（Flutter `gen_snapshot` GBK 解码 bug），构建时需拷贝到 ASCII 路径（详见 v1.0.0 runbook §3）。

## 升级指南

无破坏性变更。Windows 用户：

1. 下载 `zhiyue-setup.exe` 运行安装；或解压 `zhiyue-portable.zip` 免安装。
2. 安装版会自动关联 `.epub` / `.pdf`，双击文件直接打开智阅。
3. 已有便携版用户升级时直接覆盖目录。
