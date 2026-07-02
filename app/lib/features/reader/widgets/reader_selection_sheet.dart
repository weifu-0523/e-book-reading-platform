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

/// Bottom sheet shown after user selects text and taps 摘录.
///
/// Combines color picking + optional note entry into one save action.
/// Replaces the old flow of "高亮 button → color dialog → write" +
/// "笔记 button → identical to 高亮" (both buttons did the same thing).
///
/// UX:
/// - 5 color chips rendered in a row; tapping selects + shows ring.
/// - Optional 备注 TextField (3 lines).
/// - 取消 pops without saving; 保存 invokes [onSave] with (color, note?).
/// - `note` is `null` if the field is left empty (so [Annotation.hasNote]
///   returns false and the drawer shows the quote without a note badge).
class ReaderSelectionSheet extends StatefulWidget {
  const ReaderSelectionSheet({
    super.key,
    required this.onSave,
    this.initialColor,
    this.initialNote,
  });

  /// Invoked with (color, note?) when user taps 保存.
  /// `note` is null if user left the field empty.
  final void Function(HighlightColor color, String? note) onSave;

  /// Optional starting color (defaults to yellow, the most-used).
  final HighlightColor? initialColor;

  /// Optional starting note text (for edit flows).
  final String? initialNote;

  @override
  State<ReaderSelectionSheet> createState() => _ReaderSelectionSheetState();
}

class _ReaderSelectionSheetState extends State<ReaderSelectionSheet> {
  static const _order = [
    HighlightColor.yellow,
    HighlightColor.green,
    HighlightColor.blue,
    HighlightColor.red,
    HighlightColor.purple,
  ];

  static const _chipColors = {
    HighlightColor.yellow: Color(0xFFFFEB3B),
    HighlightColor.green: Color(0xFF4CAF50),
    HighlightColor.blue: Color(0xFF2196F3),
    HighlightColor.red: Color(0xFFF44336),
    HighlightColor.purple: Color(0xFF9C27B0),
  };

  late HighlightColor _selected = widget.initialColor ?? HighlightColor.yellow;
  late final TextEditingController _noteCtrl =
      TextEditingController(text: widget.initialNote ?? '');

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < _order.length; i++)
                    _colorChip(i, _order[i]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const Key('excerpt_note_field'),
                controller: _noteCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final note = _noteCtrl.text.trim();
                    widget.onSave(_selected, note.isEmpty ? null : note);
                    Navigator.of(context).maybePop();
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorChip(int index, HighlightColor color) {
    final isSelected = _selected == color;
    return GestureDetector(
      key: Key('excerpt_color_chip_$index'),
      onTap: () => setState(() => _selected = color),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _chipColors[color],
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface, width: 3)
              : null,
        ),
      ),
    );
  }
}
