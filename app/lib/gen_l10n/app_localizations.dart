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

  /// No description provided for @syncTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步'**
  String get syncTitle;

  /// No description provided for @syncSectionData.
  ///
  /// In zh, this message translates to:
  /// **'数据同步'**
  String get syncSectionData;

  /// No description provided for @syncUsername.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get syncUsername;

  /// No description provided for @syncPassword.
  ///
  /// In zh, this message translates to:
  /// **'应用密码'**
  String get syncPassword;

  /// No description provided for @syncUsernameHint.
  ///
  /// In zh, this message translates to:
  /// **'坚果云登录邮箱'**
  String get syncUsernameHint;

  /// No description provided for @syncPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'在坚果云「账户信息 → 安全选项 → 第三方应用管理」生成'**
  String get syncPasswordHint;

  /// No description provided for @syncSaveCredentials.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get syncSaveCredentials;

  /// No description provided for @syncClearCredentials.
  ///
  /// In zh, this message translates to:
  /// **'清除凭据'**
  String get syncClearCredentials;

  /// No description provided for @syncStatusIdle.
  ///
  /// In zh, this message translates to:
  /// **'未同步'**
  String get syncStatusIdle;

  /// No description provided for @syncStatusPushing.
  ///
  /// In zh, this message translates to:
  /// **'上传中…'**
  String get syncStatusPushing;

  /// No description provided for @syncStatusPulling.
  ///
  /// In zh, this message translates to:
  /// **'下载中…'**
  String get syncStatusPulling;

  /// No description provided for @syncStatusSuccess.
  ///
  /// In zh, this message translates to:
  /// **'同步成功'**
  String get syncStatusSuccess;

  /// No description provided for @syncStatusError.
  ///
  /// In zh, this message translates to:
  /// **'同步失败'**
  String get syncStatusError;

  /// No description provided for @syncStatusOffline.
  ///
  /// In zh, this message translates to:
  /// **'离线'**
  String get syncStatusOffline;

  /// No description provided for @syncStatusLabel.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get syncStatusLabel;

  /// No description provided for @syncNow.
  ///
  /// In zh, this message translates to:
  /// **'立即同步'**
  String get syncNow;

  /// No description provided for @syncLastRun.
  ///
  /// In zh, this message translates to:
  /// **'上次同步'**
  String get syncLastRun;

  /// No description provided for @syncNever.
  ///
  /// In zh, this message translates to:
  /// **'从未'**
  String get syncNever;

  /// No description provided for @syncRateLimitedWarning.
  ///
  /// In zh, this message translates to:
  /// **'坚果云限流（30 次/分钟），请稍后再试'**
  String get syncRateLimitedWarning;

  /// No description provided for @syncCredentialsMissing.
  ///
  /// In zh, this message translates to:
  /// **'请先填写账号和应用密码'**
  String get syncCredentialsMissing;

  /// No description provided for @syncPushedAndPulled.
  ///
  /// In zh, this message translates to:
  /// **'上传 {pushed} 条，下载 {pulled} 条'**
  String syncPushedAndPulled(int pushed, int pulled);

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

  /// No description provided for @aiSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 设置'**
  String get aiSettingsTitle;

  /// No description provided for @aiSettingsApiKey.
  ///
  /// In zh, this message translates to:
  /// **'API Key'**
  String get aiSettingsApiKey;

  /// No description provided for @aiSettingsApiKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'sk-开头的密钥'**
  String get aiSettingsApiKeyHint;

  /// No description provided for @aiSettingsBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'Base URL'**
  String get aiSettingsBaseUrl;

  /// No description provided for @aiSettingsModel.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get aiSettingsModel;

  /// No description provided for @aiSettingsSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get aiSettingsSave;

  /// No description provided for @aiSettingsClear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get aiSettingsClear;

  /// No description provided for @aiSettingsShow.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get aiSettingsShow;

  /// No description provided for @aiSettingsHide.
  ///
  /// In zh, this message translates to:
  /// **'隐藏'**
  String get aiSettingsHide;

  /// No description provided for @aiSettingsHelp.
  ///
  /// In zh, this message translates to:
  /// **'API key 仅本地存储，不上传任何服务器。本应用与 DeepSeek 官方无关。'**
  String get aiSettingsHelp;

  /// No description provided for @aiGuideTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 导读'**
  String get aiGuideTitle;

  /// No description provided for @aiGuideModeFull.
  ///
  /// In zh, this message translates to:
  /// **'全书'**
  String get aiGuideModeFull;

  /// No description provided for @aiGuideModeChapter.
  ///
  /// In zh, this message translates to:
  /// **'本章'**
  String get aiGuideModeChapter;

  /// No description provided for @aiGuideModeSelection.
  ///
  /// In zh, this message translates to:
  /// **'选区'**
  String get aiGuideModeSelection;

  /// No description provided for @aiGuideStart.
  ///
  /// In zh, this message translates to:
  /// **'开始'**
  String get aiGuideStart;

  /// No description provided for @aiGuideRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get aiGuideRetry;

  /// No description provided for @aiGuideRegenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get aiGuideRegenerate;

  /// No description provided for @aiGuideCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get aiGuideCopy;

  /// No description provided for @aiGuideExportMarkdown.
  ///
  /// In zh, this message translates to:
  /// **'导出 Markdown'**
  String get aiGuideExportMarkdown;

  /// No description provided for @aiGuideAddToNotes.
  ///
  /// In zh, this message translates to:
  /// **'加入笔记'**
  String get aiGuideAddToNotes;

  /// No description provided for @aiGuideLoadingExtract.
  ///
  /// In zh, this message translates to:
  /// **'正在提取文本…'**
  String get aiGuideLoadingExtract;

  /// No description provided for @aiGuideLoadingGenerate.
  ///
  /// In zh, this message translates to:
  /// **'正在生成…'**
  String get aiGuideLoadingGenerate;

  /// No description provided for @aiGuideCacheHit.
  ///
  /// In zh, this message translates to:
  /// **'(缓存)'**
  String get aiGuideCacheHit;

  /// No description provided for @aiGuideChapterPrefix.
  ///
  /// In zh, this message translates to:
  /// **'第'**
  String get aiGuideChapterPrefix;

  /// No description provided for @aiErrorNoKey.
  ///
  /// In zh, this message translates to:
  /// **'未配置 API key，请到设置页填入。'**
  String get aiErrorNoKey;

  /// No description provided for @aiErrorAuthFailed.
  ///
  /// In zh, this message translates to:
  /// **'API key 无效或已过期。'**
  String get aiErrorAuthFailed;

  /// No description provided for @aiErrorRateLimited.
  ///
  /// In zh, this message translates to:
  /// **'请求过于频繁，请稍后重试。'**
  String get aiErrorRateLimited;

  /// No description provided for @aiErrorServer.
  ///
  /// In zh, this message translates to:
  /// **'服务端异常，请重试。'**
  String get aiErrorServer;

  /// No description provided for @aiErrorNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败，已重试 3 次。'**
  String get aiErrorNetwork;

  /// No description provided for @aiErrorEmptySource.
  ///
  /// In zh, this message translates to:
  /// **'该书无可提取的文本（可能是扫描件）。'**
  String get aiErrorEmptySource;

  /// No description provided for @aiErrorParse.
  ///
  /// In zh, this message translates to:
  /// **'回复解析失败。'**
  String get aiErrorParse;

  /// No description provided for @aiErrorCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消。'**
  String get aiErrorCancelled;

  /// No description provided for @aiActionGoSettings.
  ///
  /// In zh, this message translates to:
  /// **'去设置'**
  String get aiActionGoSettings;

  /// No description provided for @aiActionClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get aiActionClose;

  /// No description provided for @aiCommentLabel.
  ///
  /// In zh, this message translates to:
  /// **'AI 点评'**
  String get aiCommentLabel;

  /// No description provided for @syncStatusTitle.
  ///
  /// In zh, this message translates to:
  /// **'同步状态'**
  String get syncStatusTitle;

  /// No description provided for @syncStatusSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看同步状态与冲突日志'**
  String get syncStatusSubtitle;

  /// No description provided for @syncConflictsSection.
  ///
  /// In zh, this message translates to:
  /// **'冲突日志（30 天）'**
  String get syncConflictsSection;

  /// No description provided for @syncConflictsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无冲突记录'**
  String get syncConflictsEmpty;

  /// No description provided for @syncConflictsClear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get syncConflictsClear;

  /// No description provided for @syncConflictsClearedOk.
  ///
  /// In zh, this message translates to:
  /// **'已清空全部冲突记录'**
  String get syncConflictsClearedOk;

  /// No description provided for @syncConflictItemTitle.
  ///
  /// In zh, this message translates to:
  /// **'{type} · {id}'**
  String syncConflictItemTitle(String type, String id);

  /// No description provided for @syncConflictItemWinnerLocal.
  ///
  /// In zh, this message translates to:
  /// **'本地胜出'**
  String get syncConflictItemWinnerLocal;

  /// No description provided for @syncConflictItemWinnerRemote.
  ///
  /// In zh, this message translates to:
  /// **'远端胜出（{device}）'**
  String syncConflictItemWinnerRemote(String device);

  /// No description provided for @syncConflictItemPreview.
  ///
  /// In zh, this message translates to:
  /// **'远端负载预览'**
  String get syncConflictItemPreview;

  /// No description provided for @syncConflictItemTypeAnnotation.
  ///
  /// In zh, this message translates to:
  /// **'高亮'**
  String get syncConflictItemTypeAnnotation;

  /// No description provided for @syncConflictItemTypeBookNote.
  ///
  /// In zh, this message translates to:
  /// **'笔记'**
  String get syncConflictItemTypeBookNote;

  /// No description provided for @syncConflictItemTypeProgress.
  ///
  /// In zh, this message translates to:
  /// **'进度'**
  String get syncConflictItemTypeProgress;

  /// No description provided for @syncConflictItemTypeBook.
  ///
  /// In zh, this message translates to:
  /// **'图书'**
  String get syncConflictItemTypeBook;

  /// No description provided for @syncIntervalTitle.
  ///
  /// In zh, this message translates to:
  /// **'后台同步节奏'**
  String get syncIntervalTitle;

  /// No description provided for @syncIntervalMinutes.
  ///
  /// In zh, this message translates to:
  /// **'每 {count} 分钟'**
  String syncIntervalMinutes(int count);

  /// No description provided for @syncIntervalOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭（仅手动）'**
  String get syncIntervalOff;

  /// No description provided for @syncIntervalChanged.
  ///
  /// In zh, this message translates to:
  /// **'节奏已更新'**
  String get syncIntervalChanged;

  /// No description provided for @syncBackgroundSection.
  ///
  /// In zh, this message translates to:
  /// **'后台定时'**
  String get syncBackgroundSection;

  /// No description provided for @qaDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'同书问答'**
  String get qaDialogTitle;

  /// No description provided for @qaInputHint.
  ///
  /// In zh, this message translates to:
  /// **'向这本书提问…'**
  String get qaInputHint;

  /// No description provided for @qaSubmitLabel.
  ///
  /// In zh, this message translates to:
  /// **'提问'**
  String get qaSubmitLabel;

  /// No description provided for @qaEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'输入问题，AI 基于本书内容回答'**
  String get qaEmptyHint;

  /// No description provided for @qaErrorNoKey.
  ///
  /// In zh, this message translates to:
  /// **'尚未填写 API key，请在设置中添加'**
  String get qaErrorNoKey;

  /// No description provided for @qaErrorEmptyIndex.
  ///
  /// In zh, this message translates to:
  /// **'本书尚未完成预处理。打开书详情页触发预处理后再提问。'**
  String get qaErrorEmptyIndex;

  /// No description provided for @qaErrorAuth.
  ///
  /// In zh, this message translates to:
  /// **'API key 无效'**
  String get qaErrorAuth;

  /// No description provided for @qaErrorRateLimit.
  ///
  /// In zh, this message translates to:
  /// **'请求过快，请稍后再试'**
  String get qaErrorRateLimit;

  /// No description provided for @qaErrorNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络异常，请检查连接'**
  String get qaErrorNetwork;

  /// No description provided for @qaErrorServer.
  ///
  /// In zh, this message translates to:
  /// **'服务端错误，稍后重试'**
  String get qaErrorServer;

  /// No description provided for @qaErrorParse.
  ///
  /// In zh, this message translates to:
  /// **'AI 响应解析失败'**
  String get qaErrorParse;

  /// No description provided for @preprocessStatusSummarizing.
  ///
  /// In zh, this message translates to:
  /// **'AI 处理中 {current}/{total}'**
  String preprocessStatusSummarizing(String current, String total);

  /// No description provided for @qaStopLabel.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get qaStopLabel;

  /// No description provided for @qaPreprocessInProgress.
  ///
  /// In zh, this message translates to:
  /// **'预处理进行中（{current}/{total}），回答可能不全'**
  String qaPreprocessInProgress(String current, String total);

  /// No description provided for @qaHistoryLabel.
  ///
  /// In zh, this message translates to:
  /// **'最近提问'**
  String get qaHistoryLabel;

  /// No description provided for @qaHistoryDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除该条历史'**
  String get qaHistoryDeleted;

  /// No description provided for @bookDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'书籍详情'**
  String get bookDetailTitle;

  /// No description provided for @bookDetailActionViewNotes.
  ///
  /// In zh, this message translates to:
  /// **'查看笔记'**
  String get bookDetailActionViewNotes;

  /// No description provided for @bookDetailActionReprocess.
  ///
  /// In zh, this message translates to:
  /// **'重新预处理'**
  String get bookDetailActionReprocess;

  /// No description provided for @bookDetailActionAiGuide.
  ///
  /// In zh, this message translates to:
  /// **'AI 导读'**
  String get bookDetailActionAiGuide;

  /// No description provided for @bookDetailActionDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get bookDetailActionDelete;

  /// No description provided for @bookDetailNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到书籍'**
  String get bookDetailNotFound;

  /// No description provided for @bookDetailFieldAuthor.
  ///
  /// In zh, this message translates to:
  /// **'作者：{author}'**
  String bookDetailFieldAuthor(String author);

  /// No description provided for @bookDetailFieldFormat.
  ///
  /// In zh, this message translates to:
  /// **'格式：{format}'**
  String bookDetailFieldFormat(String format);

  /// No description provided for @bookDetailFieldFileSize.
  ///
  /// In zh, this message translates to:
  /// **'文件大小：{size}'**
  String bookDetailFieldFileSize(String size);

  /// No description provided for @bookDetailFieldAddedAt.
  ///
  /// In zh, this message translates to:
  /// **'添加时间：{datetime}'**
  String bookDetailFieldAddedAt(String datetime);

  /// No description provided for @bookDetailFieldLastReadAt.
  ///
  /// In zh, this message translates to:
  /// **'最近阅读：{datetime}'**
  String bookDetailFieldLastReadAt(String datetime);

  /// No description provided for @bookDetailPreprocessIdle.
  ///
  /// In zh, this message translates to:
  /// **'AI 预处理：未开始'**
  String get bookDetailPreprocessIdle;

  /// No description provided for @bookDetailPreprocessChunking.
  ///
  /// In zh, this message translates to:
  /// **'切分章节中'**
  String get bookDetailPreprocessChunking;

  /// No description provided for @bookDetailPreprocessSummarizing.
  ///
  /// In zh, this message translates to:
  /// **'生成摘要中'**
  String get bookDetailPreprocessSummarizing;

  /// No description provided for @bookDetailPreprocessStatusLabel.
  ///
  /// In zh, this message translates to:
  /// **'AI 预处理：{phase} ({current}/{total})'**
  String bookDetailPreprocessStatusLabel(String phase, int current, int total);

  /// No description provided for @bookDetailPreprocessCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get bookDetailPreprocessCancel;

  /// No description provided for @bookDetailPreprocessAuthFailed.
  ///
  /// In zh, this message translates to:
  /// **'API key 无效'**
  String get bookDetailPreprocessAuthFailed;

  /// No description provided for @bookDetailPreprocessGoSettings.
  ///
  /// In zh, this message translates to:
  /// **'去设置'**
  String get bookDetailPreprocessGoSettings;

  /// No description provided for @bookDetailPreprocessFailed.
  ///
  /// In zh, this message translates to:
  /// **'AI 预处理：失败（{reason}）'**
  String bookDetailPreprocessFailed(String reason);

  /// No description provided for @bookDetailPreprocessDone.
  ///
  /// In zh, this message translates to:
  /// **'AI 预处理：完成'**
  String get bookDetailPreprocessDone;

  /// No description provided for @bookDetailPreprocessFailedCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 章预处理失败'**
  String bookDetailPreprocessFailedCount(int count);

  /// No description provided for @bookDetailPreprocessRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get bookDetailPreprocessRetry;

  /// No description provided for @bookDetailDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除书籍？'**
  String get bookDetailDeleteTitle;

  /// No description provided for @bookDetailDeleteBody.
  ///
  /// In zh, this message translates to:
  /// **'《{title}》及其阅读进度和高亮笔记都会被删除，无法恢复。'**
  String bookDetailDeleteBody(String title);

  /// No description provided for @bookDetailDeleteCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get bookDetailDeleteCancel;

  /// No description provided for @bookDetailDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get bookDetailDeleteConfirm;

  /// No description provided for @bookDetailPreprocessUnknownError.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get bookDetailPreprocessUnknownError;

  /// No description provided for @loadingDefaultMessage.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get loadingDefaultMessage;

  /// No description provided for @retryButtonLabel.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retryButtonLabel;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'书库为空'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'导入第一本书，开始阅读之旅'**
  String get libraryEmptySubtitle;

  /// No description provided for @libraryEmptyAction.
  ///
  /// In zh, this message translates to:
  /// **'导入第一本书'**
  String get libraryEmptyAction;

  /// No description provided for @libraryNoSearchResultTitle.
  ///
  /// In zh, this message translates to:
  /// **'无匹配书籍'**
  String get libraryNoSearchResultTitle;

  /// No description provided for @libraryNoSearchResultAction.
  ///
  /// In zh, this message translates to:
  /// **'清空筛选'**
  String get libraryNoSearchResultAction;

  /// No description provided for @notesEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'本书暂无高亮与笔记'**
  String get notesEmptyTitle;

  /// No description provided for @notesEmptyAction.
  ///
  /// In zh, this message translates to:
  /// **'去阅读器添加'**
  String get notesEmptyAction;

  /// No description provided for @notesLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get notesLoadFailed;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索高亮与笔记...'**
  String get searchHint;

  /// No description provided for @searchEmptyKeywordHint.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词搜索全部高亮'**
  String get searchEmptyKeywordHint;

  /// No description provided for @searchEmptyResultTitle.
  ///
  /// In zh, this message translates to:
  /// **'无匹配结果'**
  String get searchEmptyResultTitle;

  /// No description provided for @searchFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败'**
  String get searchFailed;
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
