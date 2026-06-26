import 'package:flutter/material.dart';

/// 书架空态视图。两种模式：
/// - [EmptyLibraryMode.empty]：用户书库完全为空，CTA 引导导入第一本书
/// - [EmptyLibraryMode.noSearchResult]：当前搜索/筛选条件下无匹配，CTA 清空筛选
class EmptyLibraryView extends StatelessWidget {
  final VoidCallback onImportTap;
  final EmptyLibraryMode mode;

  const EmptyLibraryView({
    super.key,
    required this.onImportTap,
    this.mode = EmptyLibraryMode.empty,
  });

  @override
  Widget build(BuildContext context) {
    if (mode == EmptyLibraryMode.noSearchResult) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 64),
            const SizedBox(height: 16),
            const Text('无匹配书籍'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onImportTap,
              child: const Text('清空筛选'),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.library_books, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('书库为空'),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: onImportTap,
            icon: const Icon(Icons.add),
            label: const Text('导入第一本书'),
          ),
        ],
      ),
    );
  }
}

enum EmptyLibraryMode { empty, noSearchResult }
