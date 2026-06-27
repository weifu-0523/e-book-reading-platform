import 'package:meta/meta.dart';

/// 阅读位置的统一抽象。
///
/// EPUB 使用 CFI（Canonical Fragment Identifier）；
/// PDF 使用页码 + 视口偏移。
@immutable
sealed class Locator {
  const Locator();

  Map<String, dynamic> toJson();

  factory Locator.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'epubCfi':
        return EpubCfiLocator(
          cfi: json['cfi'] as String,
          // 容错：跨平台 JSON 编码器可能输出 double 形式的整数（如 JS、备份导入），
          // `as int` 在此场景抛 TypeError；与 offsetX/offsetY 一致改用 num.toInt()。
          chapterIndex: (json['chapterIndex'] as num).toInt(),
          chapterTitle: json['chapterTitle'] as String?,
        );
      case 'pdfPage':
        return PdfPageLocator(
          page: (json['page'] as num).toInt(),
          offsetX: (json['offsetX'] as num).toDouble(),
          offsetY: (json['offsetY'] as num).toDouble(),
        );
      case 'pdfRange':
        return PdfRangeLocator(
          page: (json['page'] as num).toInt(),
          startOffset: (json['startOffset'] as num).toInt(),
          endOffset: (json['endOffset'] as num).toInt(),
          quote: json['quote'] as String,
        );
      case 'epubRange':
        return EpubRangeLocator(
          chapterIndex: (json['chapterIndex'] as num).toInt(),
          chapterTitle: json['chapterTitle'] as String?,
          startOffset: (json['startOffset'] as num).toInt(),
          endOffset: (json['endOffset'] as num).toInt(),
          quote: json['quote'] as String,
        );
      default:
        // M3: 用 FormatException 而非 ArgumentError——
        // 这是"数据格式不兼容"信号（语义比 ArgumentError 更精确）。
        // 主要触发场景：未来 schema 演进后旧版本读取新数据。
        // 上层应 catch 并通过日志/监控识别此类事件。
        throw FormatException(
          'Unknown Locator type "$type", JSON: $json. '
          'This may indicate data written by a newer app version.',
        );
    }
  }

  String toJsonString();
}

class EpubCfiLocator extends Locator {
  final String cfi;
  final int chapterIndex;
  final String? chapterTitle;

  const EpubCfiLocator({
    required this.cfi,
    required this.chapterIndex,
    this.chapterTitle,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'epubCfi',
        'cfi': cfi,
        'chapterIndex': chapterIndex,
        if (chapterTitle != null) 'chapterTitle': chapterTitle,
      };

  @override
  String toJsonString() => cfi;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpubCfiLocator &&
          cfi == other.cfi &&
          chapterIndex == other.chapterIndex &&
          chapterTitle == other.chapterTitle;

  @override
  int get hashCode => Object.hash(cfi, chapterIndex, chapterTitle);
}

class PdfPageLocator extends Locator {
  final int page;
  final double offsetX;
  final double offsetY;

  const PdfPageLocator({
    required this.page,
    required this.offsetX,
    required this.offsetY,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'pdfPage',
        'page': page,
        'offsetX': offsetX,
        'offsetY': offsetY,
      };

  @override
  String toJsonString() => 'page:$page';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfPageLocator &&
          page == other.page &&
          offsetX == other.offsetX &&
          offsetY == other.offsetY;

  @override
  int get hashCode => Object.hash(page, offsetX, offsetY);
}

/// M3.2: 纯文本 EPUB 中字符 offset 区间定位，用于高亮范围。
///
/// 与 [EpubCfiLocator] 不同，此处用字符 offset 而非 CFI——
/// 简化渲染层计算（无需 CFI 解析），适合非标准 EPUB 或自渲染文本流。
class EpubRangeLocator extends Locator {
  final int chapterIndex;
  final String? chapterTitle;
  final int startOffset;
  final int endOffset;
  final String quote;

  const EpubRangeLocator({
    required this.chapterIndex,
    required this.startOffset,
    required this.endOffset,
    required this.quote,
    this.chapterTitle,
  })  : assert(startOffset >= 0),
        assert(endOffset > startOffset),
        // 使用 .length > 0 而非 .isNotEmpty —— const 构造器中 isNotEmpty 非常量表达式。
        assert(quote.length > 0);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'epubRange',
        'chapterIndex': chapterIndex,
        if (chapterTitle != null) 'chapterTitle': chapterTitle,
        'startOffset': startOffset,
        'endOffset': endOffset,
        'quote': quote,
      };

  @override
  String toJsonString() => '$chapterIndex:$startOffset-$endOffset';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpubRangeLocator &&
          chapterIndex == other.chapterIndex &&
          chapterTitle == other.chapterTitle &&
          startOffset == other.startOffset &&
          endOffset == other.endOffset &&
          quote == other.quote;

  @override
  int get hashCode =>
      Object.hash(chapterIndex, chapterTitle, startOffset, endOffset, quote);
}

/// M4: PDF 单页内字符 offset 区间定位，用于高亮范围。
///
/// 与 [EpubRangeLocator] 对称，差异仅在「page」（PDF 1-based 页码）取代
/// EpubRangeLocator 的 chapterIndex（章索引）。两者都用于高亮存储；
/// 导航用 [PdfPageLocator]。
class PdfRangeLocator extends Locator {
  final int page;
  final int startOffset;
  final int endOffset;
  final String quote;

  const PdfRangeLocator({
    required this.page,
    required this.startOffset,
    required this.endOffset,
    required this.quote,
  })  : assert(page >= 1),
        assert(startOffset >= 0),
        assert(endOffset > startOffset),
        // 使用 .length > 0 而非 .isNotEmpty —— const 构造器中 isNotEmpty 非常量表达式。
        assert(quote.length > 0);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'pdfRange',
        'page': page,
        'startOffset': startOffset,
        'endOffset': endOffset,
        'quote': quote,
      };

  @override
  String toJsonString() => 'p$page:$startOffset-$endOffset';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PdfRangeLocator &&
          page == other.page &&
          startOffset == other.startOffset &&
          endOffset == other.endOffset &&
          quote == other.quote;

  @override
  int get hashCode => Object.hash(page, startOffset, endOffset, quote);
}
