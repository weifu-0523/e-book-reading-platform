import 'package:flutter/material.dart';
import '../../../data/models/annotation.dart';

class HighlightColorPickerDialog extends StatelessWidget {
  const HighlightColorPickerDialog({super.key});

  static const _labels = <HighlightColor, String>{
    HighlightColor.yellow: '黄色',
    HighlightColor.green: '绿色',
    HighlightColor.blue: '蓝色',
    HighlightColor.red: '红色',
    HighlightColor.purple: '紫色',
  };

  static const _colors = <HighlightColor, Color>{
    HighlightColor.yellow: Color(0xFFFFEB3B),
    HighlightColor.green: Color(0xFF4CAF50),
    HighlightColor.blue: Color(0xFF2196F3),
    HighlightColor.red: Color(0xFFF44336),
    HighlightColor.purple: Color(0xFF9C27B0),
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择高亮颜色'),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _labels.entries.map((e) {
          return InkWell(
            onTap: () => Navigator.of(context).pop(e.key),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                      backgroundColor: _colors[e.key], radius: 18),
                  const SizedBox(height: 4),
                  Text(e.value),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
