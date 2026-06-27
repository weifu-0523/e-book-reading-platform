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
