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

/// Emitted by [EpubxRenderer.chapterEndEvents] when the reader reaches the
/// last page of the current chapter (paged mode) or scrolls within 64px of
/// the bottom (scroll mode).
///
/// Field semantics:
/// - [chapterIndex]: 0-based flat index of the chapter that just ended.
/// - [isLastChapter]: true if this is the last chapter in the book (UI uses
///   this to suppress the "Next chapter" button).
class ChapterEndEvent {
  const ChapterEndEvent({
    required this.chapterIndex,
    required this.isLastChapter,
  });

  final int chapterIndex;
  final bool isLastChapter;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterEndEvent &&
          runtimeType == other.runtimeType &&
          chapterIndex == other.chapterIndex &&
          isLastChapter == other.isLastChapter;

  @override
  int get hashCode => chapterIndex.hashCode ^ isLastChapter.hashCode;

  @override
  String toString() =>
      'ChapterEndEvent(chapterIndex: $chapterIndex, isLastChapter: $isLastChapter)';
}
