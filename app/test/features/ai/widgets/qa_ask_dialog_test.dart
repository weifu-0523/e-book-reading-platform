import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class _FakeQaController extends QaController {
  _FakeQaController() : super(_NoOpService());
  bool asked = false;

  @override
  void ask({required Book book, required String question}) {
    asked = true;
    state = const QaState(
      status: QaStatus.done,
      answer: '这是答案 [ch=3]',
      citations: [3],
    );
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
  testWidgets('QaAskDialog displays question input + submit button',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          qaControllerProvider('b1').overrideWith(
            (ref) => _FakeQaController(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: QaAskDialog(bookId: 'b1', book: _book()),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('提问'), findsOneWidget);
  });

  testWidgets('typing a question and tapping submit invokes ask',
      (tester) async {
    final fake = _FakeQaController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          qaControllerProvider('b1').overrideWith((ref) => fake),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: QaAskDialog(bookId: 'b1', book: _book()),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Who is this?');
    await tester.tap(find.text('提问'));
    await tester.pump();

    expect(fake.asked, isTrue);
  });

  testWidgets('answer renders as Text.rich with tappable [ch=N] citation',
      (tester) async {
    var tappedChapter = -1;
    final fake = _FakeQaController()
      ..state = const QaState(
        status: QaStatus.done,
        answer: '这是答案 [ch=3]',
        citations: [3],
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          qaControllerProvider('b1').overrideWith((ref) => fake),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: QaAskDialog(
            bookId: 'b1',
            onCitationTap: (n) => tappedChapter = n,
          ),
        ),
      ),
    );

    await tester.pump();
    // The answer is rendered as a RichText (QaAnswerView uses RichText
    // directly, not Text widgets), so find.text won't see it. Assert on the
    // RichText's plain text + tap the citation's TapGestureRecognizer.
    final richTexts = tester.widgetList<RichText>(find.byType(RichText));
    final answerRich =
        richTexts.firstWhere((r) => r.text.toPlainText().contains('这是答案'));
    final flat = answerRich.text.toPlainText();
    expect(flat, contains('这是答案'));
    expect(flat, contains('[ch=3]'));

    final spans = (answerRich.text as TextSpan).children ?? const <InlineSpan>[];
    final citeSpan = spans.whereType<TextSpan>().firstWhere(
          (s) => s.text == '[ch=3]' && s.recognizer is TapGestureRecognizer,
        );
    (citeSpan.recognizer as TapGestureRecognizer).onTap!();
    await tester.pump();
    expect(tappedChapter, 3);
  });

  testWidgets('error status renders error message', (tester) async {
    final fake = _FakeQaController()
      ..state = const QaState(
        status: QaStatus.error,
        error: QaError.emptyIndex,
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          qaControllerProvider('b1').overrideWith((ref) => fake),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: QaAskDialog(bookId: 'b1'),
        ),
      ),
    );

    await tester.pump();
    expect(find.textContaining('预处理'), findsWidgets);
  });
}
