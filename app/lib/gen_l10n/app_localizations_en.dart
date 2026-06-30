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
  String get syncRateLimitedWarning =>
      'Jianguoyun rate limit (30/min) — try later';

  @override
  String get syncCredentialsMissing =>
      'Please enter account and app password first';

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

  @override
  String get aiSettingsTitle => 'AI Settings';

  @override
  String get aiSettingsApiKey => 'API Key';

  @override
  String get aiSettingsApiKeyHint => 'sk-prefixed key';

  @override
  String get aiSettingsBaseUrl => 'Base URL';

  @override
  String get aiSettingsModel => 'Model';

  @override
  String get aiSettingsSave => 'Save';

  @override
  String get aiSettingsClear => 'Clear';

  @override
  String get aiSettingsShow => 'Show';

  @override
  String get aiSettingsHide => 'Hide';

  @override
  String get aiSettingsHelp =>
      'API key is stored locally only, never uploaded. This app is not affiliated with DeepSeek.';

  @override
  String get aiGuideTitle => 'AI Guide';

  @override
  String get aiGuideModeFull => 'Full';

  @override
  String get aiGuideModeChapter => 'Chapter';

  @override
  String get aiGuideModeSelection => 'Selection';

  @override
  String get aiGuideStart => 'Start';

  @override
  String get aiGuideRetry => 'Retry';

  @override
  String get aiGuideRegenerate => 'Regenerate';

  @override
  String get aiGuideCopy => 'Copy';

  @override
  String get aiGuideExportMarkdown => 'Export Markdown';

  @override
  String get aiGuideAddToNotes => 'Add to Notes';

  @override
  String get aiGuideLoadingExtract => 'Extracting text...';

  @override
  String get aiGuideLoadingGenerate => 'Generating...';

  @override
  String get aiGuideCacheHit => '(cached)';

  @override
  String get aiGuideChapterPrefix => 'Chapter';

  @override
  String get aiErrorNoKey =>
      'No API key configured. Please add one in Settings.';

  @override
  String get aiErrorAuthFailed => 'API key invalid or expired.';

  @override
  String get aiErrorRateLimited => 'Too many requests. Please retry shortly.';

  @override
  String get aiErrorServer => 'Server error. Please retry.';

  @override
  String get aiErrorNetwork => 'Network failed after 3 retries.';

  @override
  String get aiErrorEmptySource =>
      'No extractable text (likely a scanned book).';

  @override
  String get aiErrorParse => 'Failed to parse response.';

  @override
  String get aiErrorCancelled => 'Cancelled.';

  @override
  String get aiActionGoSettings => 'Go to Settings';

  @override
  String get aiActionClose => 'Close';

  @override
  String get aiCommentLabel => 'AI Comment';

  @override
  String get syncStatusTitle => 'Sync Status';

  @override
  String get syncStatusSubtitle => 'View sync status and conflict log';

  @override
  String get syncConflictsSection => 'Conflicts (last 30 days)';

  @override
  String get syncConflictsEmpty => 'No conflicts recorded';

  @override
  String get syncConflictsClear => 'Clear';

  @override
  String get syncConflictsClearedOk => 'All conflict records cleared';

  @override
  String syncConflictItemTitle(String type, String id) {
    return '$type · $id';
  }

  @override
  String get syncConflictItemWinnerLocal => 'Local won';

  @override
  String syncConflictItemWinnerRemote(String device) {
    return 'Remote won ($device)';
  }

  @override
  String get syncConflictItemPreview => 'Remote payload preview';

  @override
  String get syncConflictItemTypeAnnotation => 'Highlight';

  @override
  String get syncConflictItemTypeBookNote => 'Note';

  @override
  String get syncConflictItemTypeProgress => 'Progress';

  @override
  String get syncConflictItemTypeBook => 'Book';

  @override
  String get syncIntervalTitle => 'Background Sync Interval';

  @override
  String syncIntervalMinutes(int count) {
    return 'Every $count minutes';
  }

  @override
  String get syncIntervalOff => 'Off (manual only)';

  @override
  String get syncIntervalChanged => 'Interval updated';

  @override
  String get syncBackgroundSection => 'Background';

  @override
  String get qaDialogTitle => 'Ask the book';

  @override
  String get qaInputHint => 'Ask a question about this book…';

  @override
  String get qaSubmitLabel => 'Ask';

  @override
  String get qaEmptyHint =>
      'Type a question — AI answers from this book\'s content';

  @override
  String get qaErrorNoKey => 'No API key set. Add one in Settings.';

  @override
  String get qaErrorEmptyIndex =>
      'This book hasn\'t been preprocessed yet. Open book details to trigger preprocessing first.';

  @override
  String get qaErrorAuth => 'API key invalid';

  @override
  String get qaErrorRateLimit => 'Rate limited. Try again shortly.';

  @override
  String get qaErrorNetwork => 'Network error. Check your connection.';

  @override
  String get qaErrorServer => 'Server error. Try again later.';

  @override
  String get qaErrorParse => 'Failed to parse AI response.';

  @override
  String preprocessStatusSummarizing(String current, String total) {
    return 'AI processing $current/$total';
  }

  @override
  String get qaStopLabel => 'Stop';

  @override
  String qaPreprocessInProgress(String current, String total) {
    return 'Preprocessing ($current/$total) — answers may be incomplete';
  }

  @override
  String get qaHistoryLabel => 'Recent';

  @override
  String get qaHistoryDeleted => 'History entry deleted';

  @override
  String get bookDetailTitle => 'Book Details';

  @override
  String get bookDetailActionViewNotes => 'View Notes';

  @override
  String get bookDetailActionReprocess => 'Reprocess';

  @override
  String get bookDetailActionAiGuide => 'AI Guide';

  @override
  String get bookDetailActionDelete => 'Delete';

  @override
  String get bookDetailNotFound => 'Book not found';

  @override
  String bookDetailFieldAuthor(String author) {
    return 'Author: $author';
  }

  @override
  String bookDetailFieldFormat(String format) {
    return 'Format: $format';
  }

  @override
  String bookDetailFieldFileSize(String size) {
    return 'File size: $size';
  }

  @override
  String bookDetailFieldAddedAt(String datetime) {
    return 'Added: $datetime';
  }

  @override
  String bookDetailFieldLastReadAt(String datetime) {
    return 'Last read: $datetime';
  }

  @override
  String get bookDetailPreprocessIdle => 'AI preprocessing: not started';

  @override
  String get bookDetailPreprocessChunking => 'Chunking chapters';

  @override
  String get bookDetailPreprocessSummarizing => 'Generating summaries';

  @override
  String bookDetailPreprocessStatusLabel(String phase, int current, int total) {
    return 'AI preprocessing: $phase ($current/$total)';
  }

  @override
  String get bookDetailPreprocessCancel => 'Cancel';

  @override
  String get bookDetailPreprocessAuthFailed => 'API key invalid';

  @override
  String get bookDetailPreprocessGoSettings => 'Go to Settings';

  @override
  String bookDetailPreprocessFailed(String reason) {
    return 'AI preprocessing: failed ($reason)';
  }

  @override
  String get bookDetailPreprocessDone => 'AI preprocessing: done';

  @override
  String bookDetailPreprocessFailedCount(int count) {
    return '$count chapter(s) failed preprocessing';
  }

  @override
  String get bookDetailPreprocessRetry => 'Retry';

  @override
  String get bookDetailDeleteTitle => 'Delete book?';

  @override
  String bookDetailDeleteBody(String title) {
    return '\"$title\" and all its reading progress and highlights will be deleted. This cannot be undone.';
  }

  @override
  String get bookDetailDeleteCancel => 'Cancel';

  @override
  String get bookDetailDeleteConfirm => 'Delete';

  @override
  String get bookDetailPreprocessUnknownError => 'unknown';

  @override
  String get loadingDefaultMessage => 'Loading…';

  @override
  String get retryButtonLabel => 'Retry';

  @override
  String get libraryEmptyTitle => 'Library is empty';

  @override
  String get libraryEmptySubtitle => 'Import your first book to start reading';

  @override
  String get libraryEmptyAction => 'Import first book';

  @override
  String get libraryNoSearchResultTitle => 'No matching books';

  @override
  String get libraryNoSearchResultAction => 'Clear filters';

  @override
  String get notesEmptyTitle => 'No highlights or notes yet';

  @override
  String get notesEmptyAction => 'Open reader to add';

  @override
  String get notesLoadFailed => 'Failed to load';

  @override
  String get searchHint => 'Search highlights and notes...';

  @override
  String get searchEmptyKeywordHint =>
      'Enter a keyword to search all highlights';

  @override
  String get searchEmptyResultTitle => 'No matching results';

  @override
  String get searchFailed => 'Search failed';
}
