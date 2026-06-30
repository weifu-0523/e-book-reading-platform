import 'package:flutter/material.dart';

import '../../../core/widgets/empty_view.dart';
import '../../../gen_l10n/app_localizations.dart';

/// 书架空态视图。两种模式：
/// - [EmptyLibraryMode.empty]：用户书库完全为空，CTA 引导导入第一本书
/// - [EmptyLibraryMode.noSearchResult]：当前搜索/筛选条件下无匹配，CTA 清空筛选
///
/// T10 (2026-06-30): 重构为基于共享 [EmptyView] 的实现，移除 ad-hoc Column/
/// Icon/Text 拼装。所有可见文案走 l10n。
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
    final l10n = AppLocalizations.of(context)!;
    if (mode == EmptyLibraryMode.noSearchResult) {
      return EmptyView(
        title: l10n.libraryNoSearchResultTitle,
        icon: Icons.search_off,
        actionLabel: l10n.libraryNoSearchResultAction,
        onAction: onImportTap,
      );
    }
    return EmptyView(
      title: l10n.libraryEmptyTitle,
      subtitle: l10n.libraryEmptySubtitle,
      icon: Icons.library_books_outlined,
      actionLabel: l10n.libraryEmptyAction,
      onAction: onImportTap,
    );
  }
}

enum EmptyLibraryMode { empty, noSearchResult }
