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

/// AI baseUrl 安全分级。
///
/// 2026-07-14 baseline sweep (v1.11.8-alpha B5)：用户在 AI 设置页录入的
/// baseUrl 之前无 HTTPS 校验，存在 MITM/钓鱼风险——攻击者诱导用户填
/// `http://evil.com` 即可截获 API key + 对话内容。本 helper 提供分级判断：
///
/// - [safe]：HTTPS 任意域名，或 HTTP localhost / loopback / RFC1918 私网
///   （本地开发部署场景）。
/// - [unsafeHttp]：HTTP 公网域名或公网 IP，有 MITM 风险。UI 应弹窗警告
///   并要求二次确认。
/// - [invalidScheme]：非 http/https scheme（ftp/file 等）。
/// - [invalid]：URL 解析失败或为空。
enum BaseUrlSafety { safe, unsafeHttp, invalidScheme, invalid }

/// AI baseUrl 安全校验器。
class BaseUrlValidator {
  BaseUrlValidator._();

  /// 判断 [baseUrl] 的安全等级。
  ///
  /// 判断逻辑：
  /// 1. 解析 URL，失败 → [invalid]
  /// 2. scheme 非 http/https → [invalidScheme]
  /// 3. https → [safe]
  /// 4. http + host 是 localhost/127.0.0.0/8/10.0.0.0/8/172.16.0.0/12/
  ///    192.168.0.0/16/IPv6 loopback 或 [::1] → [safe]
  /// 5. http + 其他 host → [unsafeHttp]
  static BaseUrlSafety classify(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return BaseUrlSafety.invalid;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      return BaseUrlSafety.invalid;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return BaseUrlSafety.invalidScheme;
    }
    if (uri.host.isEmpty) {
      return BaseUrlSafety.invalid;
    }
    if (scheme == 'https') return BaseUrlSafety.safe;

    // scheme == 'http'：检查 host 是否为本机/私网
    if (_isLocalOrPrivateHost(uri.host)) {
      return BaseUrlSafety.safe;
    }
    return BaseUrlSafety.unsafeHttp;
  }

  /// 判断 host 是否为本机或 RFC1918 私网地址。
  static bool _isLocalOrPrivateHost(String host) {
    // 移除 IPv6 方括号
    final h = host.startsWith('[') && host.endsWith(']')
        ? host.substring(1, host.length - 1)
        : host;

    if (h == 'localhost') return true;
    if (h == '::1') return true; // IPv6 loopback

    // IPv4 解析
    final parts = h.split('.');
    if (parts.length == 4) {
      final octets = parts.tryIntList();
      if (octets != null && octets.every((o) => o >= 0 && o <= 255)) {
        final a = octets[0];
        final b = octets[1];
        if (a == 127) return true; // loopback 127.0.0.0/8
        if (a == 10) return true; // private 10.0.0.0/8
        if (a == 192 && b == 168) return true; // private 192.168.0.0/16
        if (a == 172 && b >= 16 && b <= 31) return true; // private 172.16.0.0/12
      }
    }
    return false;
  }

  /// 返回非安全等级的警告文案；安全返回 null。
  static String? warningMessage(BaseUrlSafety safety) {
    switch (safety) {
      case BaseUrlSafety.safe:
        return null;
      case BaseUrlSafety.unsafeHttp:
        return 'HTTP 公网地址有被中间人截获 API Key 与对话内容的风险。'
            '建议改用 HTTPS。如确认要使用，请二次确认。';
      case BaseUrlSafety.invalidScheme:
        return '仅支持 http 或 https 协议。';
      case BaseUrlSafety.invalid:
        return 'URL 格式无效，应形如 https://api.example.com。';
    }
  }
}

/// String list 转 int list 的私有扩展（避免全局污染）。
extension _StringIntList on List<String> {
  List<int>? tryIntList() {
    final result = <int>[];
    for (final p in this) {
      final v = int.tryParse(p);
      if (v == null) return null;
      result.add(v);
    }
    return result;
  }
}
