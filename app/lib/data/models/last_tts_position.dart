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

/// TTS playback cursor for cross-device resume.
///
/// Stored as JSON in `books.last_tts_position`. When user resumes reading
/// aloud a book on another device, T17 chapter boundary logic uses this
/// to prompt "continue from chapter N, sentence M?".
///
/// Parsing is tolerant: missing or malformed fields fall back to `0` so a
/// corrupted payload arriving via sync (older client, truncation, etc.)
/// never throws — BooksDao.getLastTtsPosition additionally wraps the
/// jsonDecode in a try/catch and treats unparseable blobs as null
/// (i.e. "never read aloud").
class LastTtsPosition {
  final int chapterIdx;
  final int sentenceIdx;
  final int updatedAt; // millisecondsSinceEpoch

  const LastTtsPosition({
    required this.chapterIdx,
    required this.sentenceIdx,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'chapterIdx': chapterIdx,
        'sentenceIdx': sentenceIdx,
        'updatedAt': updatedAt,
      };

  factory LastTtsPosition.fromJson(Map<String, dynamic> j) => LastTtsPosition(
        chapterIdx: _readInt(j, 'chapterIdx'),
        sentenceIdx: _readInt(j, 'sentenceIdx'),
        updatedAt: _readInt(j, 'updatedAt'),
      );

  /// Tolerant int read: accepts num (int/double), rejects everything else
  /// (String / bool / List / Map / null) by falling back to 0. The naive
  /// `as num?` cast throws on a non-numeric value, which would propagate
  /// through BooksDao.getLastTtsPosition's try/catch and silently null out
  /// a payload that was merely partially malformed (e.g. one bad field).
  static int _readInt(Map<String, dynamic> j, String key) {
    final v = j[key];
    if (v is num) return v.toInt();
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LastTtsPosition &&
          runtimeType == other.runtimeType &&
          chapterIdx == other.chapterIdx &&
          sentenceIdx == other.sentenceIdx &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(chapterIdx, sentenceIdx, updatedAt);

  @override
  String toString() =>
      'LastTtsPosition(chapterIdx: $chapterIdx, sentenceIdx: $sentenceIdx, updatedAt: $updatedAt)';
}
