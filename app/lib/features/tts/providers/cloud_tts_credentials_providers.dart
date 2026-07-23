// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source Contributors

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/tts/cloud_tts_credentials.dart';

/// Secure-storage backed credential store for Volcengine TTS.
/// Reads/writes via FlutterSecureStorage (Android Keystore / Windows DPAPI).
/// Credentials are NEVER synced via WebDAV — they live only on the device.
final volcengineTtsCredentialStoreProvider =
    Provider<VolcengineTtsCredentialStore>((ref) {
  return VolcengineTtsCredentialStore();
});

/// Async-loaded Volcengine credentials. Null when user hasn't filled the form.
final volcengineTtsCredentialsProvider =
    FutureProvider<VolcengineTtsCredentials?>((ref) async {
  final store = ref.watch(volcengineTtsCredentialStoreProvider);
  return store.load();
});

/// Secure-storage backed credential store for Qwen/CosyVoice TTS.
final qwenTtsCredentialStoreProvider =
    Provider<QwenTtsCredentialStore>((ref) {
  return QwenTtsCredentialStore();
});

/// Async-loaded Qwen credentials. Null when user hasn't filled the form.
final qwenTtsCredentialsProvider =
    FutureProvider<QwenTtsCredentials?>((ref) async {
  final store = ref.watch(qwenTtsCredentialStoreProvider);
  return store.load();
});
