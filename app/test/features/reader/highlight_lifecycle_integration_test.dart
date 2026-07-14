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

import '../../fakes/fake_notes_repository.dart';

const _delay = Duration(milliseconds: 200);

void main() {
  test('highlight lifecycle: add → list → edit → delete', () async {
    final fake = FakeNotesRepository();
    final container = ProviderContainer(overrides: [
      notesRepositoryProvider.overrideWithValue(fake),
      currentBookIdProvider.overrideWith((_) => 'b1'),
    ]);
    addTearDown(container.dispose);
    // Keep the autoDispose provider alive across all read() calls.
    container.listen(notesControllerProvider, (_, __) {});

    // ADD
    await container.read(notesControllerProvider.notifier).addHighlight(
          const EpubRangeLocator(
              chapterIndex: 0, startOffset: 0, endOffset: 3, quote: 'abc'),
          HighlightColor.yellow,
          'abc',
        );
    await Future.delayed(_delay);
    container.read(notesControllerProvider).maybeWhen(
          data: (s) => expect(s.annotations, hasLength(1)),
          orElse: () => fail('should be data after add'),
        );

    // EDIT (add a note)
    final ann =
        container.read(notesControllerProvider).value!.annotations.first;
    await container.read(notesControllerProvider.notifier).updateAnnotation(
          ann.copyWith(note: 'my note'),
        );
    await Future.delayed(_delay);
    container.read(notesControllerProvider).maybeWhen(
          data: (s) => expect(s.annotations.first.note, 'my note'),
          orElse: () => fail('should be data after edit'),
        );

    // DELETE
    await container
        .read(notesControllerProvider.notifier)
        .deleteAnnotation(ann.id);
    await Future.delayed(_delay);
    container.read(notesControllerProvider).maybeWhen(
          data: (s) => expect(s.annotations, isEmpty),
          orElse: () => fail('should be data after delete'),
        );
  });
}
