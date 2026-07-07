// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// Unit tests for [SwitchSessionModeUseCase].
//
// Strategy: pure in-memory fake ChatRepository capturing setSessionMode +
// appendMessage calls. No DB, no Drift. Verifies:
//   - toSocratic: sets mode='socratic' + writes 'system' marker
//   - toNormal: sets mode='normal' silently (no marker, /exit-socratic quiet)
//   - toSocratic is idempotent (re-entry writes a fresh marker per spec §5.3)

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/data/local/daos/chat_repository.dart';
import 'package:zhiyue/features/ai_chat/use_cases/switch_session_mode_use_case.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Fake [ChatRepository] capturing only the methods used by
/// [SwitchSessionModeUseCase]. Anything else throws [UnimplementedError].
class _FakeRepo implements ChatRepository {
  String? mode;
  final List<({String role, String content})> messages = [];

  @override
  Future<void> setSessionMode(String sessionId, String mode) async {
    this.mode = mode;
  }

  @override
  Future<String> appendMessage({
    required String sessionId,
    required String role,
    required String content,
    String? presetSource,
    String? attachmentNoteId,
    String? attachmentNoteSnapshot,
    DateTime? now,
  }) async {
    messages.add((role: role, content: content));
    return 'msg-${messages.length}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeRepo repo;
  late SwitchSessionModeUseCase useCase;

  setUp(() {
    repo = _FakeRepo();
    useCase = SwitchSessionModeUseCase(repo: repo);
  });

  test('toSocratic sets mode=socratic', () async {
    await useCase.toSocratic(sessionId: 's1');
    expect(repo.mode, 'socratic');
  });

  test('toSocratic writes system marker 苏格拉底模式启动', () async {
    await useCase.toSocratic(sessionId: 's1');
    expect(repo.messages, hasLength(1));
    expect(repo.messages.first.role, 'system');
    expect(repo.messages.first.content, contains('苏格拉底'));
    expect(repo.messages.first.content, contains('启动'));
  });

  test('toNormal sets mode=normal', () async {
    await useCase.toNormal(sessionId: 's1');
    expect(repo.mode, 'normal');
  });

  test('toNormal does NOT write system marker (silent exit)', () async {
    await useCase.toNormal(sessionId: 's1');
    expect(repo.messages, isEmpty,
        reason: 'exit-socratic is silent per spec §5.3');
  });

  test('toSocratic is idempotent if already socratic (still writes marker)',
      () async {
    // The use case doesn't check current mode — caller is responsible.
    // Re-invoking will re-write the marker. This is acceptable: user explicitly
    // re-entering socratic should see a new marker.
    await useCase.toSocratic(sessionId: 's1');
    await useCase.toSocratic(sessionId: 's1');
    expect(repo.messages, hasLength(2));
    expect(repo.mode, 'socratic');
  });
}
