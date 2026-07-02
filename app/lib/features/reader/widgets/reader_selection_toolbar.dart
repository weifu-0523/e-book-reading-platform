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
import 'package:flutter/rendering.dart' show SelectedContent;

import 'highlight_selection_controls.dart';

/// Floating selection toolbar overlay extracted from `reader_body.dart`.
///
/// Renders nothing (`SizedBox.shrink()`) when [selection] is null or its
/// `plainText` is empty. Otherwise renders [HighlightSelectionControls]
/// inside a [Positioned] at the top of the parent [Stack].
///
/// Caller is responsible for owning the [SelectedContent] state and passing
/// the 3 tap callbacks (摘录 / 复制 / 可选 AI 点评). This widget has no internal state.
class ReaderSelectionToolbar extends StatelessWidget {
  final SelectedContent? selection;
  final VoidCallback onExcerpt;
  final VoidCallback onCopy;
  final VoidCallback? onAiComment;

  const ReaderSelectionToolbar({
    super.key,
    required this.selection,
    required this.onExcerpt,
    required this.onCopy,
    this.onAiComment,
  });

  @override
  Widget build(BuildContext context) {
    final sel = selection;
    if (sel == null || sel.plainText.isEmpty) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: Center(
        child: HighlightSelectionControls(
          onExcerpt: onExcerpt,
          onCopy: onCopy,
          onAiComment: onAiComment,
        ),
      ),
    );
  }
}
