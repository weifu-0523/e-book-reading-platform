import 'package:flutter/widgets.dart';

import '../core/locator.dart';
import '../core/typography_settings.dart';
import '../navigation/toc.dart';
import 'pagination_model.dart';

/// EPUB 渲染器抽象 —— EPUB 类内部契约。
///
/// 实现类需包装具体的 EPUB 渲染库（如 epub_view_plus）。
/// UI 层永远不直接引用此接口，只看 [ReaderEngine]。
abstract interface class EpubRenderer {
  Widget build(BuildContext context);
  Future<void> openFile(String filePath);
  Stream<Locator> get currentLocation$;
  Future<TableOfContents> get toc;
  Future<void> gotoLocator(Locator locator);
  Future<void> setTypography(TypographySettings settings);
  Future<void> setPaginationMode(PaginationMode mode);
  Future<void> dispose();
}
