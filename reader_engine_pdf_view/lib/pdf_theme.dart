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
class PdfTheme {
  /// 给定 [theme] 与 [child]，返回包装后的 widget。
  ///
  /// day 等价的 [ReadingTheme.light] 直接返回 [child]（无 [ColorFiltered]），
  /// 其余主题用 [ColorFiltered] 包一层。
  static Widget applyTheme({
    required ReadingTheme theme,
    required Widget child,
  }) {
    switch (theme) {
      case ReadingTheme.light:
        return child;
      case ReadingTheme.sepia:
        return ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Color(0x40F5DEB3), // 米黄半透明
            BlendMode.dstATop,
          ),
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
    }
  }
}
