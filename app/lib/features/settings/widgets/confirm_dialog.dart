import 'package:flutter/material.dart';

/// 显示确认对话框。
///
/// 返回 `true` 表示用户点击确认按钮，`false` 表示取消（含返回键 / 点击遮罩）。
/// 当 [destructive] 为 `true` 时，确认按钮渲染为红色 [FilledButton]，用于
/// 删除等不可恢复操作的视觉警示。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Colors.red)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
