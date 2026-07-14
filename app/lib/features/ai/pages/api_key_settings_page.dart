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

import '../../../gen_l10n/app_localizations.dart';
import '../../../services/ai/api_key_store.dart';
import '../../../services/ai/base_url_validator.dart';

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
    final baseUrl = _baseUrlCtrl.text.trim().isEmpty
        ? ApiCredentialsDefaults.baseUrl
        : _baseUrlCtrl.text.trim();

    // B5 (2026-07-14)：baseUrl HTTPS 校验。非 safe 等级弹窗警告 + 二次确认。
    // safe 包括：HTTPS 任意域名，或 HTTP localhost/loopback/RFC1918 私网
    // （本地开发部署）。非 safe 包括：HTTP 公网（MITM 风险）/非 http scheme
    // /URL 格式无效。
    final safety = BaseUrlValidator.classify(baseUrl);
    if (safety != BaseUrlSafety.safe && !await _confirmUnsafeBaseUrl(safety)) {
      return;
    }

    await widget.store.save(AiCredentials(
      apiKey: _apiKeyCtrl.text.trim(),
      baseUrl: baseUrl,
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

  /// 弹窗确认非 safe baseUrl。返回 true 表示用户确认继续保存。
  Future<bool> _confirmUnsafeBaseUrl(BaseUrlSafety safety) async {
    final warning = BaseUrlValidator.warningMessage(safety);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Base URL 安全校验'),
        content: Text(warning ?? '未知错误'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认继续'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
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
