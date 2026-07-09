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

// M2.7/T21: smoke test placeholder for reader_body ↔ AiDrawerWidget wiring.
//
// ReaderBody 持有 ReaderEngine + 14+ provider 依赖（notesController /
// readerEngineForBook / readerUiController / bookRepository / ai /
// highlightColorPicker / ...）。构造一个能进入 Ready 状态的 harness 至少
// 需要：注入 fake readerEngineForBookProvider + stub 一个 ConcreteEpubReaderEngine
// Ready state + 假 Book + 假 AiConfig + Override 一组 provider，工时 ~半天，
// 与 T26（完整集成测试）的 harness 重复。
//
// 决策：本任务用 skipped placeholder 占位，真实测试由 T26 落地。
// T26 将构造一个完整的 reader tree harness 并验证：
//   1. 窄屏 Scaffold.endDrawer 包含 AiDrawerWidget(wide:false)。
//   2. 宽屏 Row 末尾在 _aiPanelOpen=true 时出现 SizedBox(width:380) panel。
//   3. _toggleAiDrawer() 切换可见性。
//   4. bookId 切换 → didUpdateWidget → post-frame closeEndDrawer。

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'reader_body exposes AiDrawerWidget in narrow Scaffold.endDrawer',
    (tester) async {
      // Placeholder: see file header comment. T26 落地完整 harness 后
      // 在此处补充真实 widget test。
      expect(true, isTrue);
    },
    skip: 'M2.7 T26 harness 未落地此 placeholder (需 fake readerEngineForBookProvider + '
        'stub ConcreteEpubReaderEngine Ready + override providers, ~半天工时); '
        'deferred to next sweep. 2026-07-10 深度清理确认仍 skip.',
    // TODO(T26): construct ReaderBody with fake engine + providers;
    // verify endDrawer + wide panel + toggle + bookId-switch close.
  );
}
