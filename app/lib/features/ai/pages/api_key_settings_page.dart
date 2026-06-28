import 'package:flutter/material.dart';

import '../../../gen_l10n/app_localizations.dart';
import '../../../services/ai/api_key_store.dart';

/// AI API Key 设置页。
///
/// M1.5a/T14：用户在此录入 DeepSeek（或 OpenAI 兼容）API Key、Base URL、模型。
/// 凭证通过 [ApiKeyStore] 持久化到 flutter_secure_storage，不上传任何服务器。
class ApiKeySettingsPage extends StatefulWidget {
  const ApiKeySettingsPage({super.key, required this.store});

  final ApiKeyStore store;

  @override
  State<ApiKeySettingsPage> createState() => _ApiKeySettingsPageState();
}

class _ApiKeySettingsPageState extends State<ApiKeySettingsPage> {
  final _apiKeyCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  bool _obscure = true;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadCreds();
    }
  }

  Future<void> _loadCreds() async {
    final c = await widget.store.load();
    if (!mounted) return;
    setState(() {
      _apiKeyCtrl.text = c?.apiKey ?? '';
      _baseUrlCtrl.text = c?.baseUrl ?? ApiCredentialsDefaults.baseUrl;
      _modelCtrl.text = c?.model ?? ApiCredentialsDefaults.model;
    });
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _apiKeyCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    await widget.store.save(AiCredentials(
      apiKey: _apiKeyCtrl.text.trim(),
      baseUrl: _baseUrlCtrl.text.trim().isEmpty
          ? ApiCredentialsDefaults.baseUrl
          : _baseUrlCtrl.text.trim(),
      model: _modelCtrl.text.trim().isEmpty
          ? ApiCredentialsDefaults.model
          : _modelCtrl.text.trim(),
    ));
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.aiSettingsSave)),
    );
  }

  Future<void> _clear() async {
    await widget.store.clear();
    if (!mounted) return;
    setState(() {
      _apiKeyCtrl.clear();
      _baseUrlCtrl.text = ApiCredentialsDefaults.baseUrl;
      _modelCtrl.text = ApiCredentialsDefaults.model;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiSettingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _apiKeyCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: l10n.aiSettingsApiKey,
              hintText: l10n.aiSettingsApiKeyHint,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon:
                    Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                tooltip: _obscure ? l10n.aiSettingsShow : l10n.aiSettingsHide,
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baseUrlCtrl,
            decoration: InputDecoration(
              labelText: l10n.aiSettingsBaseUrl,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelCtrl,
            decoration: InputDecoration(
              labelText: l10n.aiSettingsModel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              FilledButton(
                onPressed: _canSave ? _save : null,
                child: Text(l10n.aiSettingsSave),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _clear,
                child: Text(l10n.aiSettingsClear),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l10n.aiSettingsHelp,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
