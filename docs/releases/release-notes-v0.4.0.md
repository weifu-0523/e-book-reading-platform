# 智阅 v0.4.0 Release Notes

**发布日期**：2026-06-28
**性质**：feature（平台适配：Android + Windows 应用名 / 图标 / 签名 / deep-link）
**Tag**：`v0.4.0`
**对应里程碑**：M7 — Platform Adaptation

## 主要变更

让智阅从「桌面调试版」真正具备移动应用该有的样子：用户在系统里看得到「智阅」这个名字、看得到图标，点击 `.epub` / `.pdf` 文件能直接打开智阅。

### Added

- 应用显示名「智阅」（Android + Windows 双端同步）。
- `flutter_launcher_icons` pipeline（用户 AI 生图 → Android `mipmap-*` + Windows `.ico`）。
- Android release signing 配置（`keystore.properties` gitignored）。
- Android `intent-filter` 注册 `VIEW` epub/pdf（含 4 个 pathPattern 覆盖多重扩展名）。
- `BookOpenBridge` Dart bridge（`isSupportedBookPath` / `handlePath` / `init`，10 单测）。
- `MainActivity` Kotlin MethodChannel bridge（cold start `popPendingBookPath` + warm start `openBook` + `content://` 拷贝到 cacheDir）。
- `main.dart` 接入（`main(List<String> args)` + post-frame callback + `UncontrolledProviderScope`）。
- `routerProvider` Riverpod singleton（修 `ZhiYueApp.build` 每次重建新建 router 反模式）。

## Commit 清单

15 个 commit（milestone 自带的 spec/plan + 12 个 TDD 任务）：

- docs：`80f2800` spec、`79eacfc` plan
- chore/infra：`a2e8c12` launcher_icons dep + keystore gitignore、`ef601a9` bump 0.4.0+1
- feat：`1f8a69f` 显示名智阅、`7187465` Android release signing、`1ed684c` intent-filter、`6cae080`/`7799f21` BookOpenBridge、`209419a` MainActivity MethodChannel、`1c32b3b` main.dart 接入、`952c656` 图标资源生成
- refactor：`9d98b4e` routerProvider 单例
- fix：`e02a539` keystore 路径（移到 `android/app/keys/`）
- docs：`1b3cd32` Android + Windows 冒烟测试流程

## 已知问题

- iOS / macOS 路径未覆盖（本期仅 Android + Windows）。
- Windows `.epub` / `.pdf` 文件关联在 v0.5.0（M8 Inno Setup）才落地。

## 升级指南

无破坏性变更。开发者首次拉取后需：

```bash
cd app
flutter pub get
dart run flutter_launcher_icons        # 重新生成图标
# Android release 签名：放 keystore 到 android/app/keys/ 并填 keystore.properties
```
