import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine_epub_view/cfi_codec.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

/// Regression test for the M3.5 refactor that replaced
/// `chapterRevisionNotifier` (a `ValueNotifier<int>`) with
/// `chapterSwitchSettled` (a `Future<void>`).
///
/// Contract being verified:
/// 1. With no switch in progress, `chapterSwitchSettled` returns an
///    already-completed Future.
/// 2. After `setChapter` / cross-chapter `gotoLocator`, a Future returned
///    by `chapterSwitchSettled` completes once the framework has run a
///    frame (the post-frame callback that completes the internal Completer
///    fires during the frame).
///
/// Test framework quirk: after `pumpWidget` + intermediate `pump()` calls,
/// `tester.pump()` no longer auto-schedules a frame. We must call
/// `tester.binding.scheduleFrame()` before pumping to drain the post-frame
/// callback queued by `_beginChapterSwitch`.
///
/// Note: deeper "await blocks until settled" semantics are exercised
/// indirectly via the reader_page integration tests, which pump frames
/// naturally while navigating.
void main() {
  test(
      'chapterSwitchSettled completes immediately when no switch in progress',
      () async {
    final renderer = EpubxRenderer();
    // No switch has begun — getter returns an already-completed future.
    await renderer.chapterSwitchSettled;
    expect(renderer.currentChapterIndex, 0);
    await renderer.dispose();
  });

  test('chapterSwitchSettled returns a fresh completed Future each call '
      'when idle (no leaked pending state)', () async {
    final renderer = EpubxRenderer();
    // Repeated reads should all complete promptly.
    await renderer.chapterSwitchSettled;
    await renderer.chapterSwitchSettled;
    await renderer.chapterSwitchSettled;
    expect(renderer.currentChapterIndex, 0);
    await renderer.dispose();
  });

  testWidgets(
    'setChapter arms a completer that resolves after a scheduled frame',
    (tester) async {
      final renderer = EpubxRenderer();
      // Two-chapter book.
      renderer.bookForTesting = EpubBook()
        ..Title = 'T'
        ..Chapters = [
          EpubChapter()
            ..Title = 'C1'
            ..HtmlContent = '<p>one</p>',
          EpubChapter()
            ..Title = 'C2'
            ..HtmlContent = '<p>two</p>',
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: Builder(builder: (ctx) => renderer.build(ctx)),
            ),
          ),
        ),
      );
      // Drain the initial frame and the post-frame callback queued by
      // `bookForTesting`'s `_beginChapterSwitch`.
      await tester.pump();

      // Probe non-blockingly.
      var completed = false;
      renderer.setChapter(1);
      expect(renderer.currentChapterIndex, 1);
      // ignore: unawaited_futures
      renderer.chapterSwitchSettled.whenComplete(() => completed = true);

      // scheduleFrame() is required: after pumpWidget+pump, the framework
      // won't run another frame unless explicitly asked. Without this, the
      // post-frame callback queued by `_beginChapterSwitch` would never fire.
      tester.binding.scheduleFrame();
      await tester.pump();
      // Second pump drains the microtask queued by `.whenComplete`.
      tester.binding.scheduleFrame();
      await tester.pump();
      expect(completed, isTrue);

      await renderer.dispose();
    },
  );

  testWidgets(
    'cross-chapter gotoLocator arms the completer',
    (tester) async {
      final renderer = EpubxRenderer();
      renderer.bookForTesting = EpubBook()
        ..Title = 'T'
        ..Chapters = [
          EpubChapter()
            ..Title = 'C1'
            ..HtmlContent = '<p>one</p>',
          EpubChapter()
            ..Title = 'C2'
            ..HtmlContent = '<p>two</p>',
        ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: Builder(builder: (ctx) => renderer.build(ctx)),
            ),
          ),
        ),
      );
      await tester.pump();

      var completed = false;
      final loc = EpubCfiLocator(cfi: encode(1, 0), chapterIndex: 1);
      await renderer.gotoLocator(loc);
      expect(renderer.currentChapterIndex, 1);
      // ignore: unawaited_futures
      renderer.chapterSwitchSettled.whenComplete(() => completed = true);

      tester.binding.scheduleFrame();
      await tester.pump();
      tester.binding.scheduleFrame();
      await tester.pump();
      expect(completed, isTrue);

      await renderer.dispose();
    },
  );
}
