/// Result of a full sync cycle (push + pull).
class SyncResult {
  const SyncResult({
    required this.success,
    required this.pushedCount,
    required this.pulledCount,
    required this.error,
  });

  const SyncResult.success({
    required int pushedCount,
    required int pulledCount,
  }) : this(
          success: true,
          pushedCount: pushedCount,
          pulledCount: pulledCount,
          error: null,
        );

  const SyncResult.failure(String error)
      : this(success: false, pushedCount: 0, pulledCount: 0, error: error);

  final bool success;
  final int pushedCount;
  final int pulledCount;
  final String? error;
}

/// Thrown when sync fails — caller wraps in SyncResult.failure.
class SyncException implements Exception {
  const SyncException(this.message);
  final String message;

  @override
  String toString() => 'SyncException: $message';
}

/// Abstract sync engine. M2.0a ships one implementation (WebDavSyncEngine);
/// future providers (Dropbox/OneDrive) would implement this.
abstract class SyncEngine {
  /// Push all pending outbox records to the cloud, then pull remote changes
  /// and apply them locally (last-write-wins by mtime).
  ///
  /// Returns aggregate counts. Throws [SyncException] on unrecoverable errors
  /// (auth, network); partial failures return success=false with error.
  Future<SyncResult> sync();
}
