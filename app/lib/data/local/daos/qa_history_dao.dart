import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/qa_history.dart';

part 'qa_history_dao.g.dart';

@DriftAccessor(tables: [QaHistory])
class QaHistoryDao extends DatabaseAccessor<AppDatabase>
    with _$QaHistoryDaoMixin {
  QaHistoryDao(super.db);
}
