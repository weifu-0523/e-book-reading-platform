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
import 'package:reader_engine/core/typography_settings.dart';
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

void main() {
  test(
    'ConcreteEpubReaderEngine.typography forwards to renderer after setTypography',
    () async {
      // Bug #3 (M2.6/T3) regression test.
      //
      // Pre-fix: typography getter returned a const default, so
      // TypographyPanel's onChanged wrote to a discarded object and the
      // panel's slider chips appeared unresponsive.
      //
      // Construction without an EPUB fixture works because the engine wraps
      // an empty EpubxRenderer (proven by concrete_reader_engine_test.dart).
      // setTypography mutates _typography synchronously, so the getter can
      // be read immediately without a widget pump.
      final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());

      // Sanity: defaults() matches what the getter returned pre-fix.
      expect(engine.typography.fontSize, TypographySettings.defaults().fontSize);

      // Sentinel: 99.0 is unambiguously non-default (default = 16.0).
      const custom = TypographySettings(
        fontSize: 99.0,
        lineHeight: 2.0,
        fontFamily: 'Sentinel',
        theme: ReadingTheme.dark,
        pageMargin: PageMargin.extraWide,
      );
      await engine.setTypography(custom);

      // The actual regression assertion: getter must reflect what
      // setTypography just wrote, not a freshly-built defaults().
      expect(engine.typography, equals(custom));
      expect(engine.typography.fontSize, 99.0);

      await engine.close();
    },
  );
}
