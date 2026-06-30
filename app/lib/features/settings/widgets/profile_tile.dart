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

class ProfileTile extends StatelessWidget {
  const ProfileTile({
    super.key,
    required this.profile,
    required this.isOnly,
    required this.onSetDefault,
    required this.onRename,
    required this.onDelete,
  });

  final TypographyProfile profile;
  final bool isOnly;
  final VoidCallback onSetDefault;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        profile.isDefault ? Icons.star : Icons.star_border,
        color: profile.isDefault ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(profile.name),
      subtitle: Text(_settingsLabel(profile.settings)),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'default') onSetDefault();
          if (v == 'rename') onRename();
          if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          if (!profile.isDefault)
            const PopupMenuItem(value: 'default', child: Text('设为默认')),
          const PopupMenuItem(value: 'rename', child: Text('重命名')),
          if (!isOnly)
            const PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
      onTap: onRename,
    );
  }

  String _settingsLabel(TypographySettings s) {
    return '字号 ${s.fontSize.toStringAsFixed(0)} · 行距 ${s.lineHeight}';
  }
}
