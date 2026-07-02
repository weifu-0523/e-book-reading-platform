// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 ZhiYue Open Source contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';

/// PDF 加载失败时由 `PdfViewerParams.errorBannerBuilder` 渲染的友好错误页。
///
/// pdfrx 在 Windows 上对真实加载失败的报错一律显示 "No password supplied"
/// （其 `_defaultErrorBannerBuilder` 直接展示 `error.toString()`）。这对
/// 用户是误导——绝大多数情况并非密码问题，而是 PDFium 引擎本身的兼容
/// 或运行时问题（参见 espresso3389/pdfrx#166）。本 widget 改为先显示
/// 中性"加载失败"提示，再把原始错误折叠到副文本中作为诊断线索。
///
/// onRetry 由调用方按需传入（典型：reader_engine 重启 documentRef）。
class PdfErrorBanner extends StatelessWidget {
  const PdfErrorBanner({
    super.key,
    required this.error,
    this.onRetry,
  });

  /// pdfrx 透出的原始错误对象（可能是 [Exception] / [String] / [Error]）。
  final Object error;

  /// 用户点「重试」时回调；为 null 时不渲染按钮。
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'PDF 加载失败',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'PDFium 引擎在 Windows 上对任何加载失败都误报为密码错误——'
              '请先用 Edge / Adobe 确认文件能正常打开。\n'
              '错误详情：$error',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
