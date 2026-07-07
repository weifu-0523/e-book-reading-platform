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

import '../../../services/ai/open_ai_compatible_client.dart';
import '../use_cases/send_message_use_case.dart' show ChatLlmClient;

/// Concrete [ChatLlmClient] backed by [OpenAiCompatibleClient].
///
/// Production wiring: the provider reads [AiCredentials] from [ApiKeyStore]
/// and constructs a fresh [OpenAiCompatibleClient] per call. Each
/// [streamChat] invocation builds its own client so a credentials change
/// between two sends doesn't leak the old key/model into the next call.
///
/// The OpenAI-compatible client already does SSE parsing, TCP-line buffering,
/// and HTTP error → [AiException] mapping (see
/// `open_ai_compatible_client.dart`). We just forward.
///
/// **Cancel semantics**: the underlying stream cancels itself when the
/// subscriber cancels its subscription (Drift/StreamedResponse default).
/// [cancel] here is a no-op stub kept to satisfy the interface; the actual
/// cancellation is driven by the controller dropping its StreamSubscription
/// (see [ChatSessionController]).
class OpenAiChatLlmAdapter implements ChatLlmClient {
  OpenAiChatLlmAdapter(this._clientFactory);

  /// Builds a fresh client per call. Factory closes over credentials +
  /// httpClient resolved at provider construction time.
  final OpenAiCompatibleClient Function() _clientFactory;

  @override
  Stream<String> streamChat(String prompt) async* {
    yield* _clientFactory().streamChat(prompt: prompt);
  }

  @override
  Future<void> cancel() async {
    // No-op: callers cancel via StreamSubscription. Kept for interface
    // symmetry with stub implementations that may buffer chunks.
  }
}
