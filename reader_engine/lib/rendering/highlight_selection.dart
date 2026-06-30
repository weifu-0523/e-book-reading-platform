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

import 'package:meta/meta.dart';

/// 用户选区事件（由 EpubxRenderer 在选区结束时 emit）。
@immutable
class HighlightSelection {
  final String text;
  final int chapterIndex;
  final int startOffset;
  final int endOffset;

  const HighlightSelection({
    required this.text,
    required this.chapterIndex,
    required this.startOffset,
    required this.endOffset,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HighlightSelection &&
          text == other.text &&
          chapterIndex == other.chapterIndex &&
          startOffset == other.startOffset &&
          endOffset == other.endOffset;

  @override
  int get hashCode => Object.hash(text, chapterIndex, startOffset, endOffset);
}
