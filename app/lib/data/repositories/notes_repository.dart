import '../models/annotation.dart';
import '../models/book_note.dart';

abstract class NotesRepository {
  Future<BookNote?> getNoteByBook(String bookId);
  Future<BookNote> createEmptyNote({
    required String id,
    required String bookId,
    required String bookTitle,
  });
  Future<void> updateNote(BookNote note);
  Future<List<Annotation>> listAnnotations(String noteId);
  Future<void> addAnnotation(Annotation annotation);
  Future<void> updateAnnotation(Annotation annotation);
  Future<void> deleteAnnotation(String id);
  Future<List<Annotation>> searchAnnotations(
    String query, {
    List<String>? tags,
  });
}
