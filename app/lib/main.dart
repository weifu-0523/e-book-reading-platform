import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app.dart';
import 'core/app_providers.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: providers,
      child: const ZhiYueApp(),
    ),
  );
}
