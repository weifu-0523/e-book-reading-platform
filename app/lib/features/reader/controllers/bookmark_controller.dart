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

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Locator;
import 'package:uuid/uuid.dart';

import '../../../core/locator.dart';
import '../../../core/providers.dart' show bookmarkRepositoryProvider;
import '../../../data/local/database.dart';
import '../../../data/repositories/bookmark_repository.dart';
import '../providers/notes_controller.dart' show currentBookIdProvider;

class BookmarkState {
  final List<BookmarkEntry> bookmarks;
  final bool isLoading;
  final String? error;

  const BookmarkState({
    this.bookmarks = const [],
    this.isLoading = false,
    this.error,
  });

  BookmarkState copyWith({
    List<BookmarkEntry>? bookmarks,
    bool? isLoading,
    String? error,
  }) =>
      BookmarkState(
        bookmarks: bookmarks ?? this.bookmarks,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

final bookmarkControllerProvider = StateNotifierProvider.autoDispose<
    BookmarkController, AsyncValue<BookmarkState>>((ref) {
  final bookId = ref.watch(currentBookIdProvider);
  final repo = ref.watch(bookmarkRepositoryProvider);
  return BookmarkController(bookId: bookId, repository: repo);
});

/// Subscribes to [BookmarkRepository.watchForBook] for the current book and
/// exposes add / updateLabel / updateNote / delete mutations.
class BookmarkController extends StateNotifier<AsyncValue<BookmarkState>> {
  final String? bookId;
  final BookmarkRepository repository;
  StreamSubscription<List<BookmarkEntry>>? _sub;
  static const _uuid = Uuid();

  BookmarkController({required this.bookId, required this.repository})
      : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    if (bookId == null) {
      state = const AsyncValue.data(BookmarkState());
      return;
    }
    try {
      _sub = repository.watchForBook(bookId!).listen(
        (bookmarks) {
          if (!mounted) return;
          final current = state.value ?? const BookmarkState();
          state = AsyncValue.data(
            current.copyWith(bookmarks: bookmarks, isLoading: false),
          );
        },
        onError: (Object e, StackTrace st) {
          state = AsyncValue.error(e, st);
        },
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> add({
    required String label,
    required Locator locator,
    String? note,
  }) async {
    if (bookId == null) return;
    final now = DateTime.now();
    await repository.add(BookmarkEntry(
      id: _uuid.v4(),
      bookId: bookId!,
      locatorJson: jsonEncode(locator.toJson()),
      label: label,
      note: note,
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> updateLabel(String id, String label) async {
    await repository.updateLabel(id: id, label: label);
  }

  Future<void> updateNote(String id, String? note) async {
    await repository.updateNote(id: id, note: note);
  }

  Future<void> delete(String id) async {
    await repository.delete(id);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
