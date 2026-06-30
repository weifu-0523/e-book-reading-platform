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

/// A character range identifying one page within a paginated chapter.
///
/// Offsets are in the same coordinate space as
/// `ReaderEngine.currentChapterPlainText` (post-T0 unification).
class PageBreak {
  final int startOffset;
  final int endOffset;

  const PageBreak({required this.startOffset, required this.endOffset});

  @override
  bool operator ==(Object other) =>
      other is PageBreak &&
      startOffset == other.startOffset &&
      endOffset == other.endOffset;

  @override
  int get hashCode => Object.hash(startOffset, endOffset);

  @override
  String toString() => 'PageBreak($startOffset..$endOffset)';
}
