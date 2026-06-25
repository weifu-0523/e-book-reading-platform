import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/home_page.dart';
import '../features/reader/pages/reader_page.dart';
import 'theme.dart';

class ZhiYueApp extends ConsumerWidget {
  const ZhiYueApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '智阅',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const HomePage(),
      onGenerateRoute: _onGenerateRoute,
    );
  }
}

/// 路由生成。
///
/// 设计决策：M1 原本仅用 `MaterialApp(home: HomePage())`，未引入 `go_router`。
/// 为了不引入新依赖，沿用 Flutter 内置的 `onGenerateRoute`，按 `/book/:id` 规约派发
/// 到 [ReaderPage]。若后续 M3+ 路由数量增多，再迁移到 `go_router`。
Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
  final uri = Uri.parse(settings.name ?? '/');
  if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'book') {
    final bookId = uri.pathSegments[1];
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => ReaderPage(bookId: bookId),
    );
  }
  return null;
}

