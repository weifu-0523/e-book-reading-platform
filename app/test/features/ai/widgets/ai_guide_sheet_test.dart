import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zhiyue/data/local/daos/ai_summaries_dao.dart';
import 'package:zhiyue/data/models/book.dart';
import 'package:zhiyue/features/ai/providers/ai_guide_controller.dart';
import 'package:zhiyue/features/ai/widgets/ai_guide_sheet.dart';
import 'package:zhiyue/gen_l10n/app_localizations.dart';
import 'package:zhiyue/services/ai/ai_guide.dart';
import 'package:zhiyue/services/ai/api_key_store.dart';
import 'package:zhiyue/services/ai/book_text_extractor.dart';
import 'package:zhiyue/services/ai/chapter_text_provider.dart';

Book _book() => Book(
      id: 'b1',
      title: 'T',
      format: BookFormat.epub,
      filePath: '/p',
      fileHash: 'h',
      fileSizeBytes: 1,
      author: null,
      coverPath: null,
      lastReadAt: null,
      addedAt: DateTime(2026, 1, 1),
    );

Widget _wrap(Widget child, List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('renders 3 mode ToggleButtons + title in idle state',
      (tester) async {
    await tester.pumpWidget(_wrap(
      AiGuideSheet(book: _book(), initialMode: AiGuideMode.full),
      [aiGuideControllerProvider.overrideWith((ref) => _NoopController())],
    ));
    await tester.pump();
    expect(find.text('全书'), findsOneWidget);
    expect(find.text('本章'), findsOneWidget);
    expect(find.text('选区'), findsOneWidget);
    expect(find.text('AI 导读'), findsOneWidget);
  });

  testWidgets('renders loading indicator + extract label when loading',
      (tester) async {
    await tester.pumpWidget(_wrap(
      AiGuideSheet(book: _book(), initialMode: AiGuideMode.full),
      [
        aiGuideControllerProvider.overrideWith((ref) => _LoadingController()),
      ],
    ));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('正在提取文本…'), findsOneWidget);
  });

  testWidgets('error state: noApiKey shows go-to-settings button',
      (tester) async {
    await tester.pumpWidget(_wrap(
      AiGuideSheet(book: _book(), initialMode: AiGuideMode.full),
      [
        aiGuideControllerProvider.overrideWith(
            (ref) => _ErrorController(AiGuideError.noApiKey)),
      ],
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('未配置 API key，请到设置页填入。'), findsOneWidget);
    expect(find.text('去设置'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
  });

  testWidgets('error state: network shows retry button', (tester) async {
    await tester.pumpWidget(_wrap(
      AiGuideSheet(book: _book(), initialMode: AiGuideMode.full),
      [
        aiGuideControllerProvider.overrideWith(
            (ref) => _ErrorController(AiGuideError.network)),
      ],
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('去设置'), findsNothing);
  });

  testWidgets('error state: emptySource renders neither button',
      (tester) async {
    await tester.pumpWidget(_wrap(
      AiGuideSheet(book: _book(), initialMode: AiGuideMode.full),
      [
        aiGuideControllerProvider.overrideWith(
            (ref) => _ErrorController(AiGuideError.emptySource)),
      ],
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('去设置'), findsNothing);
    expect(find.text('重试'), findsNothing);
  });

  testWidgets('chapter done state parses bullets + KeyTakeawayActions',
      (tester) async {
    await tester.pumpWidget(_wrap(
      AiGuideSheet(
        book: _book(),
        initialMode: AiGuideMode.chapter,
        chapterIndex: 0,
        chapterTitle: 'Ch1',
      ),
      [
        aiGuideControllerProvider.overrideWith(
            (ref) => _ChapterDoneController()),
      ],
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('核心要点一'), findsOneWidget);
    expect(find.byTooltip('加入笔记'), findsOneWidget);
  });

  testWidgets('modeLocked disables the toggle', (tester) async {
    await tester.pumpWidget(_wrap(
      AiGuideSheet(
        book: _book(),
        initialMode: AiGuideMode.chapter,
        modeLocked: true,
      ),
      [aiGuideControllerProvider.overrideWith((ref) => _NoopController())],
    ));
    await tester.pump();
    final toggle = tester.widget<ToggleButtons>(find.byType(ToggleButtons));
    expect(toggle.onPressed, isNull);
  });
}

/// Base for stub controllers: build with a real-but-inert [AiGuide] (its
/// dependencies are never invoked because every start* method is overridden),
/// then overwrite the state in the constructor body.
abstract class _StubController extends AiGuideController {
  _StubController(AiStreamState initial) : super(_InertGuide()) {
    state = initial;
  }

  // All start* methods are no-ops: the test drives state purely via the
  // constructor. This ensures the sheet's post-frame _kickoff() callback
  // does not stomp on the pre-seeded state.
  @override
  Future<void> startFullBook(Book book) async {}
  @override
  Future<void> startChapter(Book b, int i, {String? chapterTitle}) async {}
  @override
  Future<void> startSelection(Book b, String s, {String? chapterTitle}) async {}
}

class _NoopController extends AiGuideController {
  _NoopController() : super(_InertGuide());
  @override
  Future<void> startFullBook(Book book) async {}
  @override
  Future<void> startChapter(Book b, int i, {String? chapterTitle}) async {}
  @override
  Future<void> startSelection(Book b, String s, {String? chapterTitle}) async {}
}

class _LoadingController extends _StubController {
  _LoadingController()
      : super(const AiStreamState(
            status: AiGuideStatus.loading, mode: AiGuideMode.full));
}

class _ErrorController extends _StubController {
  _ErrorController(AiGuideError e)
      : super(AiStreamState(
            status: AiGuideStatus.error, mode: AiGuideMode.full, error: e));
}

class _ChapterDoneController extends _StubController {
  _ChapterDoneController()
      : super(const AiStreamState(
          status: AiGuideStatus.done,
          mode: AiGuideMode.chapter,
          accumulatedText: '本章摘要\n- 核心要点一',
        ));
}

/// A real [AiGuide] that is never actually run — its dependencies stub
/// everything via [noSuchMethod] so we don't need a drift AppDatabase.
class _InertGuide extends AiGuide {
  _InertGuide()
      : super(
          apiKeys: _NoopKeys(),
          extractorFor: (_) => _NoopExtractor(),
          chapterTextProviderFor: (_) => _NoopChapter(),
          cache: _NoopCache(),
        );
}

class _NoopKeys implements ApiKeyStoreLike {
  @override
  Future<AiCredentials?> load() async => null;
}

class _NoopExtractor implements BookTextExtractor {
  @override
  Future<String> extract(Book b) async => '';
}

class _NoopChapter implements ChapterTextProvider {
  @override
  Future<String?> get(String p, int i) async => null;
  @override
  Future<String?> title(String p, int i) async => null;
  @override
  Future<int> count(String filePath) async => 0;
}

class _NoopCache implements AiSummariesDao {
  @override
  dynamic noSuchMethod(Invocation inv) => super.noSuchMethod(inv);
}
