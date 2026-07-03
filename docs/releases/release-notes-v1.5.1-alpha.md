# v1.5.1-alpha — Emergency Bug Fix Sweep

发布日期：2026-07-03

## 为什么有这个 release

v1.5.0-alpha 上午交付后用户立即上手测试，发现 9 个 bug，其中数个阻塞核心阅读流程。这是 fast-follow 补丁，**纯修复，无新功能**。

## 修复了什么

9 个 bug 跨 P0/P1/P2 全部闭（详见 CHANGELOG）。重点：

- **翻页工作正常了** —— 键盘箭头 / 鼠标拖拽在所有模式下都翻页（之前 PDF scroll 模式被静默吞）。
- **PDF 双页是用户独立 toggle** —— AppBar 新增按钮显式切换，不再耦合窗口宽度。
- **排版控件响应** —— 之前读到 const 默认值，写到丢弃对象。
- **高亮选完真渲染** —— injectHighlights 现在触发 widget 重建。
- **目录点击真跳页** —— EpubRangeLocator 分支现在 emit state。
- **默认边距加宽** —— Normal 24→32, Wide 32→48, ExtraWide 40→64。
- **仿真书 tap zone 模型** —— 左右空白边点击翻页，中央纯选择，4 面留白。
- **ESC 退出全屏** —— AppBar 按钮点击后焦点自动回收。

## 已知限制

- Bug #1（书签点击红屏）仅有防御性修复，根因待用户复现提供 stack trace。
- EPUB 双页渲染仍推到 v1.6（API surface 不变）。
- PDF 双页 toggle 不持久化（v1.5.2 加 SharedPreferences）。

## 升级注意

如新默认边距过宽，请 **Settings → Typography → Margin → Compact**（8px）切回。

## 测试

4 包全 clean，**1069 pass + 3 skipped**（baseline 1066 + 3 新回归测试）。
