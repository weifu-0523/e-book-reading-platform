import 'dart:async';

import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/data/repositories/notes_repository.dart';

/// In-memory fake [NotesRepository] for tests.
///
/// 反应式语义与 [LocalNotesRepository] 对齐：
/// - `watchAnnotations` 在 BookNote 不存在时立即 emit 空 list
/// - 每次 add/update/delete 后通过 broadcast controller 通知订阅者
class FakeNotesRepository implements NotesRepository {
  final Map<String, BookNote> _notes = {}; // bookId -> BookNote
  final Map<String, List<Annotation>> _annotationsByNote = {}; // noteId -> list
  final Map<String, StreamController<List<Annotation>>> _controllers = {};

  StreamController<List<Annotation>> _ctlFor(String bookId) {
    return _controllers.putIfAbsent(
      bookId,
      () => StreamController<List<Annotation>>.broadcast(),
    );
  }

  @override
  Stream<List<Annotation>> watchAnnotations(String bookId) async* {
    final note = _notes[bookId];
    yield note == null
        ? const <Annotation>[]
        : List<Annotation>.unmodifiable(
            _annotationsByNote[note.id] ?? const <Annotation>[]);
    yield* _ctlFor(bookId).stream;
  }

  @override
  Future<BookNote?> getNoteByBook(String bookId) async => _notes[bookId];

  @override
  Future<BookNote> createEmptyNote({
    required String id,
    required String bookId,
    required String bookTitle,
  }) async {
    final n = BookNote.empty(id: id, bookId: bookId, bookTitle: bookTitle);
    _notes[bookId] = n;
    _annotationsByNote[id] = [];
    return n;
  }

  @override
  Future<void> updateNote(BookNote note) async {
    _notes[note.bookId] = note;
  }

  @override
  Future<List<Annotation>> listAnnotations(String noteId) async =>
      List<Annotation>.unmodifiable(
        _annotationsByNote[noteId] ?? const <Annotation>[],
      );

  @override
  Future<void> addAnnotation(Annotation a) async {
    (_annotationsByNote[a.bookNoteId] ??= <Annotation>[]).add(a);
    _emitForNote(a.bookNoteId);
  }

  @override
  Future<void> updateAnnotation(Annotation a) async {
    final list = _annotationsByNote[a.bookNoteId] ?? <Annotation>[];
    final idx = list.indexWhere((x) => x.id == a.id);
    if (idx >= 0) list[idx] = a;
    _emitForNote(a.bookNoteId);
  }

  @override
  Future<void> deleteAnnotation(String id) async {
    String? noteId;
    for (final entry in _annotationsByNote.entries) {
      if (entry.value.any((a) => a.id == id)) {
        noteId = entry.key;
        break;
      }
    }
    if (noteId == null) return;
    _annotationsByNote[noteId]!.removeWhere((a) => a.id == id);
    _emitForNote(noteId);
  }

  @override
  Future<List<Annotation>> searchAnnotations(
    String query, {
    List<String>? tags,
    HighlightColor? color,
  }) async {
    final all = _annotationsByNote.values.expand((l) => l).toList();
    var filtered = query.isEmpty
        ? all
        : all
            .where((a) =>
                a.quote.contains(query) || (a.note?.contains(query) ?? false))
            .toList();
    if (color != null) {
      filtered = filtered.where((a) => a.color == color).toList();
    }
    if (tags != null && tags.isNotEmpty) {
      filtered = filtered.where((a) => tags.every(a.tags.contains)).toList();
    }
    return filtered;
  }

  void _emitForNote(String noteId) {
    String? bookId;
    for (final entry in _notes.entries) {
      if (entry.value.id == noteId) {
        bookId = entry.key;
        break;
      }
    }
    if (bookId == null) return;
    _ctlFor(bookId).add(
      List<Annotation>.unmodifiable(_annotationsByNote[noteId] ?? const []),
    );
  }
}
