import 'dart:async';

import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/data/models/book_note.dart';
import 'package:zhiyue/data/repositories/notes_repository.dart';

/// In-memory fake [NotesRepository] for tests.
///
/// 反应式语义与 [LocalNotesRepository] 对齐：
/// - `watchAnnotations` 在 BookNote 不存在时立即 emit 空 list
/// - 每次 add/update/delete 后通过 broadcast controller 通知订阅者
///
/// Test-only knobs:
/// - [searchError]: when non-null, [searchAnnotations] throws synchronously,
///   exercising the consumer's error-state rendering.
/// - [searchAnnotationsCompleter]: when non-null, [searchAnnotations] awaits
///   this completer before resolving, letting tests pump the loading frame.
class FakeNotesRepository implements NotesRepository {
  FakeNotesRepository({this.searchError, this.searchAnnotationsCompleter});

  /// When non-null, [searchAnnotations] throws this synchronously.
  final Object? searchError;

  /// When non-null, [searchAnnotations] awaits this completer.
  final Completer<List<Annotation>>? searchAnnotationsCompleter;

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

  /// 测试辅助：直接放入 [bookId] → [BookNote] 映射，避免每个测试都要走 async save。
  void setNote(String bookId, BookNote note) {
    _notes[bookId] = note;
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
    if (searchError != null) throw searchError!;
    if (searchAnnotationsCompleter != null) {
      return searchAnnotationsCompleter!.future;
    }
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

  @override
  Future<void> applyChapterReview({
    required String bookId,
    required String bookTitle,
    required int chapterIndex,
    required String? chapterTitle,
    required String summary,
    required List<String> keyTakeaways,
  }) async {
    var note = _notes[bookId];
    note ??= await createEmptyNote(
      id: 'note_$bookId',
      bookId: bookId,
      bookTitle: bookTitle,
    );

    final ordinal = chapterIndex + 1;
    final prefix = '【第$ordinal章】 ';
    final sentinelStart = '## 第 $ordinal 章';
    final sentinelTitle = (chapterTitle == null || chapterTitle.isEmpty)
        ? sentinelStart
        : '$sentinelStart · $chapterTitle';

    final existingTakeaways =
        note.keyTakeaways.where((t) => !t.startsWith(prefix)).toList();
    final newTakeaways = keyTakeaways.map((t) => '$prefix$t').toList();
    final mergedTakeaways = [...existingTakeaways, ...newTakeaways];

    final cleanedSummary = _stripChapterSection(note.summary, sentinelStart);
    final newSection = StringBuffer()
      ..writeln(sentinelTitle)
      ..writeln()
      ..writeln(summary)
      ..writeln();
    final mergedSummary = cleanedSummary.isEmpty
        ? newSection.toString()
        : '${cleanedSummary.trimRight()}\n\n$newSection';

    _notes[bookId] = note.copyWith(
      summary: mergedSummary,
      keyTakeaways: mergedTakeaways,
      updatedAt: DateTime.now(),
    );
  }

  /// 与 LocalNotesRepository._stripChapterSection 相同的语义。
  String _stripChapterSection(String summary, String sentinelStart) {
    if (sentinelStart.isEmpty) return summary;
    if (!summary.contains(sentinelStart)) return summary;
    final sections = <String>[];
    final lines = summary.split('\n');
    var skipping = false;
    for (final line in lines) {
      if (line.startsWith('## ')) {
        skipping = line.startsWith(sentinelStart);
        if (!skipping) sections.add(line);
        continue;
      }
      if (!skipping) sections.add(line);
    }
    return sections.join('\n');
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
