import 'package:flutter/material.dart';

enum LocaleSetting {
  system,
  chinese,
  english;

  Locale? toLocale() {
    switch (this) {
      case LocaleSetting.system:
        return null;
      case LocaleSetting.chinese:
        return const Locale('zh');
      case LocaleSetting.english:
        return const Locale('en');
    }
  }

  static LocaleSetting fromName(String? name) {
    switch (name) {
      case 'chinese':
        return LocaleSetting.chinese;
      case 'english':
        return LocaleSetting.english;
      case 'system':
      default:
        return LocaleSetting.system;
    }
  }
}
