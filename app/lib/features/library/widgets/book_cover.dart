import 'dart:io';

import 'package:flutter/material.dart';

/// 书籍封面 widget。
///
/// [coverFile] 为 null 或解码失败时显示首字符占位图。
class BookCover extends StatelessWidget {
  final File? coverFile;
  final String title;
  final double aspectRatio;

  const BookCover({
    super.key,
    required this.coverFile,
    required this.title,
    this.aspectRatio = 0.7,
  });

  @override
  Widget build(BuildContext context) {
    if (coverFile == null) {
      return _Placeholder(title: title, aspectRatio: aspectRatio);
    }
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Image.file(
        coverFile!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _Placeholder(
          title: title,
          aspectRatio: aspectRatio,
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  final double aspectRatio;

  const _Placeholder({required this.title, required this.aspectRatio});

  @override
  Widget build(BuildContext context) {
    final firstChar = title.isNotEmpty ? title.characters.first : '?';
    final color = _colorFromString(title);
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        color: color,
        alignment: Alignment.center,
        child: Text(
          firstChar,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  static const _palette = [
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.pink,
    Colors.teal,
  ];

  Color _colorFromString(String s) {
    return _palette[s.hashCode.abs() % _palette.length];
  }
}
