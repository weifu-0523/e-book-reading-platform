import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/annotations.dart';

part 'annotations_dao.g.dart';

@DriftAccessor(tables: [Annotations])
class AnnotationsDao extends DatabaseAccessor<AppDatabase>
    with _$AnnotationsDaoMixin {
  AnnotationsDao(super.db);

  Future<List<Annotation>> getByBookNoteId(String bookNoteId) {
    return (select(annotations)..where((t) => t.bookNoteId.equals(bookNoteId)))
        .get();
  }

  Future<int> insertOne({
    required String id,
    required String bookNoteId,
    required String locatorJson,
    required String quote,
    String? note,
    required String color,
    required String tagsJson,
    required String source,
  }) {
    return into(annotations).insert(
      AnnotationsCompanion.insert(
        id: id,
        bookNoteId: bookNoteId,
        locator: locatorJson,
        quote: quote,
        note: note == null ? const Value.absent() : Value(note),
        color: color,
        tags: Value(tagsJson),
        source: Value(source),
      ),
    );
  }

  Future<int> updateNote(String id, String? note) {
    return (update(annotations)..where((t) => t.id.equals(id))).write(
      AnnotationsCompanion(
        note: note == null ? const Value.absent() : Value(note),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> deleteAnnotation(String id) {
    return (delete(annotations)..where((t) => t.id.equals(id))).go();
  }
}
