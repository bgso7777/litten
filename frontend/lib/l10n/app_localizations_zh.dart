// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '利腾';

  @override
  String get homeTitle => '首页';

  @override
  String get recordingTitle => '听写';

  @override
  String get writingTitle => '写作';

  @override
  String get settingsTitle => '设置';

  @override
  String get createLitten => '创建笔记本';

  @override
  String get emptyLittenTitle => '创建或选择一个笔记本';

  @override
  String get emptyLittenDescription => '使用下方的\'创建笔记本\'按钮开始您的第一个笔记';

  @override
  String get startRecording => '开始录音';

  @override
  String get stopRecording => '停止录音';

  @override
  String get recording => '录音中...';

  @override
  String get textWriting => '文字写作';

  @override
  String get handwriting => '手写';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get upgrade => '升级';

  @override
  String get removeAds => '移除广告';

  @override
  String get freeVersion => '免费';

  @override
  String get standardVersion => '标准';

  @override
  String get premiumVersion => '高级';

  @override
  String get theme => '主题';

  @override
  String get language => '语言';

  @override
  String get classicBlue => '经典蓝';

  @override
  String get darkMode => '深色模式';

  @override
  String get natureGreen => '自然绿';

  @override
  String get sunsetOrange => '日落橙';

  @override
  String get monochromeGrey => '单色灰';

  @override
  String get accountAndSubscription => '账户和订阅';

  @override
  String get userStatus => '用户状态';

  @override
  String get usageStatistics => '使用统计';

  @override
  String get appSettings => '应用设置';

  @override
  String get startScreen => '开始屏幕';

  @override
  String get recordingSettings => '录音设置';

  @override
  String get maxRecordingTime => '最大录音时间';

  @override
  String get audioQuality => '音频质量';

  @override
  String get writingSettings => '写作设置';

  @override
  String get autoSaveInterval => '自动保存间隔';

  @override
  String get defaultFont => '默认字体';

  @override
  String get freeWithAds => '免费（含广告）';

  @override
  String get standardMonthly => '标准（\$4.99/月）';

  @override
  String get premiumMonthly => '高级（\$9.99/月）';

  @override
  String get littensCount => '个笔记本';

  @override
  String get filesCount => '个文件';

  @override
  String get removeAdsAndUnlimited => '移除广告和无限功能';

  @override
  String get maxRecordingTimeValue => '1小时';

  @override
  String get standardQuality => '标准';

  @override
  String get autoSaveIntervalValue => '3分钟';

  @override
  String get systemFont => '系统字体';

  @override
  String get appVersion => '利腾 v1.0.0';

  @override
  String get appDescription => '跨平台集成笔记应用';

  @override
  String get close => '关闭';

  @override
  String get cancel => '取消';

  @override
  String get addSchedule => 'Add Schedule';

  @override
  String get selectDate => 'Select Date';

  @override
  String get selectStartTime => 'Select Start Time';

  @override
  String get selectEndTime => 'Select End Time';

  @override
  String get startTime => 'Start Time';

  @override
  String get endTime => 'End Time';

  @override
  String get date => 'Date';

  @override
  String get notes => 'Notes';

  @override
  String get scheduleNotesHint => 'Enter notes for this schedule (optional)';

  @override
  String get confirm => 'Confirm';

  @override
  String get enableNotifications => 'Enable Notifications';

  @override
  String get frequency => 'Frequency';

  @override
  String get enabledNotifications => 'Enabled Notifications';

  @override
  String get notifications => 'Notifications';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get clearAll => 'Clear All';

  @override
  String get freeUserLimits => '免费用户限制：';

  @override
  String get maxLittens => '• 笔记本';

  @override
  String get maxRecordingFiles => '• 录音文件';

  @override
  String get maxTextFiles => '• 文本文件';

  @override
  String get maxHandwritingFiles => '• 手写文件';

  @override
  String get maxLittensLimit => '最多5个';

  @override
  String get maxRecordingFilesLimit => '最多10个';

  @override
  String get maxTextFilesLimit => '最多5个';

  @override
  String get maxHandwritingFilesLimit => '最多5个';

  @override
  String get upgradeToStandard => '升级到标准计划？';

  @override
  String get upgradeBenefits => '• 移除广告\n• 无限笔记本和文件\n• \$4.99/月';

  @override
  String get upgradedToStandard => '已升级到标准计划！（模拟）';

  @override
  String get selectTheme => '选择主题';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get totalFiles => '总文件数';

  @override
  String get noLittenSelected => '请选择一个笔记本';

  @override
  String get selectLittenFirst => '要开始听写，请先从首页选项卡选择或创建一个笔记本。';

  @override
  String get goToHome => '前往首页';

  @override
  String get noAudioFilesYet => '还没有音频文件';

  @override
  String get startFirstRecording => '点击下方按钮开始您的第一次录音';

  @override
  String get selectLittenFirstMessage => '请先选择或创建一个笔记本。';

  @override
  String get recordingStoppedAndSaved => '录音已停止并保存文件。';

  @override
  String get recordingStarted => '录音已开始。';

  @override
  String get recordingFailed => '录音启动失败。请检查权限。';

  @override
  String get playbackFailed => '播放失败。';

  @override
  String get deleteFile => '删除文件';

  @override
  String confirmDeleteFile(String fileName) {
    return '您确定要删除文件 $fileName 吗？';
  }

  @override
  String get fileDeleted => '文件已删除。';

  @override
  String get selectPlaybackSpeed => '选择播放速度';

  @override
  String get playbackSpeed => '播放速度';

  @override
  String get recordingInProgress => '录音中...';

  @override
  String get created => '创建';

  @override
  String get title => '标题';

  @override
  String get create => '创建';

  @override
  String get pleaseEnterTitle => '请输入标题。';

  @override
  String littenCreated(String title) {
    return '$title 笔记本已创建。';
  }

  @override
  String get error => '错误';

  @override
  String get renameLitten => '重命名笔记本';

  @override
  String get newName => '新名称';

  @override
  String get change => '更改';

  @override
  String littenRenamed(String newName) {
    return '笔记本名称已更改为 \'$newName\'。';
  }

  @override
  String get deleteLitten => '删除笔记本';

  @override
  String confirmDeleteLitten(String title) {
    return '\'$title\' 笔记本将被删除。\n\n此操作无法撤销，所有相关文件将一起删除。';
  }

  @override
  String get freeUserLimitMessage => '免费用户最多只能创建5个笔记本。升级以创建无限数量！';

  @override
  String littenDeleted(String title) {
    return '$title 笔记本已删除。';
  }

  @override
  String confirmDeleteLittenMessage(String title) {
    return '\'$title\' 笔记本将被删除。\n\n此操作无法撤销，所有相关文件将一起删除。';
  }

  @override
  String get defaultLitten => '默认笔记本';

  @override
  String get lecture => '讲座';

  @override
  String get meeting => '会议';

  @override
  String get defaultLittenDescription => '未选择笔记本时创建的文件将存储在此默认空间中。';

  @override
  String get lectureDescription => '在此处存储与讲座相关的文件。';

  @override
  String get meetingDescription => '在此处存储与会议相关的文件。';

  @override
  String get selectLanguageDescription => '请选择应用使用的语言';

  @override
  String get themeRecommendationMessage => '已自动选择适合所选语言的推荐主题';

  @override
  String get recommended => '推荐';

  @override
  String get previous => '上一步';

  @override
  String get next => '下一步';

  @override
  String get getStarted => '开始使用';

  @override
  String get welcomeDescription => '集成听写、写作和手绘的\n智能笔记应用';

  @override
  String get listen => '听写';

  @override
  String get listenDescription => '语音录制和回放';

  @override
  String get write => '写作';

  @override
  String get writeDescription => '文本创建和编辑';

  @override
  String get draw => '手绘';

  @override
  String get drawDescription => '在图像上手写';
}
