// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '记听';

  @override
  String get home => '主页';

  @override
  String get listen => '听取';

  @override
  String get write => '书写';

  @override
  String get settings => '设置';

  @override
  String get createNote => '创建记听';

  @override
  String get newNote => '新记听';

  @override
  String get title => '标题';

  @override
  String get description => '描述';

  @override
  String get optional => '(可选)';

  @override
  String get cancel => '取消';

  @override
  String get create => '创建';

  @override
  String get delete => '删除';

  @override
  String get search => '搜索';

  @override
  String get searchNotes => '搜索笔记...';

  @override
  String get noNotesTitle => '创建您的第一个记听';

  @override
  String get noNotesSubtitle => '在一个集成空间中管理\n语音、文本和手写内容';

  @override
  String get noSearchResults => '无搜索结果';

  @override
  String noSearchResultsSubtitle(String query) {
    return '未找到与\"$query\"匹配的笔记';
  }

  @override
  String get clearSearch => '清除搜索';

  @override
  String get deleteNote => '删除笔记';

  @override
  String get deleteNoteConfirm => '确定要删除此笔记吗？\n所有文件将一起删除。';

  @override
  String get noteDeleted => '笔记已删除';

  @override
  String noteCreated(String title) {
    return '\'$title\' 创建完成';
  }

  @override
  String noteSelected(String title) {
    return '已选择 $title';
  }

  @override
  String freeLimitReached(int limit) {
    return '免费版本最多只能创建 $limit 个记听。';
  }

  @override
  String get upgradeToStandard => '升级到标准版';

  @override
  String get upgradeFeatures =>
      '升级到标准版可获得：\n\n• 无限制创建记听\n• 无限制文件存储\n• 去除广告\n• 云端同步';

  @override
  String get later => '稍后';

  @override
  String get upgrade => '升级';

  @override
  String get adBannerText => '广告区域 - 升级标准版移除';

  @override
  String get enterTitle => '请输入标题';

  @override
  String createNoteFailed(String error) {
    return '创建记听失败：$error';
  }

  @override
  String deleteNoteFailed(String error) {
    return '删除笔记失败：$error';
  }

  @override
  String get upgradeComingSoon => '升级功能即将推出';
}
