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

import '../../../data/local/daos/chat_repository.dart';

/// Switches a chat session between 'normal' and 'socratic' modes.
///
/// **Asymmetric by design (spec §5.3):**
/// - [toSocratic]: sets mode + writes a system message marker so the user
///   sees "苏格拉底模式启动" in the chat history.
/// - [toNormal]: sets mode silently (no marker). The `/exit-socratic` slash
///   command path is intentionally quiet — the user already knows they
///   exited.
///
/// **Why doesn't this use case check the current mode before writing the
/// marker?**
/// - Doing so would require an extra DB read per invocation (N+1 risk in
///   batch UI flows). The caller (UI action / slash-command dispatcher)
///   already knows the current mode and is responsible for deciding whether
///   to invoke the transition at all. Re-invoking [toSocratic] when already
///   in socratic mode will re-write the marker — acceptable since the user
///   explicitly re-entered the mode and seeing a new marker is informative.
class SwitchSessionModeUseCase {
  SwitchSessionModeUseCase({required this.repo});
  final ChatRepository repo;

  /// Switches the session to socratic mode and writes a visible system
  /// marker.
  ///
  /// Caller responsibility: only invoke when the session is currently in
  /// 'normal' mode (or when an explicit re-entry marker is desired).
  Future<void> toSocratic({required String sessionId}) async {
    await repo.setSessionMode(sessionId, 'socratic');
    await repo.appendMessage(
      sessionId: sessionId,
      role: 'system',
      content: '苏格拉底模式启动',
    );
  }

  /// Switches the session back to normal mode silently.
  ///
  /// Per spec §5.3, the `/exit-socratic` path is intentionally quiet: the
  /// user typed the command, so they already know the transition happened.
  /// No system marker is written.
  Future<void> toNormal({required String sessionId}) async {
    await repo.setSessionMode(sessionId, 'normal');
    // Intentionally no system marker.
  }
}
