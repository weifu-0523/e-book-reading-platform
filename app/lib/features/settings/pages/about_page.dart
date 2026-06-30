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
import 'package:url_launcher/url_launcher.dart';

import '../../../gen_l10n/app_localizations.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _giteeUrl = 'https://gitee.com/weifu0523/e-book-reading-platform';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAbout)),
      body: ListView(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.menu_book_outlined, size: 80),
          const SizedBox(height: 16),
          Center(
              child: Text(l10n.appTitle,
                  style: Theme.of(context).textTheme.headlineSmall)),
          const Center(child: Text('v0.1.0+1')),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(l10n.settingsSourceCode),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => launchUrl(Uri.parse(_giteeUrl)),
          ),
          const ListTile(
            leading: Icon(Icons.copyright),
            title: Text('AGPLv3'),
            subtitle: Text('© 2026 Zhi Yue contributors'),
          ),
        ],
      ),
    );
  }
}
