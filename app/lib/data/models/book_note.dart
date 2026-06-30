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

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import 'annotation.dart';

@immutable
class BookNote {
  final String id;
  final String bookId;
  final String title;
  final String summary;
  final List<String> _keyTakeaways;
  final List<Annotation> _annotations;

  final DateTime createdAt;
  final DateTime updatedAt;

  const BookNote({
    required this.id,
    required this.bookId,
    required this.title,
    required this.summary,
    required List<String> keyTakeaways,
    required List<Annotation> annotations,
    required this.createdAt,
    required this.updatedAt,
  })  : _keyTakeaways = keyTakeaways,
        _annotations = annotations;

  factory BookNote.empty({
    required String id,
    required String bookId,
    required String bookTitle,
  }) {
    final now = DateTime.now();
    return BookNote(
      id: id,
      bookId: bookId,
      title: '《$bookTitle》读书笔记',
      summary: '',
      keyTakeaways: const [],
      annotations: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  List<String> get keyTakeaways => UnmodifiableListView(_keyTakeaways);
  List<Annotation> get annotations => UnmodifiableListView(_annotations);

  BookNote copyWith({
    String? title,
    String? summary,
    List<String>? keyTakeaways,
    List<Annotation>? annotations,
    DateTime? updatedAt,
  }) {
    return BookNote(
      id: id,
      bookId: bookId,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      keyTakeaways: keyTakeaways ?? _keyTakeaways,
      annotations: annotations ?? _annotations,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookNote &&
        runtimeType == other.runtimeType &&
        id == other.id &&
        bookId == other.bookId &&
        title == other.title &&
        summary == other.summary &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        // List 字段（UnmodifiableListView）按内容比较：默认 == 是引用相等，
        // 这里需要深度比较，否则 Riverpod 的 select + 自动 rebuild 会失效。
        listEquals(_keyTakeaways, other._keyTakeaways) &&
        listEquals(_annotations, other._annotations);
  }

  @override
  int get hashCode => Object.hash(
        id,
        bookId,
        title,
        summary,
        Object.hashAll(_keyTakeaways),
        Object.hashAll(_annotations),
        createdAt,
        updatedAt,
      );
}
