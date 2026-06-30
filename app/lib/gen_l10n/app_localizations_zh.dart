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

  @override
  String get aiSettingsTitle => 'AI 设置';

  @override
  String get aiSettingsApiKey => 'API Key';

  @override
  String get aiSettingsApiKeyHint => 'sk-开头的密钥';

  @override
  String get aiSettingsBaseUrl => 'Base URL';

  @override
  String get aiSettingsModel => '模型';

  @override
  String get aiSettingsSave => '保存';

  @override
  String get aiSettingsClear => '清空';

  @override
  String get aiSettingsShow => '显示';

  @override
  String get aiSettingsHide => '隐藏';

  @override
  String get aiSettingsHelp => 'API key 仅本地存储，不上传任何服务器。本应用与 DeepSeek 官方无关。';

  @override
  String get aiGuideTitle => 'AI 导读';

  @override
  String get aiGuideModeFull => '全书';

  @override
  String get aiGuideModeChapter => '本章';

  @override
  String get aiGuideModeSelection => '选区';

  @override
  String get aiGuideStart => '开始';

  @override
  String get aiGuideRetry => '重试';

  @override
  String get aiGuideRegenerate => '重新生成';

  @override
  String get aiGuideCopy => '复制';

  @override
  String get aiGuideExportMarkdown => '导出 Markdown';

  @override
  String get aiGuideAddToNotes => '加入笔记';

  @override
  String get aiGuideLoadingExtract => '正在提取文本…';

  @override
  String get aiGuideLoadingGenerate => '正在生成…';

  @override
  String get aiGuideCacheHit => '(缓存)';

  @override
  String get aiGuideChapterPrefix => '第';

  @override
  String get aiErrorNoKey => '未配置 API key，请到设置页填入。';

  @override
  String get aiErrorAuthFailed => 'API key 无效或已过期。';

  @override
  String get aiErrorRateLimited => '请求过于频繁，请稍后重试。';

  @override
  String get aiErrorServer => '服务端异常，请重试。';

  @override
  String get aiErrorNetwork => '网络连接失败，已重试 3 次。';

  @override
  String get aiErrorEmptySource => '该书无可提取的文本（可能是扫描件）。';

  @override
  String get aiErrorParse => '回复解析失败。';

  @override
  String get aiErrorCancelled => '已取消。';

  @override
  String get aiActionGoSettings => '去设置';

  @override
  String get aiActionClose => '关闭';

  @override
  String get aiCommentLabel => 'AI 点评';

  @override
  String get syncStatusTitle => '同步状态';

  @override
  String get syncStatusSubtitle => '查看同步状态与冲突日志';

  @override
  String get syncConflictsSection => '冲突日志（30 天）';

  @override
  String get syncConflictsEmpty => '暂无冲突记录';

  @override
  String get syncConflictsClear => '清空';

  @override
  String get syncConflictsClearedOk => '已清空全部冲突记录';

  @override
  String syncConflictItemTitle(String type, String id) {
    return '$type · $id';
  }

  @override
  String get syncConflictItemWinnerLocal => '本地胜出';

  @override
  String syncConflictItemWinnerRemote(String device) {
    return '远端胜出（$device）';
  }

  @override
  String get syncConflictItemPreview => '远端负载预览';

  @override
  String get syncConflictItemTypeAnnotation => '高亮';

  @override
  String get syncConflictItemTypeBookNote => '笔记';

  @override
  String get syncConflictItemTypeProgress => '进度';

  @override
  String get syncConflictItemTypeBook => '图书';

  @override
  String get syncIntervalTitle => '后台同步节奏';

  @override
  String syncIntervalMinutes(int count) {
    return '每 $count 分钟';
  }

  @override
  String get syncIntervalOff => '关闭（仅手动）';

  @override
  String get syncIntervalChanged => '节奏已更新';

  @override
  String get syncBackgroundSection => '后台定时';

  @override
  String get qaDialogTitle => '同书问答';

  @override
  String get qaInputHint => '向这本书提问…';

  @override
  String get qaSubmitLabel => '提问';

  @override
  String get qaEmptyHint => '输入问题，AI 基于本书内容回答';

  @override
  String get qaErrorNoKey => '尚未填写 API key，请在设置中添加';

  @override
  String get qaErrorEmptyIndex => '本书尚未完成预处理。打开书详情页触发预处理后再提问。';

  @override
  String get qaErrorAuth => 'API key 无效';

  @override
  String get qaErrorRateLimit => '请求过快，请稍后再试';

  @override
  String get qaErrorNetwork => '网络异常，请检查连接';

  @override
  String get qaErrorServer => '服务端错误，稍后重试';

  @override
  String get qaErrorParse => 'AI 响应解析失败';

  @override
  String preprocessStatusChunking(String current, String total) {
    return '切片中 $current/$total';
  }

  @override
  String preprocessStatusSummarizing(String current, String total) {
    return 'AI 处理中 $current/$total';
  }

  @override
  String get preprocessCancelLabel => '取消';

  @override
  String get preprocessRetryLabel => '重新预处理';

  @override
  String preprocessFailedChapters(String count) {
    return '$count 章预处理失败';
  }

  @override
  String get qaStopLabel => '停止';

  @override
  String qaPreprocessInProgress(String current, String total) {
    return '预处理进行中（$current/$total），回答可能不全';
  }

  @override
  String get qaHistoryLabel => '最近提问';

  @override
  String get qaHistoryDeleted => '已删除该条历史';

  @override
  String get bookDetailTitle => '书籍详情';

  @override
  String get bookDetailActionViewNotes => '查看笔记';

  @override
  String get bookDetailActionReprocess => '重新预处理';

  @override
  String get bookDetailActionAiGuide => 'AI 导读';

  @override
  String get bookDetailActionDelete => '删除';

  @override
  String get bookDetailNotFound => '未找到书籍';

  @override
  String bookDetailFieldAuthor(String author) {
    return '作者：$author';
  }

  @override
  String bookDetailFieldFormat(String format) {
    return '格式：$format';
  }

  @override
  String bookDetailFieldFileSize(String size) {
    return '文件大小：$size';
  }

  @override
  String bookDetailFieldAddedAt(String datetime) {
    return '添加时间：$datetime';
  }

  @override
  String bookDetailFieldLastReadAt(String datetime) {
    return '最近阅读：$datetime';
  }

  @override
  String get bookDetailPreprocessIdle => 'AI 预处理：未开始';

  @override
  String get bookDetailPreprocessChunking => '切分章节中';

  @override
  String get bookDetailPreprocessSummarizing => '生成摘要中';

  @override
  String bookDetailPreprocessStatusLabel(String phase, int current, int total) {
    return 'AI 预处理：$phase ($current/$total)';
  }

  @override
  String get bookDetailPreprocessCancel => '取消';

  @override
  String get bookDetailPreprocessAuthFailed => 'API key 无效';

  @override
  String get bookDetailPreprocessGoSettings => '去设置';

  @override
  String bookDetailPreprocessFailed(String reason) {
    return 'AI 预处理：失败（$reason）';
  }

  @override
  String get bookDetailPreprocessDone => 'AI 预处理：完成';

  @override
  String bookDetailPreprocessFailedCount(int count) {
    return '$count 章预处理失败';
  }

  @override
  String get bookDetailPreprocessRetry => '重试';

  @override
  String get bookDetailDeleteTitle => '删除书籍？';

  @override
  String bookDetailDeleteBody(String title) {
    return '《$title》及其阅读进度和高亮笔记都会被删除，无法恢复。';
  }

  @override
  String get bookDetailDeleteCancel => '取消';

  @override
  String get bookDetailDeleteConfirm => '删除';

  @override
  String get bookDetailPreprocessUnknownError => '未知';
}
