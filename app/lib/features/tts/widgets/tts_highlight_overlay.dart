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
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:reader_engine/rendering/highlight_range.dart';

import '../../../services/tts/tts_service.dart';

/// TTS 句子级「正在朗读」临时高亮（T13）。
///
/// 与用户级 5 色 [HighlightColor]（持久化到 `annotations` 表）不同，TTS 高亮
/// **永不入库**——它只活在内存中，由 T15 `TtsReaderController` 监听
/// [TtsService.progress] 把当前句子的 [Sentence] 转成 [HighlightRange]，合并
/// 进 `engine.injectHighlights([...userRanges, ...ttsRange])` 后再渲染。
///
/// 颜色选取为半透明金黄 `Color(0x66FFD700)`（≈ rgba(255,215,0,0.4)），与用户
/// 5 色互不冲突；`colorKey='tts'` 作为字符串 sentinel，方便日后序列化（例如
/// markdown 导出过滤、跨设备 sync 中跳过该 entry）时与 `HighlightColor.name`
/// 区分。当前没有 `colorKeyToColor` 集中映射——TTS 颜色仅在本文件中定义，
/// 不污染 [Annotation] / 数据库 schema。
///
/// 坐标系：[Sentence.startCfi]/[endCfi] 是简化 CFI `<chapterIndex>:<offset>`
/// （见 `reader_engine_epub_view/lib/cfi_codec.dart`），冒号后的整数即
/// `startOffset`/`endOffset`，直接喂给 [HighlightRange]。CFI 缺失时（PDF
/// 选区、降级路径）退回 `charStart`/`charEnd`——保证 renderer 永远拿到合法
/// offset，不会静默丢弃。
class TtsHighlightOverlay {
  const TtsHighlightOverlay._();

  /// 临时高亮颜色：半透明金黄。
  /// `0x66` alpha ≈ 40%，与 `reader_body._highlightColorRgba` 的 5 色透明度
  /// 颗粒度一致，保证视觉层级与用户高亮同档（不会盖住下层文字）。
  static const Color color = Color(0x66FFD700);

  /// 字符串 sentinel，区分于 [HighlightColor] 枚举名
  /// (`yellow|green|blue|red|purple`)。
  static const String colorKey = 'tts';

  /// CSS rgba 字符串，与 [reader_body.dart] 的 `_highlightColorRgba` 同源
  /// （renderer 接收 rgba 字符串而不是 Flutter [Color]）。
  /// `Color(0x66FFD700)` → ARGB(0x66, 0xFF, 0xD7, 0x00)
  /// → rgba(255, 215, 0, 0.4)。
  static const String colorRgba = 'rgba(255, 215, 0, 0.4)';

  /// 为当前正在朗读的 [sentence] 构造一个临时 [HighlightRange]。
  ///
  /// 优先用 CFI 冒号后的整数作为 offset（与 reader_engine 的 plain-text
  /// 坐标一致）；CFI 缺失时退回 `charStart`/`charEnd`。`hasNote` 永远为
  /// `false`——TTS 高亮不应在右侧渲染用户笔记小圆点。
  ///
  /// [chapterIndex] 透传到 [HighlightRange.chapterIndex]，paged 模式渲染时
  /// 引擎按章过滤（M2.11/问题3 防幽灵高亮机制同样适用于 TTS overlay）。
  static HighlightRange rangeFor(Sentence sentence, {required int chapterIndex}) {
    final start = _offsetFromCfi(sentence.startCfi) ?? sentence.charStart;
    final end = _offsetFromCfi(sentence.endCfi) ?? sentence.charEnd;
    return HighlightRange(
      start,
      end,
      colorRgba,
      hasNote: false,
      chapterIndex: chapterIndex,
    );
  }

  /// 解析简化 CFI `<chapterIndex>:<charOffset>` 的 offset 段。
  /// 失败（null / 无冒号 / 非整数）返回 null，调用方退回 charStart/charEnd。
  static int? _offsetFromCfi(String? cfi) {
    if (cfi == null) return null;
    final colon = cfi.indexOf(':');
    if (colon < 0) return null;
    return int.tryParse(cfi.substring(colon + 1));
  }
}
