import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/widgets/loading_view.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/ai/providers/qa_controller.dart';
import 'package:zhiyue/features/ai/widgets/qa_ask_dialog.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';
import 'package:zhiyue/services/ai/book_qa_service.dart';

class _NoOpService implements BookQaServiceLike {
  @override
  Stream<QaEvent> ask({required Book book, required String question}) =>
      const Stream.empty();
}

class _LoadingQaController extends QaController {
  _LoadingQaController() : super(_NoOpService()) {
    state = const QaState(status: QaStatus.loading);
  }
}

Book _book() => Book(
      id: 'b1',
      title: '测试书',
      author: null,
      format: BookFormat.epub,
      filePath: 'p',
      fileHash: 'h',
      fileSizeBytes: 1,
      addedAt: DateTime(2026, 1, 1),
      lastReadAt: null,
      coverPath: null,
      sortOrder: 0,
    );

void main() {
  testWidgets(
      'qa_ask_dialog_renders LoadingView while QaController is loading',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          qaControllerProvider('b1').overrideWith((ref) => _LoadingQaController()),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: QaAskDialog(bookId: 'b1', book: _book()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LoadingView), findsOneWidget);
  });
}
