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

/// Result of parsing a chapter-mode AI output into summary + bullet list.
class ChapterBulletParseResult {
  const ChapterBulletParseResult({
    required this.summary,
    required this.bullets,
  });
  final String summary;
  final List<String> bullets;
}

/// Splits chapter-mode AI output into (summary, bullets).
///
/// Algorithm:
/// 1. Split into lines.
/// 2. Lines matching the bullet regex (`- x` or `* x`) are bullets.
/// 3. Non-empty non-bullet lines are joined (with space) into the summary.
/// 4. Empty input → empty result.
class ChapterBulletParser {
  const ChapterBulletParser._();

  static final _bulletRegex = RegExp(r'^\s*[-*]\s+(.+?)\s*$');

  static ChapterBulletParseResult parse(String text) {
    if (text.trim().isEmpty) {
      return const ChapterBulletParseResult(summary: '', bullets: []);
    }
    final lines = text.split('\n');
    final summaryBuf = <String>[];
    final bullets = <String>[];
    for (final line in lines) {
      final m = _bulletRegex.firstMatch(line);
      if (m != null) {
        bullets.add(m.group(1)!.trim());
      } else if (line.trim().isNotEmpty) {
        summaryBuf.add(line.trim());
      }
    }
    final summary = summaryBuf.join(' ').trim();
    return ChapterBulletParseResult(summary: summary, bullets: bullets);
  }
}
