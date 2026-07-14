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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zhiyue/core/app_providers.dart';
import 'package:zhiyue/data/local/daos/qa_history_dao.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/ai/providers/qa_controller.dart';
import 'package:zhiyue/features/ai/widgets/qa_ask_dialog.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';
import 'package:zhiyue/services/ai/book_qa_service.dart';
import 'package:zhiyue/services/ai/qa_citation_parser.dart';

class _FakeQaHistoryDao implements QaHistoryDaoLike {
  _FakeQaHistoryDao(this._rows);
  final List<QaHistoryEntry> _rows;
  int deleteCalls = 0;

  @override
  Future<List<QaHistoryEntry>> getByBook(String bookId,
          {int limit = 50}) async =>
      _rows.take(limit).toList(growable: false);

  @override
  Future<QaHistoryEntry?> findSameQuestion(
          String bookId, String question) async =>
      null;

  @override
  Future<String> insert({
    required String bookId,
    required String question,
    required String answer,
    required List<int> citations,
    DateTime? createdAt,
  }) async =>
      'new-id';

  @override
  Future<int> deleteEntry(String id) async {
    deleteCalls += 1;
    _rows.removeWhere((r) => r.id == id);
    return 1;
  }

  @override
  Future<int> clearForBook(String bookId) async => 0;
}

class _NoOpService implements BookQaServiceLike {
  @override
  Stream<QaEvent> ask({required Book book, required String question}) =>
      const Stream.empty();
}

class _CountingQaController extends QaController {
  _CountingQaController() : super(_NoOpService());
  String? askedQuestion;
  @override
  void ask({required Book book, required String question}) {
    askedQuestion = question;
  }
}

Book _book() => Book(
      id: 'b1',
      title: 't',
      author: null,
      format: BookFormat.epub,
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 1,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
      coverPath: null,
    );

QaHistoryEntry _entry(String id, String q) => QaHistoryEntry(
      id: id,
      bookId: 'b1',
      question: q,
      answer: 'a',
      citations: const [],
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets('QaAskDialog renders history list above the input',
      (tester) async {
    final history = _FakeQaHistoryDao([
      _entry('h1', '主角是谁？'),
      _entry('h2', '结局如何？'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          qaControllerProvider('b1').overrideWith(
            (ref) => _CountingQaController(),
          ),
          qaHistoryDaoProvider.overrideWith((ref) => history),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: QaAskDialog(bookId: 'b1', book: _book()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('最近提问'), findsOneWidget);
    expect(find.text('主角是谁？'), findsOneWidget);
    expect(find.text('结局如何？'), findsOneWidget);
  });

  testWidgets('tapping a history entry fills the input and submits',
      (tester) async {
    final history = _FakeQaHistoryDao([_entry('h1', '主角是谁？')]);
    final qa = _CountingQaController()
      ..state = const QaState(status: QaStatus.idle);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          qaControllerProvider('b1').overrideWith((ref) => qa),
          qaHistoryDaoProvider.overrideWith((ref) => history),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: QaAskDialog(bookId: 'b1', book: _book()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('主角是谁？'));
    await tester.pump();

    expect(qa.askedQuestion, '主角是谁？');
  });

  testWidgets('long-press deletes the entry and shows SnackBar',
      (tester) async {
    final history = _FakeQaHistoryDao([_entry('h1', '主角是谁？')]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          qaControllerProvider('b1').overrideWith(
            (ref) => _CountingQaController(),
          ),
          qaHistoryDaoProvider.overrideWith((ref) => history),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: QaAskDialog(bookId: 'b1', book: _book()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('主角是谁？'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('已删除'), findsOneWidget);
    expect(history.deleteCalls, 1);
  });
}
