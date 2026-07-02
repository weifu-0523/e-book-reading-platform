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
import 'package:reader_engine/core/typography_settings.dart';

import '../../../data/models/typography_profile.dart';
import '../../../data/models/user_font.dart';

/// 阅读排版设置面板。
/// M2 字号/主题 + M3.1 行距/字体/页边距 + M3.5 多预设 + 用户字体。
class TypographyPanel extends StatelessWidget {
  final TypographySettings current;
  final ValueChanged<TypographySettings> onChanged;

  /// M3.5 多预设集成。非空时在面板顶部渲染预设下拉 + 存为预设按钮。
  final List<TypographyProfile>? profiles;
  final TypographyProfile? currentProfile;
  final ValueChanged<TypographyProfile>? onSelectProfile;
  final Future<void> Function({
    required TypographySettings settings,
    required bool overwrite,
    String? newName,
  })? onSaveAsProfile;

  /// M3.5 用户字体。系统/衬线/无衬线 之外的可选项。
  final List<UserFont> userFonts;

  const TypographyPanel({
    super.key,
    required this.current,
    required this.onChanged,
    this.profiles,
    this.currentProfile,
    this.onSelectProfile,
    this.onSaveAsProfile,
    this.userFonts = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (profiles != null) _profileRow(context),
            if (profiles != null) const SizedBox(height: 16),

            Text('字号', style: Theme.of(context).textTheme.titleSmall),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () => _changeFontSize(current.fontSize - 1),
                ),
                Expanded(
                  child: Text(
                    current.fontSize.toStringAsFixed(0),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _changeFontSize(current.fontSize + 1),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text('主题', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: ReadingTheme.values
                  .map((t) => ChoiceChip(
                        label: Text(_themeLabel(t)),
                        selected: current.theme == t,
                        onSelected: (_) =>
                            onChanged(current.copyWith(theme: t)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            Text('行距', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: [
                ('紧凑', 1.2),
                ('标准', 1.5),
                ('宽松', 1.8),
              ]
                  .map((p) => ChoiceChip(
                        label: Text(p.$1),
                        selected: (current.lineHeight - p.$2).abs() < 0.01,
                        onSelected: (_) =>
                            onChanged(current.copyWith(lineHeight: p.$2)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            Text('字体', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: [
                ('系统', null),
                ('衬线', 'serif'),
                ('无衬线', 'sans-serif'),
                ...userFonts.map((f) => (f.displayName, f.familyName)),
              ]
                  .map((p) => ChoiceChip(
                        label: Text(p.$1),
                        selected: current.fontFamily == p.$2,
                        onSelected: (_) =>
                            onChanged(current.copyWith(fontFamily: p.$2)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            Text('页边距', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: PageMargin.values
                  .map((m) => ChoiceChip(
                        label: Text(_marginLabel(m)),
                        selected: current.pageMargin == m,
                        onSelected: (_) =>
                            onChanged(current.copyWith(pageMargin: m)),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButton<TypographyProfile>(
            value: currentProfile,
            isExpanded: true,
            hint: const Text('选择预设'),
            items: profiles!.map((p) => DropdownMenuItem(
                  value: p,
                  child: Row(children: [
                    if (p.isDefault) const Icon(Icons.star, size: 16),
                    Text(p.name),
                  ]),
                )).toList(),
            onChanged: (p) {
              if (p != null && onSelectProfile != null) onSelectProfile!(p);
            },
          ),
        ),
        const SizedBox(width: 8),
        if (onSaveAsProfile != null)
          TextButton.icon(
            icon: const Icon(Icons.save_outlined),
            label: const Text('存为预设'),
            onPressed: () => _showSaveAsDialog(context),
          ),
      ],
    );
  }

  void _showSaveAsDialog(BuildContext context) {
    bool overwrite = true;
    final nameCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('存为预设'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioGroup<bool>(
                groupValue: overwrite,
                onChanged: (v) => setState(() => overwrite = v ?? true),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<bool>(
                      title: Text('覆盖当前「${currentProfile?.name ?? ''}」'),
                      value: true,
                    ),
                    const RadioListTile<bool>(
                      title: Text('另存为新预设'),
                      value: false,
                    ),
                  ],
                ),
              ),
              if (!overwrite)
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '名称'),
                  autofocus: true,
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (onSaveAsProfile != null) {
                  await onSaveAsProfile!(
                    settings: current,
                    overwrite: overwrite,
                    newName: overwrite ? null : nameCtrl.text.trim(),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    ).whenComplete(nameCtrl.dispose);
  }

  void _changeFontSize(double newSize) {
    final clamped = newSize.clamp(12.0, 32.0);
    onChanged(current.copyWith(fontSize: clamped));
  }

  String _themeLabel(ReadingTheme t) {
    switch (t) {
      case ReadingTheme.light:
        return '白';
      case ReadingTheme.dark:
        return '深';
      case ReadingTheme.sepia:
        return '黄';
      case ReadingTheme.eInk:
        return '墨';
    }
  }

  String _marginLabel(PageMargin m) {
    switch (m) {
      case PageMargin.compact:
        return '紧凑';
      case PageMargin.normal:
        return '标准';
      case PageMargin.wide:
        return '宽松';
      case PageMargin.extraWide:
        return '特宽';
    }
  }
}
