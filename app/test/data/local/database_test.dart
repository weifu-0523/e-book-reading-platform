import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/database.dart';

import '../../helpers/drift_test_helper.dart';

void main() {
  test('database can be created and closed', () async {
    final db = createTestDatabase();
    expect(db, isNotNull);
    await db.close();
  });

  test('database version is 1', () {
    final db = createTestDatabase();
    expect(db.schemaVersion, 1);
    db.close();
  });
}
