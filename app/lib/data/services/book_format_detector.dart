// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'dart:io';

import 'package:zhiyue/data/models/book.dart';

/// 通过文件 magic bytes 检测 [BookFormat]。
///
/// 当前规则：
/// - `%PDF-`（5 字节前缀）→ [BookFormat.pdf]
/// - `PK\x03\x04` ZIP 头 + `.epub` 扩展名 → [BookFormat.epub]
/// - `.md` / `.markdown` / `.mdown` 扩展名 → [BookFormat.markdown]（无 magic bytes）
/// - `.txt` 扩展名 → [BookFormat.text]（无 magic bytes）
/// - 空文件或未知特征 → `null`
///
/// 注意：EPUB 本质是 ZIP，但其他 ZIP 派生格式（如 .docx/.jar）也可能拥有
/// 相同前缀；为避免误判，EPUB 判定在 ZIP 基础上要求扩展名为 `.epub`。
/// PDF 的 `%PDF-` 前缀足够独特，扩展名不参与判定。
/// Markdown / TXT 是纯文本，无可靠 magic bytes，仅按扩展名判定（放在 magic
/// bytes 检查之后，避免把二进制文件误当文本）。
class BookFormatDetector {
  const BookFormatDetector._();

  /// 检测 [path] 指向文件的格式；无法识别时返回 `null`。
  static BookFormat? detect(String path) {
    final bytes = File(path).readAsBytesSync();
    // M4.5: 放宽到 1 字节（容纳极短 .txt）。原 < 5 会拒掉合法的短文本文件。
    if (bytes.isEmpty) return null;

    // PDF magic: %PDF-
    if (bytes.length >= 5 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D) {
      return BookFormat.pdf;
    }

    // EPUB: ZIP header (PK..) + .epub extension.
    // ZIP 家族格式众多，仅靠 magic bytes 不足以下定论，扩展名做二次约束。
    if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      final pathLower = path.toLowerCase();
      if (pathLower.endsWith('.epub')) return BookFormat.epub;
    }

    // M4.5: Markdown / TXT —— 无可靠 magic bytes，按扩展名判定。
    // 放在 magic bytes 之后：避免把同名二进制文件（如 report.pdf.txt）误判，
    // magic 优先级高于扩展名。.markdown / .mdown 也归入 markdown。
    final pathLower = path.toLowerCase();
    if (pathLower.endsWith('.md') ||
        pathLower.endsWith('.markdown') ||
        pathLower.endsWith('.mdown')) {
      return BookFormat.markdown;
    }
    if (pathLower.endsWith('.txt')) {
      return BookFormat.text;
    }

    return null;
  }
}
