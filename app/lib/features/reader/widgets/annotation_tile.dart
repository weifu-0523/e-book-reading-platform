import 'package:flutter/material.dart';
import '../../../data/models/annotation.dart';

class AnnotationTile extends StatelessWidget {
  final Annotation annotation;
  final String? chapterTitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const AnnotationTile({
    super.key,
    required this.annotation,
    this.chapterTitle,
    this.onTap,
    this.onLongPress,
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
              Text(chapterTitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
