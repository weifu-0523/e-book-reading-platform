// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// One-shot tool: prepend AGPLv3 SPDX header to all dart source files that
// don't already have one. Excludes generated files (*.g.dart, *.freezed.dart,
// gen_l10n/*). Safe to re-run (idempotent).

import 'dart:io';

const header = '''// SPDX-License-Identifier: AGPL-3.0-or-later
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

''';

bool isGenerated(File f) {
  final p = f.path.replaceAll(r'\', '/');
  if (p.endsWith('.g.dart')) return true;
  if (p.endsWith('.freezed.dart')) return true;
  if (p.contains('/gen_l10n/')) return true;
  if (p.contains('/.dart_tool/')) return true;
  if (p.contains('/build/')) return true;
  return false;
}

Future<void> processDir(Directory dir) async {
  if (!dir.existsSync()) return;
  var added = 0;
  var skipped = 0;
  var generated = 0;
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;
    if (isGenerated(entity)) {
      generated++;
      continue;
    }
    final content = await entity.readAsString();
    if (content.startsWith('// SPDX-License-Identifier')) {
      skipped++;
      continue;
    }
    final newContent = header + content;
    await entity.writeAsString(newContent);
    added++;
    stdout.writeln('  + ${entity.path}');
  }
  stdout.writeln('${dir.path}: added=$added skipped=$skipped generated=$generated');
}

void main(List<String> args) async {
  final roots = args.isEmpty
      ? ['app/lib', 'reader_engine/lib', 'reader_engine_epub_view/lib', 'reader_engine_pdf_view/lib']
      : args;
  for (final r in roots) {
    await processDir(Directory(r));
  }
}
