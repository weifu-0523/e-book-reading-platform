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
