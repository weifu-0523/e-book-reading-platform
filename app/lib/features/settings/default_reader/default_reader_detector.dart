// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors

import 'dart:io';

import 'package:flutter/services.dart';

/// Platform-agnostic interface for detecting / setting the system default
/// reader for .epub / .pdf.
abstract class DefaultReaderDetector {
  /// True when this app is already registered as the system default for
  /// .epub AND .pdf.
  Future<bool> isRegisteredAsDefault();

  /// Attempts to register this app as the system default. Returns true on
  /// success.
  ///
  /// On Android this is impossible to do programmatically — implementations
  /// should instead expose a method to jump to system settings.
  Future<bool> registerAsDefault({required String exePath});

  /// True when this platform supports programmatic registration (Windows).
  /// Android must show a "open system settings" affordance instead.
  bool get supportsProgrammaticRegistration;

  /// Opens the system settings page where the user can pick the default.
  /// Returns false when the platform has no such page.
  Future<bool> openSystemDefaultSettings();
}

class WindowsDefaultReaderDetector implements DefaultReaderDetector {
  // v1.14.0-alpha T6: T4 wired readAssoc + set_default_reader on this
  // dedicated channel (separate from dev.zhiyue.bookopen which is owned
  // by Dart-side BookOpenBridge).
  static const _channel = MethodChannel('dev.zhiyue.default_reader');

  @override
  bool get supportsProgrammaticRegistration => true;

  @override
  Future<bool> isRegisteredAsDefault() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await _channel.invokeMethod<String>(
          'readAssoc', {'ext': '.epub'});
      if (result == null || result.isEmpty) return false;
      final lower = result.toLowerCase();
      return lower.contains('zhiyue.exe');
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> registerAsDefault({required String exePath}) async {
    try {
      final result = await _channel.invokeMethod<bool>(
          'set_default_reader', {'exe_path': exePath});
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openSystemDefaultSettings() async {
    try {
      final result = await Process.run(
          'cmd', ['/c', 'start', 'ms-settings:defaultapps']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}

class AndroidDefaultReaderDetector implements DefaultReaderDetector {
  // v1.14.0-alpha T6: T5 wired openDefaultAppsSettings on the bookopen
  // channel (existing channel, used by MainActivity for Android-side
  // intents). No new channel needed.
  static const _channel = MethodChannel('dev.zhiyue.bookopen');

  @override
  bool get supportsProgrammaticRegistration => false;

  @override
  Future<bool> isRegisteredAsDefault() async => false;  // no Android API

  @override
  Future<bool> registerAsDefault({required String exePath}) async => false;

  @override
  Future<bool> openSystemDefaultSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openDefaultAppsSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}

/// Picks the right detector for the current platform.
DefaultReaderDetector defaultReaderDetectorForPlatform() {
  if (Platform.isWindows) return WindowsDefaultReaderDetector();
  if (Platform.isAndroid) return AndroidDefaultReaderDetector();
  return _NoopDefaultReaderDetector();
}

class _NoopDefaultReaderDetector implements DefaultReaderDetector {
  @override
  bool get supportsProgrammaticRegistration => false;
  @override
  Future<bool> isRegisteredAsDefault() async => false;
  @override
  Future<bool> registerAsDefault({required String exePath}) async => false;
  @override
  Future<bool> openSystemDefaultSettings() async => false;
}
