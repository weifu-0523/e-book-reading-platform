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
