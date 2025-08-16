// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'Litten';

  @override
  String get home => 'ホーム';

  @override
  String get listen => '聴く';

  @override
  String get write => '書く';

  @override
  String get settings => '設定';

  @override
  String get createNote => 'Littenを作成';

  @override
  String get newNote => '新しいLitten';

  @override
  String get title => 'タイトル';

  @override
  String get description => '説明';

  @override
  String get optional => '(オプション)';

  @override
  String get cancel => 'キャンセル';

  @override
  String get create => '作成';

  @override
  String get delete => '削除';

  @override
  String get search => '検索';

  @override
  String get searchNotes => 'ノートを検索...';

  @override
  String get noNotesTitle => '最初のLittenを作成しましょう';

  @override
  String get noNotesSubtitle => '音声、テキスト、手書きを\n1つの統合されたスペースで管理';

  @override
  String get noSearchResults => '検索結果なし';

  @override
  String noSearchResultsSubtitle(String query) {
    return '\"$query\"に一致するノートが見つかりません';
  }

  @override
  String get clearSearch => '検索をクリア';

  @override
  String get deleteNote => 'ノートを削除';

  @override
  String get deleteNoteConfirm => 'このノートを削除してよろしいですか？\nすべてのファイルが一緒に削除されます。';

  @override
  String get noteDeleted => 'ノートを削除しました';

  @override
  String noteCreated(String title) {
    return '\'$title\'を作成しました';
  }

  @override
  String noteSelected(String title) {
    return '$titleを選択しました';
  }

  @override
  String freeLimitReached(int limit) {
    return '無料版では$limit個のノートのみ作成可能です。';
  }

  @override
  String get upgradeToStandard => 'スタンダードにアップグレード';

  @override
  String get upgradeFeatures =>
      'スタンダードにアップグレードして以下を取得:\n\n• 無制限ノート作成\n• 無制限ファイルストレージ\n• 広告の削除\n• クラウド同期';

  @override
  String get later => '後で';

  @override
  String get upgrade => 'アップグレード';

  @override
  String get adBannerText => '広告エリア - スタンダードアップグレードで削除';

  @override
  String get enterTitle => 'タイトルを入力してください';

  @override
  String createNoteFailed(String error) {
    return 'ノートの作成に失敗: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return 'ノートの削除に失敗: $error';
  }

  @override
  String get upgradeComingSoon => 'アップグレード機能は近日中に利用可能になります';
}
