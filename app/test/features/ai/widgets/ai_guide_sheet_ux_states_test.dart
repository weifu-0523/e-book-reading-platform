import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zhiyue/core/widgets/loading_view.dart';
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
  testWidgets(
      'ai_guide_sheet_renders LoadingView with extract caption while loading',
      (tester) async {
    await tester.pumpWidget(_wrap(
      AiGuideSheet(book: _book(), initialMode: AiGuideMode.full),
      [
        aiGuideControllerProvider.overrideWith((ref) => _LoadingController()),
      ],
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.text('正在提取文本…'), findsOneWidget);
  });
}

/// Base for stub controllers: build with a real-but-inert [AiGuide] (its
/// dependencies are never invoked because every start* method is overridden),
/// then overwrite the state in the constructor body.
abstract class _StubController extends AiGuideController {
  _StubController(AiStreamState initial) : super(_InertGuide()) {
    state = initial;
  }

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
