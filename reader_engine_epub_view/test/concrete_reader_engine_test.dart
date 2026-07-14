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
import 'package:reader_engine_epub_view/concrete_reader_engine.dart';
import 'package:reader_engine_epub_view/epubx_renderer.dart';

void main() {
  test('nextSpine on empty book is a no-op (no throw)', () async {
    final engine = ConcreteEpubReaderEngine(renderer: EpubxRenderer());
    // No book loaded — flatChapters is empty
    await engine.nextSpine(); // should not throw
    await engine.previousSpine();
    await engine.close();
  });

  // Note: testing with a real book requires fixture EPUB;
  // integration tests in M2.5-5 will cover the happy path.
}
