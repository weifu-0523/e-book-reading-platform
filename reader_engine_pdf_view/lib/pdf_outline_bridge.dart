import 'package:pdfrx/pdfrx.dart';
import 'package:reader_engine/core/locator.dart';
import 'package:reader_engine/navigation/toc.dart';

/// pdfrx `PdfOutlineNode` 树 → reader_engine [TableOfContents] 转换器。
///
/// pdfrx v2.4.4 API（spike 2026-06-28 验证）：
/// - `PdfOutlineNode` 是普通不可变 class（非 sealed），三字段：
///   `String title` / `PdfDest? dest` / `List<PdfOutlineNode> children`。
///   构造为 `const PdfOutlineNode({required title, required dest, required children})`。
/// - `PdfDest` 同样是普通 class（非 sealed）：`int pageNumber`（1-based）、
///   `PdfDestCommand command`、`List<double?>? params`。提取页码只需 `dest.pageNumber`。
/// - `PdfDocument.loadOutline()` 异步返回根节点列表 `Future<List<PdfOutlineNode>>`
///   （顶级可能有多个根，因此本 API 接收 list 而非单根）。
/// - `PdfDestCommand` enum：unknown/xyz/fit/fitH/fitV/fitR/fitB/fitBH/fitBV。
///   本桥接器对 command 不敏感——任意 command 都带 pageNumber，统一取之。
class PdfOutlineBridge {
  const PdfOutlineBridge._();

  /// 将 pdfrx 顶级 outline 列表（`PdfDocument.loadOutline()` 返回值）
  /// 转换为 reader_engine [TableOfContents]。
  ///
  /// 行为：
  /// - 空列表 → `TableOfContents.empty()`。
  /// - `dest == null` 的节点被静默跳过（无法解析页码）。
  /// - 子节点递归处理；同样跳过 `dest == null` 的后代。
  /// - 每个 [TocEntry] 的 [Locator] 是 [PdfPageLocator]，`offsetX/offsetY = 0`
  ///   （pdfrx dest 的 params 内坐标在阅读区 widget 渲染后再计算，bridge 层不解析）。
  static TableOfContents toTableOfContents(List<PdfOutlineNode> nodes) {
    return TableOfContents(entries: _convert(nodes));
  }

  static List<TocEntry> _convert(List<PdfOutlineNode> nodes) {
    final result = <TocEntry>[];
    for (final node in nodes) {
      final page = node.dest?.pageNumber;
      if (page == null) continue;
      result.add(TocEntry(
        title: node.title,
        locator: PdfPageLocator(page: page, offsetX: 0, offsetY: 0),
        children: _convert(node.children),
      ));
    }
    return result;
  }
}
