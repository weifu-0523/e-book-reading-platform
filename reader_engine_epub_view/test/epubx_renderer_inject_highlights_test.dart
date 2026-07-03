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

import 'package:flutter_test/flutter_test.dart';
import 'package:reader_engine/engine/reader_engine_state.dart';
import 'package:reader_engine/rendering/highlight_range.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // M2.6/T5 (Bug #5b regression test): verify injectHighlights emits state
  // so consumer widgets rebuild and read the new highlight ranges.
  test(
    'injectHighlights emits ReaderEngineReady on state\$ (M2.6/T5)',
    () async {
      final r = EpubxRenderer();
      final states = <ReaderEngineState>[];
      final sub = r.state$.listen(states.add);
      // Allow the initial state yield to flush.
      await Future<void>.delayed(Duration.zero);
      states.clear();

      const highlights = [
        HighlightRange(0, 10, 'rgba(255, 235, 59, 0.5)'),
        HighlightRange(20, 30, 'rgba(255, 235, 59, 0.5)', hasNote: true),
      ];
      await r.injectHighlights(highlights);
      // Allow state$ async* to deliver.
      await Future<void>.delayed(Duration.zero);

      expect(states, isNotEmpty,
          reason: 'Bug #5b regression: injectHighlights must emit state '
              'notification so widget tree rebuilds and reads the new '
              '_allHighlights. Pre-fix the field was updated silently and '
              'highlights appeared in memory but not on screen.');
      expect(states.last, isA<ReaderEngineReady>(),
          reason: 'emitted state should be ReaderEngineReady');

      // Verify the highlights were actually stored.
      expect(r.allHighlightsForTest, equals(highlights));

      await sub.cancel();
      await r.dispose();
    },
  );
}
