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

import 'dart:convert';

/// Parsed review output from LLM JSON response.
class ReviewOutput {
  const ReviewOutput({required this.summary, required this.keyTakeaways});
  final String summary;
  final List<String> keyTakeaways;
}

/// Parses the LLM's review-mode JSON response.
///
/// Tolerates:
/// - Leading/trailing whitespace
/// - ```json ... ``` or ``` ... ``` fences (some LLMs ignore "no fences" instruction)
/// - Non-String elements in keyTakeaways (silently filtered)
///
/// Returns null if:
/// - JSON unparseable after fence stripping
/// - Top-level not an object
/// - `summary` field missing or not a String
/// - `keyTakeaways` missing or not a List
class ReviewOutputParser {
  const ReviewOutputParser._();

  static ReviewOutput? parse(String raw) {
    final trimmed = raw.trim();
    final unfenced = _stripFence(trimmed);
    final decoded = _tryDecode(unfenced);
    if (decoded == null) return null;
    if (decoded is! Map<String, dynamic>) return null;
    final summary = decoded['summary'];
    if (summary is! String) return null;
    final takeaways = decoded['keyTakeaways'];
    if (takeaways is! List) return null;
    final filtered =
        takeaways.whereType<String>().where((s) => s.isNotEmpty).toList();
    return ReviewOutput(summary: summary, keyTakeaways: filtered);
  }

  /// Strips one layer of ``` or ```json fencing if present.
  static String _stripFence(String s) {
    if (!s.startsWith('```')) return s;
    final firstNewline = s.indexOf('\n');
    if (firstNewline < 0) return s;
    var body = s.substring(firstNewline + 1);
    if (body.endsWith('```')) {
      body = body.substring(0, body.length - 3);
    }
    return body.trim();
  }

  static Object? _tryDecode(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }
}
