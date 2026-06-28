// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '智阅';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSectionReading => '阅读';

  @override
  String get settingsSectionFonts => '字体';

  @override
  String get settingsSectionAppearance => '外观';

  @override
  String get settingsSectionLanguage => '语言';

  @override
  String get settingsSectionAbout => '关于';

  @override
  String get settingsTypographyProfiles => '排版预设';

  @override
  String get settingsCustomFonts => '自定义字体';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsAbout => '关于智阅';

  @override
  String get syncTitle => '同步';

  @override
  String get syncSectionData => '数据同步';

  @override
  String get syncUsername => '账号';

  @override
  String get syncPassword => '应用密码';

  @override
  String get syncUsernameHint => '坚果云登录邮箱';

  @override
  String get syncPasswordHint => '在坚果云「账户信息 → 安全选项 → 第三方应用管理」生成';

  @override
  String get syncSaveCredentials => '保存';

  @override
  String get syncClearCredentials => '清除凭据';

  @override
  String get syncStatusIdle => '未同步';

  @override
  String get syncStatusPushing => '上传中…';

  @override
  String get syncStatusPulling => '下载中…';

  @override
  String get syncStatusSuccess => '同步成功';

  @override
  String get syncStatusError => '同步失败';

  @override
  String get syncStatusOffline => '离线';

  @override
  String get syncStatusLabel => '状态';

  @override
  String get syncNow => '立即同步';

  @override
  String get syncLastRun => '上次同步';

  @override
  String get syncNever => '从未';

  @override
  String get syncRateLimitedWarning => '坚果云限流（30 次/分钟），请稍后再试';

  @override
  String get syncCredentialsMissing => '请先填写账号和应用密码';

  @override
  String syncPushedAndPulled(int pushed, int pulled) {
    return '上传 $pushed 条，下载 $pulled 条';
  }

  @override
  String get settingsSourceCode => '源代码';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get fontManagementTitle => '字体管理';

  @override
  String get fontManagementSystemFonts => '系统字体';

  @override
  String get fontManagementImportFont => '导入字体';

  @override
  String get fontManagementImportButton => '导入 .ttf / .otf 文件';

  @override
  String get fontManagementEmpty => '尚未导入任何字体。点击上方按钮选择 .ttf 或 .otf 文件。';

  @override
  String get fontManagementImportCancelled => '已取消导入';

  @override
  String fontManagementImportExists(String name) {
    return '该字体已存在：$name';
  }

  @override
  String fontManagementImportInvalid(String reason) {
    return '字体文件无效：$reason';
  }

  @override
  String fontManagementImportReadError(String message) {
    return '读取文件失败：$message';
  }

  @override
  String fontManagementImportSuccess(String name) {
    return '已导入：$name';
  }

  @override
  String get fontManagementRename => '重命名';

  @override
  String get fontManagementDelete => '删除';

  @override
  String get fontManagementRenamePrompt => '新的显示名称';

  @override
  String get fontManagementDeleteConfirmTitle => '删除字体';

  @override
  String fontManagementDeleteConfirmBody(String name) {
    return '确定要删除 “$name” 吗？';
  }

  @override
  String get fontManagementCancel => '取消';

  @override
  String get fontManagementConfirm => '确认';
}
