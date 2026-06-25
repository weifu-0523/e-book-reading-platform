import 'dart:convert';

import '../../core/locator.dart';
import '../local/database.dart' as db;
import '../local/daos/annotations_dao.dart';
import '../local/daos/book_notes_dao.dart';
import '../models/annotation.dart';
import '../models/book_note.dart';
import 'notes_repository.dart';

class LocalNotesRepository implements NotesRepository {
  final BookNotesDao _notesDao;
  final AnnotationsDao _annotationsDao;

  LocalNotesRepository(db.AppDatabase database)
      : _notesDao = BookNotesDao(database),
        _annotationsDao = AnnotationsDao(database);

  @override
  Future<BookNote?> getNoteByBook(String bookId) async {
    final row = await _notesDao.getByBookId(bookId);
    if (row == null) return null;
    final annotations = await listAnnotations(row.id);
    return BookNote(
      id: row.id,
      bookId: row.bookId,
      title: row.title,
      summary: row.summary,
      keyTakeaways: _decodeStringList(row.keyTakeaways),
      annotations: annotations,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<BookNote> createEmptyNote({
    required String id,
    required String bookId,
    required String bookTitle,
  }) async {
    final note = BookNote.empty(id: id, bookId: bookId, bookTitle: bookTitle);
    await _notesDao.insertOne(id: id, bookId: bookId, title: note.title);
    return note;
  }

  @override
  Future<void> updateNote(BookNote note) {
    return _notesDao.updateContent(
      note.id,
      summary: note.summary,
      keyTakeawaysJson: jsonEncode(note.keyTakeaways.toList()),
    );
  }

  @override
  Future<List<Annotation>> listAnnotations(String noteId) async {
    final rows = await _annotationsDao.getByBookNoteId(noteId);
    return rows.map(_toAnnotationModel).toList();
  }

  @override
  Future<void> addAnnotation(Annotation a) {
    return _annotationsDao.insertOne(
      id: a.id,
      bookNoteId: a.bookNoteId,
      locatorJson: jsonEncode(a.locator.toJson()),
      quote: a.quote,
      note: a.note,
      color: _colorToString(a.color),
      tagsJson: jsonEncode(a.tags.toList()),
      source: a.source == AnnotationSource.manual ? 'manual' : 'aiAssisted',
    );
  }

  @override
  Future<void> updateAnnotation(Annotation a) async {
    // 简单实现：delete + insert。生产可改为 update。
    await _annotationsDao.deleteAnnotation(a.id);
    await addAnnotation(a);
  }

  @override
  Future<void> deleteAnnotation(String id) =>
      _annotationsDao.deleteAnnotation(id);

  @override
  Future<List<Annotation>> searchAnnotations(
    String query, {
    List<String>? tags,
  }) async {
    // M1 简单实现：FTS5 全文搜索留待 M6（笔记库 UI 阶段）实现。
    return <Annotation>[];
  }

  // ====== 私有 helpers ======

  Annotation _toAnnotationModel(db.Annotation row) {
    return Annotation(
      id: row.id,
      bookNoteId: row.bookNoteId,
      locator: Locator.fromJson(
        jsonDecode(row.locator) as Map<String, dynamic>,
      ),
      quote: row.quote,
      note: row.note,
      color: _colorFromString(row.color),
      tags: _decodeStringList(row.tags),
      source: row.source == 'aiAssisted'
          ? AnnotationSource.aiAssisted
          : AnnotationSource.manual,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  String _colorToString(HighlightColor c) {
    switch (c) {
      case HighlightColor.yellow:
        return 'yellow';
      case HighlightColor.green:
        return 'green';
      case HighlightColor.blue:
        return 'blue';
      case HighlightColor.red:
        return 'red';
      case HighlightColor.purple:
        return 'purple';
    }
  }

  HighlightColor _colorFromString(String s) {
    return HighlightColor.values.firstWhere(
      (c) => _colorToString(c) == s,
      orElse: () => HighlightColor.yellow,
    );
  }

  List<String> _decodeStringList(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list.cast<String>();
  }
}
