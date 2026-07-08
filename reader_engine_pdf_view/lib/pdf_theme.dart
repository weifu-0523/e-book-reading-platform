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

import 'package:flutter/widgets.dart';
import 'package:reader_engine/core/typography_settings.dart';

/// 把 [PdfViewer] 包装在主题适配层内。
///
/// pdfrx 没有原生 sepia / night / eInk 模式，
/// 这里用 [ColorFiltered] 在显示层做颜色映射，与 EPUB 主题对齐：
///
/// - [ReadingTheme.light]：原样返回（白底黑字）
/// - [ReadingTheme.sepia]：米黄半透明叠加（pdfrx 没有 sepia 模式）
/// - [ReadingTheme.dark]：颜色反相矩阵（夜间模式，与 EPUB night 等价）
/// - [ReadingTheme.eInk]：灰度矩阵（墨水屏优化，去除彩色噪点）
///
/// **M4.6-fix14: 强制背景色**。pdfrx 渲染的 PDF 页面默认透明背景（PDF 规范
/// 不强制白底），用户报告"PDF 正文区空白"——根因是 dark 模式下 ColorFilter
/// 反相后，透明区域仍透明（alpha 不变），白色文字画在透明上 = 看不见。
/// sepia/green 模式的 BlendMode.dstATop 同理：只在 dst 不透明区显示 src，
/// 透明区域 src 被丢弃。修复：每个主题给一个 [backgroundColor]，用
/// [ColoredBox] 包 [child]，让 PdfViewer 始终有一个不透明底色供滤镜作用。
class PdfTheme {
  /// 给定 [theme] 与 [child]，返回包装后的 widget。
  ///
  /// day 等价的 [ReadingTheme.light] 直接返回 [child]（无 [ColorFiltered]），
  /// 其余主题用 [ColorFiltered] 包一层。
  static Widget applyTheme({
    required ReadingTheme theme,
    required Widget child,
  }) {
    final bgColor = backgroundColorFor(theme);
    return ColoredBox(
      color: bgColor,
      child: _wrapWithFilter(theme, child),
    );
  }

  /// 返回主题对应的背景色。
  ///
  /// dark 模式黑底（反相后白字可见）；sepia/green 暖底；light/eInk 白底。
  /// 调用方（如 reader_body 的选区容器）也可调用此方法获取匹配的 Scaffold
  /// 背景色，保证 PdfViewer 区域与周边 UI 视觉一致。
  static Color backgroundColorFor(ReadingTheme theme) {
    switch (theme) {
      case ReadingTheme.light:
        return const Color(0xFFFFFFFF);
      case ReadingTheme.sepia:
        return const Color(0xFFF5DEB3); // 米黄
      case ReadingTheme.dark:
        return const Color(0xFF000000); // 黑
      case ReadingTheme.eInk:
        return const Color(0xFFFFFFFF);
      case ReadingTheme.green:
        return const Color(0xFFE3EDD7); // 浅艾绿
    }
  }

  static Widget _wrapWithFilter(ReadingTheme theme, Widget child) {
    switch (theme) {
      case ReadingTheme.light:
        return child;
      case ReadingTheme.sepia:
        // 2026-07-08 BUG 1：sepia 改 matrix —— 把白色像素 (255,255,255) 映射到
        // 米黄色 (245,222,179)，深色像素（文字）保持。原 dstATop 半透明叠加
        // 会给所有像素盖一层米黄纱，文字变糊。matrix 路径 R*0.96/G*0.87/B*0.70
        // 让黑字 (0,0,0) 输出仍为 (0,0,0)，文字锐利。
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.96, 0, 0, 0, 0,
            0, 0.87, 0, 0, 0,
            0, 0, 0.70, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: child,
        );
      case ReadingTheme.dark:
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            // RGB 反相，alpha 保留
            -1, 0, 0, 0, 255,
            0, -1, 0, 0, 255,
            0, 0, -1, 0, 255,
            0, 0, 0, 1, 0,
          ]),
          child: child,
        );
      case ReadingTheme.eInk:
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            // ITU-R BT.601 luma: 0.299R + 0.587G + 0.114B
            0.299, 0.587, 0.114, 0, 0,
            0.299, 0.587, 0.114, 0, 0,
            0.299, 0.587, 0.114, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: child,
        );
      case ReadingTheme.green:
        // 2026-07-08 BUG 1：green 改 matrix。原 dstATop 半透明叠加
        // (0x40E3EDD7) 给整页盖绿色纱，文字糊。matrix 路径 R*0.89/G*0.93/B*0.84
        // 把白色像素 (255,255,255) 映射到艾绿 (227,237,215)，黑字保持
        // (0,0,0)，中间灰度按比例过渡。护眼绿效果保留，文字锐利度恢复。
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.89, 0, 0, 0, 0,
            0, 0.93, 0, 0, 0,
            0, 0, 0.84, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: child,
        );
    }
  }
}
