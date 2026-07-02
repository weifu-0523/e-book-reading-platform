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

import 'dart:ui' show Color;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../../core/locator.dart';

enum HighlightColor { yellow, green, blue, red, purple }

/// Material design swatch for each [HighlightColor], used wherever a chip /
/// tile / picker dot needs the canonical color. Centralized here to avoid
/// the same `<HighlightColor, Color>` map literal being duplicated across
/// `reader_selection_sheet.dart`, `annotation_tile.dart`, and
/// `highlight_color_picker_dialog.dart`.
extension HighlightColorX on HighlightColor {
  Color get swatch => switch (this) {
        HighlightColor.yellow => const Color(0xFFFFEB3B),
        HighlightColor.green => const Color(0xFF4CAF50),
        HighlightColor.blue => const Color(0xFF2196F3),
        HighlightColor.red => const Color(0xFFF44336),
        HighlightColor.purple => const Color(0xFF9C27B0),
      };
}

enum AnnotationSource { manual, aiAssisted }

@immutable
class Annotation {
  final String id;
  final String bookNoteId;
  final Locator locator;
  final String quote;
  final String? note;
  final HighlightColor color;
  final List<String> _tags;
  final AnnotationSource source;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Annotation({
    required this.id,
    required this.bookNoteId,
    required this.locator,
    required this.quote,
    required this.note,
    required this.color,
    required List<String> tags,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  }) : _tags = tags;

  bool get isHighlightOnly => note == null;
  bool get hasNote => note != null && note!.isNotEmpty;

  List<String> get tags => UnmodifiableListView(_tags);

  Annotation copyWith({
    String? note,
    HighlightColor? color,
    List<String>? tags,
    DateTime? updatedAt,
  }) {
    return Annotation(
      id: id,
      bookNoteId: bookNoteId,
      locator: locator,
      quote: quote,
      note: note ?? this.note,
      color: color ?? this.color,
      tags: tags ?? _tags,
      source: source,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
