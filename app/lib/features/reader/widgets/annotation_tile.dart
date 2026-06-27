import 'package:flutter/material.dart';
import '../../../data/models/annotation.dart';

class AnnotationTile extends StatelessWidget {
  final Annotation annotation;

  /// 已废弃：章节标题应由父级以 section header 形式渲染。
  /// 保留只是为了向后兼容，M4 会移除。
  @Deprecated('Use section header in parent. Will be removed in M4.')
  final String? chapterTitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showMeta;

  const AnnotationTile({
    super.key,
    required this.annotation,
    // ignore: deprecated_member_use_from_same_package
    this.chapterTitle,
    this.onTap,
    this.onLongPress,
    this.showMeta = false,
  });

  static const _colors = <HighlightColor, Color>{
    HighlightColor.yellow: Color(0xFFFFEB3B),
    HighlightColor.green: Color(0xFF4CAF50),
    HighlightColor.blue: Color(0xFF2196F3),
    HighlightColor.red: Color(0xFFF44336),
    HighlightColor.purple: Color(0xFF9C27B0),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[annotation.color] ?? Colors.yellow;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(annotation.quote,
                maxLines: 3, overflow: TextOverflow.ellipsis),
            if (annotation.hasNote) ...[
              const SizedBox(height: 4),
              Text(annotation.note!,
                  maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            if (chapterTitle != null) ...[
              const SizedBox(height: 4),
              // ignore: deprecated_member_use_from_same_package
              Text(chapterTitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (showMeta) ...[
              const SizedBox(height: 4),
              Text(
                _metaLine(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _metaLine() {
    final parts = <String>[_formatDate(annotation.updatedAt)];
    if (annotation.tags.isNotEmpty) {
      parts.add(annotation.tags.map((t) => '#$t').join(' '));
    }
    return parts.join(' · ');
  }

  static String _formatDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
