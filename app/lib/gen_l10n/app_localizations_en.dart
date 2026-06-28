// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Zhi Yue';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionReading => 'Reading';

  @override
  String get settingsSectionFonts => 'Fonts';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionLanguage => 'Language';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsTypographyProfiles => 'Typography Profiles';

  @override
  String get settingsCustomFonts => 'Custom Fonts';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsAbout => 'About Zhi Yue';

  @override
  String get syncTitle => 'Sync';

  @override
  String get syncSectionData => 'Data Sync';

  @override
  String get syncUsername => 'Account';

  @override
  String get syncPassword => 'App Password';

  @override
  String get syncUsernameHint => 'Jianguoyun login email';

  @override
  String get syncPasswordHint =>
      'Generate at Jianguoyun: Account Info → Security → Third-Party App Management';

  @override
  String get syncSaveCredentials => 'Save';

  @override
  String get syncClearCredentials => 'Clear credentials';

  @override
  String get syncStatusIdle => 'Not synced';

  @override
  String get syncStatusPushing => 'Uploading…';

  @override
  String get syncStatusPulling => 'Downloading…';

  @override
  String get syncStatusSuccess => 'Sync succeeded';

  @override
  String get syncStatusError => 'Sync failed';

  @override
  String get syncStatusOffline => 'Offline';

  @override
  String get syncStatusLabel => 'Status';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncLastRun => 'Last sync';

  @override
  String get syncNever => 'Never';

  @override
  String get syncRateLimitedWarning => 'Jianguoyun rate limit (30/min) — try later';

  @override
  String get syncCredentialsMissing => 'Please enter account and app password first';

  @override
  String syncPushedAndPulled(int pushed, int pulled) {
    return 'Pushed $pushed, pulled $pulled';
  }

  @override
  String get settingsSourceCode => 'Source Code';

  @override
  String get themeSystem => 'Follow System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageSystem => 'Follow System';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get fontManagementTitle => 'Font Management';

  @override
  String get fontManagementSystemFonts => 'System Fonts';

  @override
  String get fontManagementImportFont => 'Import Font';

  @override
  String get fontManagementImportButton => 'Import .ttf / .otf file';

  @override
  String get fontManagementEmpty =>
      'No fonts imported yet. Tap the button above to pick a .ttf or .otf file.';

  @override
  String get fontManagementImportCancelled => 'Import cancelled';

  @override
  String fontManagementImportExists(String name) {
    return 'Font already exists: $name';
  }

  @override
  String fontManagementImportInvalid(String reason) {
    return 'Invalid font file: $reason';
  }

  @override
  String fontManagementImportReadError(String message) {
    return 'Failed to read file: $message';
  }

  @override
  String fontManagementImportSuccess(String name) {
    return 'Imported: $name';
  }

  @override
  String get fontManagementRename => 'Rename';

  @override
  String get fontManagementDelete => 'Delete';

  @override
  String get fontManagementRenamePrompt => 'New display name';

  @override
  String get fontManagementDeleteConfirmTitle => 'Delete font';

  @override
  String fontManagementDeleteConfirmBody(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get fontManagementCancel => 'Cancel';

  @override
  String get fontManagementConfirm => 'Confirm';
}
