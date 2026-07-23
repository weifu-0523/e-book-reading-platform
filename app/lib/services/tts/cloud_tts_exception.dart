// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

/// Error categories for cloud TTS failures. Drives fallback policy:
/// [isTransient] kinds trigger auto-fallback to system engine;
/// non-transient kinds (auth/quota/invalidRequest) only show UI message
/// (fallback wouldn't help — same credentials = same failure).
enum CloudTtsErrorKind {
  network,
  auth,
  quota,
  server,
  invalidRequest;

  bool get isTransient => this == network || this == server;

  /// Maps HTTP status code to error kind.
  /// - 401/403 → auth (credential issue, fallback won't help)
  /// - 429 → quota (rate limit, fallback won't help)
  /// - 5xx → server (transient, fallback may help)
  /// - 4xx → invalidRequest (programming error, fallback won't help)
  /// - 2xx/3xx unexpected → invalidRequest (server returned success
  ///   but body wasn't what we expected).
  static CloudTtsErrorKind fromHttpStatus(int status) {
    if (status == 401 || status == 403) return CloudTtsErrorKind.auth;
    if (status == 429) return CloudTtsErrorKind.quota;
    if (status >= 500) return CloudTtsErrorKind.server;
    if (status >= 400) return CloudTtsErrorKind.invalidRequest;
    return CloudTtsErrorKind.invalidRequest;
  }
}

/// Thrown by cloud TTS services. Caught by TtsPlaybackController which
/// decides whether to fallback based on [kind].
class CloudTtsException implements Exception {
  final CloudTtsErrorKind kind;
  final String message;
  final String? cause;

  const CloudTtsException({
    required this.kind,
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'CloudTtsException($kind): $message';
}
