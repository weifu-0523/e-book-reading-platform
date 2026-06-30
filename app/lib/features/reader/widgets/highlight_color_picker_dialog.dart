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
