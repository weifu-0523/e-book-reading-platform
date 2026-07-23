// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Snapshot of the latest cloud-TTS → system fallback event.
///
/// Has [hasFallback]=false until a cloud engine reports a transient error
/// (network / server). Auth/quota/invalidRequest errors do NOT trigger
/// fallback (user action required — re-enter API key, upgrade plan, etc.).
class TtsFallbackState {
  final bool hasFallback;
  final String fromEngine;
  final String message;
  final DateTime? timestamp;

  const TtsFallbackState({
    this.hasFallback = false,
    this.fromEngine = '',
    this.message = '',
    this.timestamp,
  });

  TtsFallbackState copyWith({
    bool? hasFallback,
    String? fromEngine,
    String? message,
    DateTime? timestamp,
  }) {
    return TtsFallbackState(
      hasFallback: hasFallback ?? this.hasFallback,
      fromEngine: fromEngine ?? this.fromEngine,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

final ttsFallbackProvider =
    StateNotifierProvider<TtsFallbackNotifier, TtsFallbackState>(
  (ref) => TtsFallbackNotifier(),
);

class TtsFallbackNotifier extends StateNotifier<TtsFallbackState> {
  TtsFallbackNotifier() : super(const TtsFallbackState());

  void reportFallback({required String fromEngine, required String message}) {
    state = TtsFallbackState(
      hasFallback: true,
      fromEngine: fromEngine,
      message: message,
      timestamp: DateTime.now(),
    );
  }

  void clear() {
    state = const TtsFallbackState();
  }
}
