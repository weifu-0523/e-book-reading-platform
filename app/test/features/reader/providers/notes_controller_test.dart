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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/core/locator.dart';
import 'package:zhiyue/core/providers.dart';
import 'package:zhiyue/data/models/annotation.dart';
import 'package:zhiyue/features/reader/providers/notes_controller.dart';

import '../../../fakes/fake_notes_repository.dart';

void main() {
  test('addHighlight persists and state emits annotation', () async {
    final fake = FakeNotesRepository();
    final container = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(fake),
      currentBookIdProvider.overrideWith((_) => 'b1'),
    ]);
    addTearDown(container.dispose);
    // Keep provider alive (autoDispose otherwise releases between accesses).
    final sub = container.listen(notesControllerProvider, (_, __) {});
    addTearDown(sub.close);
    final ctrl = container.read(notesControllerProvider.notifier);
    await ctrl.addHighlight(
      const EpubRangeLocator(
          chapterIndex: 0, startOffset: 0, endOffset: 3, quote: 'abc'),
      HighlightColor.yellow,
      'abc',
    );
    await Future.delayed(const Duration(milliseconds: 200));
    container.read(notesControllerProvider).maybeWhen(
      data: (s) => expect(s.annotations, hasLength(1)),
      orElse: () => fail('state should be data'),
    );
  });

  test('state starts empty when bookId is null', () async {
    final fake = FakeNotesRepository();
    final container = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(notesControllerProvider, (_, __) {});
    addTearDown(sub.close);
    await Future.delayed(const Duration(milliseconds: 50));
    container.read(notesControllerProvider).maybeWhen(
      data: (s) {
        expect(s.annotations, isEmpty);
        expect(s.bookNote, isNull);
      },
      loading: () => fail('should not still be loading'),
      error: (e, _) => fail('unexpected error: $e'),
      orElse: () => fail('unexpected state'),
    );
  });

  test('deleteAnnotation removes from state', () async {
    final fake = FakeNotesRepository();
    final container = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(fake),
      currentBookIdProvider.overrideWith((_) => 'b1'),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(notesControllerProvider, (_, __) {});
    addTearDown(sub.close);
    final ctrl = container.read(notesControllerProvider.notifier);
    await ctrl.addHighlight(
      const EpubRangeLocator(
          chapterIndex: 0, startOffset: 0, endOffset: 3, quote: 'q1'),
      HighlightColor.yellow,
      'q1',
    );
    await Future.delayed(const Duration(milliseconds: 200));
    final state1 = container.read(notesControllerProvider);
    final id = state1.value!.annotations.first.id;
    await ctrl.deleteAnnotation(id);
    await Future.delayed(const Duration(milliseconds: 200));
    final state2 = container.read(notesControllerProvider);
    expect(state2.value!.annotations, isEmpty);
  });
}
