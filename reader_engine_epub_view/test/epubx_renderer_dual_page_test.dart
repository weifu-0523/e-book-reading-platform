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
import 'package:reader_engine/rendering/pagination_model.dart';
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

void main() {
  test('EpubxRenderer.dualPageMode defaults to false', () {
    final renderer = EpubxRenderer();
    expect(renderer.dualPageMode, isFalse);
  });

  test('EpubxRenderer.dualPageMode is settable', () {
    final renderer = EpubxRenderer();
    renderer.dualPageMode = true;
    expect(renderer.dualPageMode, isTrue);
  });

  test(
      'ConcreteEpubReaderEngine.rendererRef exposes dualPageMode '
      'and survives setPaginationMode', () async {
    final renderer = EpubxRenderer();
    final engine = ConcreteEpubReaderEngine(renderer: renderer);
    expect(engine.rendererRef.dualPageMode, isFalse);
    engine.rendererRef.dualPageMode = true;
    expect(engine.rendererRef.dualPageMode, isTrue);
    // setPaginationMode should not clobber dualPageMode.
    await engine.rendererRef.setPaginationMode(PaginationMode.scroll);
    expect(engine.rendererRef.dualPageMode, isTrue);
  });
}
