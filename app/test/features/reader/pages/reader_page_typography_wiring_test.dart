// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:zhiyue/data/repositories/book_typography_repository.dart';

import 'package:zhiyue/features/reader/services/typography_persister.dart';

/// T5 wiring smoke test.
///
/// T1 covers `TypographyPersister` in isolation with a plain `StreamController`
/// as the state source. T3.2 covers load-on-open in isolation. Neither
/// verifies the contract that `ReaderEngine.setTypography` actually emits on
/// `state$` — if a renderer (e.g. PdfRenderer pre-fix, or a future engine
/// impl) forgets to emit, the persister silently never fires and typography
/// changes are lost on close.
///
/// This test mirrors `reader_page._ensureTypographyPersister` wiring with a
/// controllable fake engine: setTypography mutates the getter AND emits
/// `ReaderEngineReady`, exactly like `EpubxRenderer.setTypography` and the
/// fixed `PdfRenderer.setTypography`. The round-trip (subscribe → emit →
/// save → dispose → new persister with same repo → load applied) must work.

class _RecordingRepo implements BookTypographyRepository {
  final List<({String bookId, TypographySettings settings})> saves = [];
  TypographySettings? getForBookReturnValue;

  @override
  Future<TypographySettings?> getForBook(String bookId) async =>
      getForBookReturnValue;

  @override
  Future<void> saveForBook(String bookId, TypographySettings settings) async {
    saves.add((bookId: bookId, settings: settings));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fake engine that mirrors the setTypography→state$ emit contract.
///
/// Mirrors `EpubxRenderer.setTypography` (epubx_renderer.dart:950-959) and
/// the fixed `PdfRenderer.setTypography` (pdf_renderer.dart:511-522): the
/// method updates the typography field AND emits `ReaderEngineReady` on the
/// state stream. If a renderer breaks this contract, this fake still passes
/// (it's the contract reference) — but the renderer's own tests should catch
/// the missing emit. Here we only verify the persister wiring assumes the
/// contract holds.
class _FakeControllableEngine {
  _FakeControllableEngine()
      : typography = TypographySettings.defaults();

  late TypographySettings typography;
  final StreamController<ReaderEngineState> _stateController =
      StreamController<ReaderEngineState>.broadcast();

  Stream<ReaderEngineState> get state$ => _stateController.stream;

  Future<void> setTypography(TypographySettings settings) async {
    typography = settings;
    _stateController.add(const ReaderEngineReady());
  }

  Future<void> close() => _stateController.close();
}

void main() {
  group('T5 typography wiring', () {
    test('T5.1 TypographyPersister round-trip with fake engine', () async {
      final repo = _RecordingRepo()..getForBookReturnValue = null;
      final engine = _FakeControllableEngine();

      // Wire persister manually (mirrors reader_page._ensureTypographyPersister).
      final persister = TypographyPersister(
        bookId: 'b1',
        repository: repo,
        stateSource: engine.state$,
        typographyGetter: () => engine.typography,
        debounceMs: 50,
      )..start();

      // Simulate user changing font size. setTypography must emit on state$
      // for the persister to fire — this is the contract under test.
      await engine.setTypography(
          TypographySettings.defaults().copyWith(fontSize: 24.0));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(repo.saves, hasLength(1));
      expect(repo.saves.first.bookId, 'b1');
      expect(repo.saves.first.settings.fontSize, 24.0);

      persister.dispose();
      await engine.close();
    });

    test('T5.2 round-trip: saved settings re-apply to a fresh engine',
        () async {
      // Phase 1: persister saves a non-default typography to repo.
      final repo = _RecordingRepo();
      final engine1 = _FakeControllableEngine();
      final persister1 = TypographyPersister(
        bookId: 'b1',
        repository: repo,
        stateSource: engine1.state$,
        typographyGetter: () => engine1.typography,
        debounceMs: 50,
      )..start();

      await engine1.setTypography(
          TypographySettings.defaults().copyWith(fontSize: 22.0));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(repo.saves, hasLength(1));

      persister1.dispose();
      await engine1.close();

      // Phase 2: simulate reader_page._applyPersistedTypography on next open.
      // The repo now holds the saved settings; a fresh engine should receive
      // them via setTypography. This is the round-trip the persistence
      // feature promises the user.
      repo.getForBookReturnValue = repo.saves.first.settings;
      final engine2 = _FakeControllableEngine();
      final saved = await repo.getForBook('b1');
      expect(saved, isNotNull);
      expect(saved!.fontSize, 22.0);

      await engine2.setTypography(saved);
      expect(engine2.typography.fontSize, 22.0);

      await engine2.close();
    });

    test('T5.3 distinct typography values do not double-save', () async {
      final repo = _RecordingRepo();
      final engine = _FakeControllableEngine();

      final persister = TypographyPersister(
        bookId: 'b1',
        repository: repo,
        stateSource: engine.state$,
        typographyGetter: () => engine.typography,
        debounceMs: 50,
      )..start();

      // First change → save.
      await engine.setTypography(
          TypographySettings.defaults().copyWith(fontSize: 20.0));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(repo.saves, hasLength(1));

      // Re-emit the SAME typography (e.g. user opens panel but doesn't change
      // anything, then engine re-emits ready). Persister's distinct check
      // should skip the save.
      await engine.setTypography(
          TypographySettings.defaults().copyWith(fontSize: 20.0));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(repo.saves, hasLength(1));

      persister.dispose();
      await engine.close();
    });
  });
}
