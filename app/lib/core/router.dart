import 'package:go_router/go_router.dart';

import '../features/library/pages/book_detail_page.dart';
import '../features/library/pages/library_page.dart';
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
        builder: (context, state) => const LibraryPage(),
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
          return BookDetailPage(bookId: id);
        },
      ),
    ],
  );
}
