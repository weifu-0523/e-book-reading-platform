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
