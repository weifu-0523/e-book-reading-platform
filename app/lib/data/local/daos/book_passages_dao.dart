import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/book_passages.dart';

part 'book_passages_dao.g.dart';

@DriftAccessor(tables: [BookPassages])
class BookPassagesDao extends DatabaseAccessor<AppDatabase>
    with _$BookPassagesDaoMixin {
  BookPassagesDao(super.db);
}
