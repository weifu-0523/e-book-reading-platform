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

import 'dart:convert';

import 'package:epubx/epubx.dart';

/// 把 EPUB 章节 HTML 中的 `<img src="相对路径">` 替换为 data URI。
///
/// **根因（用户报告）**：在 EPUB 中有部分图片（如 neat-reader 等阅读器都能
/// 显示），但在智阅里看不到任何一张插图。
///
/// 调查：[HtmlWidget]（fwfh）默认只支持 network / asset / data URI 三种 src，
/// 不知道怎么解析 EPUB 内部相对路径。`EpubChapter.HtmlContent` 中的 `<img src>`
/// 是相对路径（如 `../images/foo.png`），fwfh 无从查找。
///
/// 修复：扫描 HTML 中所有 `<img>` 标签，把 src 解析为 OPF 包内绝对路径，在
/// `book.Content.Images` 中查到 bytes，转 base64 data URI 内联回去。这样
/// fwfh 的 `ImageWidgetFactory` 默认 data URI 分支直接解码。
///
/// 性能：每章通常 < 10 张图，扫描 + 替换 < 1ms。data URI 内联让 HTML 增大
/// ~33%（base64 膨胀），但 Paginator 测量 plain text（已剥 img），不受影响。
class EpubImageInliner {
  /// 解析 [book] 的所有图片资源，构建 inliner 上下文。
  ///
  /// 内部缓存：完整路径 → bytes + basename → bytes 两个映射，前者精确匹配，
  /// 后者兜底（某些 EPUB manifest href 不含目录前缀，basename 唯一时直接命中）。
  /// 重复 basename 后写入覆盖前者（极少见，忽略）。
  factory EpubImageInliner(EpubBook book) {
    final byFullPath = <String, _EpubImage>{};
    final byBasename = <String, _EpubImage>{};
    final images = book.Content?.Images;
    if (images != null) {
      for (final entry in images.entries) {
        final href = entry.key;
        final file = entry.value;
        final bytes = file.Content;
        if (bytes == null || bytes.isEmpty) continue;
        final mime = file.ContentMimeType ?? _guessMime(href);
        final img = _EpubImage(bytes, mime);
        // 完整路径（去 leading slash + lower）作为精确匹配 key
        byFullPath[_normalizePath(href)] = img;
        // basename 兜底（同 basename 多图后者覆盖，极少见）
        final base = _basename(href);
        if (!byBasename.containsKey(base)) {
          byBasename[base] = img;
        }
      }
    }
    return EpubImageInliner._(byFullPath, byBasename);
  }

  EpubImageInliner._(this._byFullPath, this._byBasename);

  final Map<String, _EpubImage> _byFullPath;
  final Map<String, _EpubImage> _byBasename;

  /// 内联 [chapterHtml] 中所有 `<img src>` 为 data URI。
  ///
  /// [chapterContentFileName] 是当前 chapter 的 xhtml 在 OPF 包内的路径
  /// （`EpubChapter.ContentFileName`，如 `OEBPS/Text/chap1.xhtml`），用于解析
  /// img src 相对路径。null 时仅按 basename 兜底匹配（命中率较低）。
  ///
  /// 已是 data URI / http(s) / absolute path 的 src 不处理，保留原样。
  String inline(String chapterHtml, {String? chapterContentFileName}) {
    if (_byFullPath.isEmpty && _byBasename.isEmpty) return chapterHtml;
    // img src 正则：覆盖单/双引号、src 前后空白、自闭合/非自闭合标签。
    // 不区分大小写。capture 第 1 组 = quote char，第 2 组 = src 值。
    final re = RegExp(
      r'''<img\b[^>]*?\bsrc\s*=\s*(['"])([^'"]+)\1''',
      caseSensitive: false,
    );
    final chapterDir = chapterContentFileName == null
        ? null
        : _dirname(chapterContentFileName);
    return chapterHtml.replaceAllMapped(re, (m) {
      final rawSrc = m.group(2)!;
      // 跳过已是 data: / http(s): / https: 的 src（fwfh 原生支持）
      if (rawSrc.startsWith('data:') ||
          rawSrc.startsWith('http://') ||
          rawSrc.startsWith('https://')) {
        return m.group(0)!;
      }
      // 去除 URL fragment / query（EPUB 内部图片极少用，但鲁棒起见）
      final pathOnly = rawSrc.split('#').first.split('?').first;
      final resolved = chapterDir == null
          ? pathOnly
          : _resolveRelative(chapterDir, pathOnly);
      final img = _lookup(resolved) ?? _lookup(pathOnly);
      if (img == null) {
        // 找不到资源：保留原 src（fwfh 会显示 broken image icon，比静默吞好）
        return m.group(0)!;
      }
      final b64 = base64.encode(img.bytes);
      final dataUri = 'data:${img.mime};base64,$b64';
      return m.group(0)!.replaceFirst(rawSrc, dataUri);
    });
  }

  _EpubImage? _lookup(String normalizedPath) {
    final p = _normalizePath(normalizedPath);
    return _byFullPath[p] ?? _byBasename[_basename(p)];
  }

  /// 路径规范化：去 leading slash + 反斜杠转正斜杠 + 小写。
  /// EPUB 规范大小写敏感，但实际阅读器普遍 case-insensitive，这里 lower
  /// 让 inliner 更宽容（同书同图不同 case 极罕见）。
  static String _normalizePath(String path) {
    var p = path.replaceAll('\\', '/');
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    return p.toLowerCase();
  }

  /// basename：取最后一段路径，去 extension 之外的字符（保留 ext）。
  static String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final lastSlash = normalized.lastIndexOf('/');
    final base = lastSlash >= 0 ? normalized.substring(lastSlash + 1) : normalized;
    return base.toLowerCase();
  }

  /// dirname：取除最后一段外的路径（不含末尾 slash）。
  static String _dirname(String path) {
    final normalized = path.replaceAll('\\', '/');
    final lastSlash = normalized.lastIndexOf('/');
    return lastSlash >= 0 ? normalized.substring(0, lastSlash) : '';
  }

  /// 解析 [rel] 相对于 [baseDir] 为 OPF 包内绝对路径（normalized）。
  /// 处理 `.`（当前目录）和 `..`（上级目录）。
  static String _resolveRelative(String baseDir, String rel) {
    final stack = baseDir.split('/')..removeWhere((s) => s.isEmpty);
    for (final seg in rel.split('/')) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (stack.isNotEmpty) stack.removeLast();
        continue;
      }
      stack.add(seg);
    }
    return stack.join('/');
  }

  static String _guessMime(String href) {
    final lower = href.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }
}

class _EpubImage {
  const _EpubImage(this.bytes, this.mime);
  final List<int> bytes;
  final String mime;
}
