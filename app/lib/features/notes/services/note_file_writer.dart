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

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

/// Filesystem wrapper for Markdown export.
///
/// Wraps file_picker's directory picker behind a small surface that's easy to
/// test (callers inject [FilePicker.platform] in tests). The pick+write cycle
/// is grouped here so UI code (NotesPage, export SnackBar) stays free of I/O.
class NoteFileWriter {
  /// Opens a directory picker (Windows/macOS/Linux via file_picker) and writes
  /// [content] to `<pickedDir>/<suggestedName>.md`. Returns the absolute path
  /// on success or `null` if the user cancelled the dialog.
  ///
  /// If a file already exists at the resolved path, appends ` (1)`, ` (2)`,
  /// … before the `.md` extension until a free slot is found — never silently
  /// overwrites existing exports.
  static Future<String?> saveMarkdownFile({
    required String content,
    required String suggestedName,
  }) async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return null;

    var name = '$suggestedName.md';
    var path = p.join(dir, name);
    var counter = 1;
    while (await File(path).exists()) {
      name = '$suggestedName ($counter).md';
      path = p.join(dir, name);
      counter++;
    }

    await File(path).writeAsString(content);
    return path;
  }

  /// Sanitize a free-form book/annotation title into a filesystem-safe name
  /// segment.
  ///
  /// - Replaces Windows/Linux/macOS forbidden chars (`\ / : * ? " < > |`)
  ///   with `_`.
  /// - Trims leading/trailing whitespace and collapses interior runs to a
  ///   single space.
  /// - Truncates to 80 characters (preserves the un-suffixed part of the
  ///   filename even when paired with ` (N).md` collision suffix).
  static String sanitizeForFilename(String raw) {
    var s = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    s = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (s.length > 80) s = s.substring(0, 80);
    if (s.isEmpty) return 'untitled';
    return s;
  }
}
