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
