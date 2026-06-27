import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import 'core/app.dart';
import 'core/app_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize(); // M4: pdfrx 引擎初始化
  runApp(
    ProviderScope(
      overrides: providers,
      child: const ZhiYueApp(),
    ),
  );
}
