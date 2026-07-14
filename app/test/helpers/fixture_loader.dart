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

import 'dart:io';
import 'package:path/path.dart' as p;

/// Fixture EPUB 加载器。
///
/// 文件不存在时返回 null，测试应 skip（而非 fail）。
class FixtureLoader {
  static const _fixturesDir = 'test/fixtures';

  static File? tryLoad(String filename) {
    final path = p.join(_fixturesDir, filename);
    final file = File(path);
    return file.existsSync() ? file : null;
  }
}
