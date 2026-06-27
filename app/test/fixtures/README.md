# 测试 fixture EPUB

本目录存放 M2 EPUB 阅读器测试用书，**不入库**（版权 + 二进制）。

## 必备书目

| 文件名 | 用途 | 下载源 |
|---|---|---|
| `page-blanche.epub` | 标准英文 EPUB 基线 | https://www.gutenberg.org/ebooks/... （任选 public domain） |
| `kite-runner-cn.epub` | 中文 reflowable | 团队私有 / 公共领域中文 EPUB |
| `weicheng.epub` | 复杂 TOC + 嵌套 spine | 钱钟书《围城》公开领域版本 |
| `bad-cfi.epub` | 构造异常 CFI | 手工构造（用 EPUB 编辑器修改 OEBPS） |

新机器准备环境时：
1. 按上表下载/构造 4 个文件，放到本目录
2. 运行 `/c/flutter/bin/flutter test app/test/` 验证
3. 不准备则相关测试会 skip（参见 `fixture_loader.dart`）

## 测试 fixture PDF（M4/T14）

`pdfs/` 子目录存放 M4 PDF 阅读器测试用 PDF，**不入库**（与 EPUB 同策略，
见根 `.gitignore` 第 30-31 行的 `*.pdf` / `*.epub` 规则）。

| 文件名 | 用途 | 生成方式 |
|---|---|---|
| `pdfs/sample-text.pdf` | 含文本的标准 PDF 基线 | pdfrx 官方 hello.pdf：`curl -sL https://raw.githubusercontent.com/espresso3389/pdfrx/master/packages/pdfrx/example/viewer/assets/hello.pdf -o pdfs/sample-text.pdf`（CN 环境需走 ghproxy 镜像） |
| `pdfs/sample-corrupted.pdf` | 截断字节流，测错误处理 | `head -c 1024 pdfs/sample-text.pdf > pdfs/sample-corrupted.pdf` |
| `pdfs/sample-scanned.pdf` | 无文本层扫描 PDF（可选） | 当前 **未提供**：手头无现成扫描 PDF，scanned_detector 的端到端集成测试因此跳过；组件级单测仍走自身 mock。 |

新机器准备 PDF 环境时：
1. 创建 `pdfs/` 目录
2. 按上表 2 步生成 sample-text / sample-corrupted
3. 运行 `/c/flutter/bin/flutter test test/features/reader/reader_page_pdf_integration_test.dart`
   —— fixture 缺失时，对应的 sanity 测试会 fail（**不** skip，因为 fixture
   是 T14 已知能拉的公开资源，不像 EPUB 那样需要版权判断）。
4. 真正的 widget-level PDF 端到端测试**始终 skip** —— pdfrx 需要 PDFium
   native channel，`flutter test` headless 环境跑不起来；要走
   `integration_test/` 设备测试。
