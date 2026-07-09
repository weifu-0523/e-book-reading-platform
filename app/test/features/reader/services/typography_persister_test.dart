// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:zhiyue/data/repositories/book_typography_repository.dart';

import 'package:zhiyue/features/reader/services/typography_persister.dart';

/// In-memory fake repository. Records every saveForBook call.
class _RecordingRepo implements BookTypographyRepository {
  final List<({String bookId, TypographySettings settings})> saves = [];

  @override
  Future<TypographySettings?> getForBook(String bookId) async => null;

  @override
  Future<void> saveForBook(String bookId, TypographySettings settings) async {
    saves.add((bookId: bookId, settings: settings));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  group('TypographyPersister', () {
    test('T1.1 debounces rapid changes — only last value persisted',
        () async {
      final repo = _RecordingRepo();
      final controller = StreamController<ReaderEngineState>();
      final persister = TypographyPersister(
        bookId: 'b1',
        repository: repo,
        stateSource: controller.stream,
        typographyGetter: () => TypographySettings.defaults(),
        debounceMs: 50,
      )..start();

      // Emit 3 state changes in rapid succession (within debounce window).
      controller
        ..add(const ReaderEngineReady())
        ..add(const ReaderEngineReady())
        ..add(const ReaderEngineReady());

      // Wait beyond debounce window.
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(repo.saves, hasLength(1));
      expect(repo.saves.first.bookId, 'b1');
      expect(repo.saves.first.settings, TypographySettings.defaults());

      persister.dispose();
      await controller.close();
    });

    test('T1.2 distinct — same typography skipped, no save', () async {
      final repo = _RecordingRepo();
      final controller = StreamController<ReaderEngineState>();
      final settings = TypographySettings.defaults();
      final persister = TypographyPersister(
        bookId: 'b1',
        repository: repo,
        stateSource: controller.stream,
        typographyGetter: () => settings,
        debounceMs: 50,
      )..start();

      // First emit → save.
      controller.add(const ReaderEngineReady());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(repo.saves, hasLength(1));

      // Second emit with same typography value → no save.
      controller.add(const ReaderEngineReady());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(repo.saves, hasLength(1));

      persister.dispose();
      await controller.close();
    });

    test('T1.3 changing typography value triggers save', () async {
      final repo = _RecordingRepo();
      final controller = StreamController<ReaderEngineState>();
      var current = TypographySettings.defaults();
      final persister = TypographyPersister(
        bookId: 'b1',
        repository: repo,
        stateSource: controller.stream,
        typographyGetter: () => current,
        debounceMs: 50,
      )..start();

      // First emit → save defaults.
      controller.add(const ReaderEngineReady());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(repo.saves, hasLength(1));
      expect(repo.saves.first.settings.fontSize, 18.0);

      // Change typography and emit again.
      current = current.copyWith(fontSize: 24.0);
      controller.add(const ReaderEngineReady());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(repo.saves, hasLength(2));
      expect(repo.saves.last.settings.fontSize, 24.0);

      persister.dispose();
      await controller.close();
    });

    test('T1.4 dispose cancels pending debounce — no save after dispose',
        () async {
      final repo = _RecordingRepo();
      final controller = StreamController<ReaderEngineState>();
      final persister = TypographyPersister(
        bookId: 'b1',
        repository: repo,
        stateSource: controller.stream,
        typographyGetter: () => TypographySettings.defaults(),
        debounceMs: 50,
      )..start();

      // Emit then immediately dispose (before debounce window elapses).
      controller.add(const ReaderEngineReady());
      persister.dispose();

      // Wait beyond debounce window.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(repo.saves, isEmpty);

      await controller.close();
    });

    test('T1.5 silent failure — repository exception does not throw',
        () async {
      final controller = StreamController<ReaderEngineState>();
      final failingRepo = _FailingBookTypographyRepository();
      final persister = TypographyPersister(
        bookId: 'b1',
        repository: failingRepo,
        stateSource: controller.stream,
        typographyGetter: () => TypographySettings.defaults(),
        debounceMs: 50,
      )..start();

      // Should not throw.
      controller.add(const ReaderEngineReady());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      persister.dispose();
      await controller.close();
    });
  });
}

/// Stub repository that throws on every call. Used only to verify
/// TypographyPersister swallows repository exceptions.
class _FailingBookTypographyRepository implements BookTypographyRepository {
  @override
  Future<TypographySettings?> getForBook(String bookId) async {
    throw StateError('fake db failure');
  }

  @override
  Future<void> saveForBook(String bookId, TypographySettings settings) async {
    throw StateError('fake db failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
