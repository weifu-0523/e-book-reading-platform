import 'package:flutter/material.dart';

/// 选择模式下的底部操作条。
/// 显示当前已选数量 + 全选 + 删除按钮。
class BatchSelectionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onDelete;
  final VoidCallback onSelectAll;

  const BatchSelectionBar({
    super.key,
    required this.selectedCount,
    required this.onDelete,
    required this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Text('已选 $selectedCount 本'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: onSelectAll,
              tooltip: '全选',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
              tooltip: '删除',
            ),
          ],
        ),
      ),
    );
  }
}
