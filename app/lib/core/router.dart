import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_page.dart';
import '../features/reader/pages/reader_page.dart';

/// 应用路由配置。
///
/// M3.1 用 go_router 替换 M2 的 onGenerateRoute，便于后续扩展
/// （详情页、笔记页、设置页等）。
GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/book/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ReaderPage(bookId: id);
        },
      ),
      GoRoute(
        path: '/book/:id/details',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return _BookDetailPlaceholder(bookId: id);
        },
      ),
    ],
  );
}

/// 占位；Task 18 (BookDetailPage) 实现后替换为真实页面。
class _BookDetailPlaceholder extends StatelessWidget {
  final String bookId;
  const _BookDetailPlaceholder({required this.bookId});
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text('详情（M3.1 Task 18 实现）')));
}
