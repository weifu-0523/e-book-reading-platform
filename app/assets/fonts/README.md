# 打包字体（M3a/任务5）

本目录存放 M3a 排版增强打包的开源 OFL 中文字体，供阅读器「字体」选项
（黑体/宋体/楷体）使用。字体文件**不入 git**（体积大），首次拉取仓库后需
运行下载脚本获取：

```bash
bash scripts/download-fonts.sh        # Git Bash / WSL
# 或
pwsh scripts/download-fonts.ps1       # PowerShell
```

下载完成后在 `app/` 目录跑 `flutter pub get` 让 Flutter 注册字体。

## 字体清单

| 逻辑 family（pubspec / 代码用） | UI 标签 | 文件 | 来源 | 协议 |
|---|---|---|---|---|
| `NotoSansSC` | 黑体 | `NotoSansSC-Regular.otf` (~8MB) | [notofonts/noto-cjk](https://github.com/notofonts/noto-cjk) SubsetOTF/SC | OFL 1.1 |
| `NotoSerifSC` | 宋体 | `NotoSerifSC-Regular.otf` (~12MB) | [notofonts/noto-cjk](https://github.com/notofonts/noto-cjk) SubsetOTF/SC | OFL 1.1 |
| `LXGWWenKai` | 楷体 | `LXGWWenKai-Regular.ttf` (~25MB) | [lxgw/LxgwWenKai](https://github.com/lxgw/LxgwWenKai) v1.522 | OFL 1.1 |

> 注：pubspec 里 `family:` 是 Flutter 注册的逻辑别名，不必与字体内部
> post 表 name（如 `Noto Sans SC`）完全一致。代码用 `TextStyle(fontFamily: 'NotoSansSC')`
> 引用，pubspec 与 typography_panel.dart 三处必须一致。

## 圆体

圆体选项**暂未提供**——目前没有完美的开源 OFL 圆体（Dubai 不开源，思源无
Round 变体）。UI 不显示圆体 chip；用户可选「系统」（Windows 即微软雅黑，
本身偏圆）作 fallback。若未来出现合适开源圆体，可在此追加。

## Subset 说明

v1 用 Google Noto 的 **SubsetOTF/SC**（仅简体中文字集），比全字重 CJK
（16MB）小一半（~8MB）。若需繁体/日韩字形，可改用全 CJK OTF（修改
`scripts/download-fonts.sh` 的 URL）。霞鹜文楷无 subset 版，直接用 release
完整字体（~25MB，含全 GB 字）。

## 失败 fallback

若下载脚本失败（网络/镜像失效），字体不显示但**不会崩溃**——Flutter 会
fallback 到系统字体（Windows 微软雅黑）。`app/pubspec.yaml` 的 fonts 声明
已入 git，无需改动；只缺二进制文件。修复镜像 URL 后重跑脚本即可。
