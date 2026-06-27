import 'package:flutter/material.dart';

enum ThemeModeSetting {
  system,
  light,
  dark;

  ThemeMode toMaterialThemeMode() {
    switch (this) {
      case ThemeModeSetting.system:
        return ThemeMode.system;
      case ThemeModeSetting.light:
        return ThemeMode.light;
      case ThemeModeSetting.dark:
        return ThemeMode.dark;
    }
  }

  static ThemeModeSetting fromName(String? name) {
    switch (name) {
      case 'light':
        return ThemeModeSetting.light;
      case 'dark':
        return ThemeModeSetting.dark;
      case 'system':
      default:
        return ThemeModeSetting.system;
    }
  }
}
