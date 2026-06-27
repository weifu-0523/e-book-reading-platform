import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen_l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'智阅'**
  String get appTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsSectionReading.
  ///
  /// In zh, this message translates to:
  /// **'阅读'**
  String get settingsSectionReading;

  /// No description provided for @settingsSectionFonts.
  ///
  /// In zh, this message translates to:
  /// **'字体'**
  String get settingsSectionFonts;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsSectionLanguage;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get settingsSectionAbout;

  /// No description provided for @settingsTypographyProfiles.
  ///
  /// In zh, this message translates to:
  /// **'排版预设'**
  String get settingsTypographyProfiles;

  /// No description provided for @settingsCustomFonts.
  ///
  /// In zh, this message translates to:
  /// **'自定义字体'**
  String get settingsCustomFonts;

  /// No description provided for @settingsTheme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get settingsTheme;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @settingsAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于智阅'**
  String get settingsAbout;

  /// No description provided for @settingsSourceCode.
  ///
  /// In zh, this message translates to:
  /// **'源代码'**
  String get settingsSourceCode;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @fontManagementTitle.
  ///
  /// In zh, this message translates to:
  /// **'字体管理'**
  String get fontManagementTitle;

  /// No description provided for @fontManagementSystemFonts.
  ///
  /// In zh, this message translates to:
  /// **'系统字体'**
  String get fontManagementSystemFonts;

  /// No description provided for @fontManagementImportFont.
  ///
  /// In zh, this message translates to:
  /// **'导入字体'**
  String get fontManagementImportFont;

  /// No description provided for @fontManagementImportButton.
  ///
  /// In zh, this message translates to:
  /// **'导入 .ttf / .otf 文件'**
  String get fontManagementImportButton;

  /// No description provided for @fontManagementEmpty.
  ///
  /// In zh, this message translates to:
  /// **'尚未导入任何字体。点击上方按钮选择 .ttf 或 .otf 文件。'**
  String get fontManagementEmpty;

  /// No description provided for @fontManagementImportCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消导入'**
  String get fontManagementImportCancelled;

  /// No description provided for @fontManagementImportExists.
  ///
  /// In zh, this message translates to:
  /// **'该字体已存在：{name}'**
  String fontManagementImportExists(String name);

  /// No description provided for @fontManagementImportInvalid.
  ///
  /// In zh, this message translates to:
  /// **'字体文件无效：{reason}'**
  String fontManagementImportInvalid(String reason);

  /// No description provided for @fontManagementImportReadError.
  ///
  /// In zh, this message translates to:
  /// **'读取文件失败：{message}'**
  String fontManagementImportReadError(String message);

  /// No description provided for @fontManagementImportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已导入：{name}'**
  String fontManagementImportSuccess(String name);

  /// No description provided for @fontManagementRename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get fontManagementRename;

  /// No description provided for @fontManagementDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get fontManagementDelete;

  /// No description provided for @fontManagementRenamePrompt.
  ///
  /// In zh, this message translates to:
  /// **'新的显示名称'**
  String get fontManagementRenamePrompt;

  /// No description provided for @fontManagementDeleteConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除字体'**
  String get fontManagementDeleteConfirmTitle;

  /// No description provided for @fontManagementDeleteConfirmBody.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除 “{name}” 吗？'**
  String fontManagementDeleteConfirmBody(String name);

  /// No description provided for @fontManagementCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get fontManagementCancel;

  /// No description provided for @fontManagementConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get fontManagementConfirm;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
