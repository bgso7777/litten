// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => '리튼';

  @override
  String get home => '홈';

  @override
  String get listen => '듣기';

  @override
  String get write => '쓰기';

  @override
  String get settings => '설정';

  @override
  String get createNote => '리튼 생성';

  @override
  String get newNote => '새 리튼';

  @override
  String get title => '제목';

  @override
  String get description => '설명';

  @override
  String get optional => '(선택사항)';

  @override
  String get cancel => '취소';

  @override
  String get create => '생성';

  @override
  String get delete => '삭제';

  @override
  String get search => '검색';

  @override
  String get searchNotes => '노트 검색...';

  @override
  String get noNotesTitle => '첫 번째 리튼을 만들어보세요';

  @override
  String get noNotesSubtitle => '음성, 텍스트, 필기를 하나의 공간에서\n통합 관리할 수 있습니다';

  @override
  String get noSearchResults => '검색 결과가 없습니다';

  @override
  String noSearchResultsSubtitle(String query) {
    return '\"$query\"와 일치하는 노트를 찾을 수 없습니다';
  }

  @override
  String get clearSearch => '검색어 지우기';

  @override
  String get deleteNote => '노트 삭제';

  @override
  String get deleteNoteConfirm => '이 노트를 삭제하시겠습니까?\n모든 파일이 함께 삭제됩니다.';

  @override
  String get noteDeleted => '노트가 삭제되었습니다';

  @override
  String noteCreated(String title) {
    return '\'$title\' 생성 완료';
  }

  @override
  String noteSelected(String title) {
    return '$title 선택됨';
  }

  @override
  String freeLimitReached(int limit) {
    return '무료 버전에서는 최대 $limit개의 리튼만 생성할 수 있습니다.';
  }

  @override
  String get upgradeToStandard => '스탠다드로 업그레이드';

  @override
  String get upgradeFeatures =>
      '스탠다드 버전으로 업그레이드하면:\n\n• 무제한 리튼 생성\n• 무제한 파일 저장\n• 광고 제거\n• 클라우드 동기화';

  @override
  String get later => '나중에';

  @override
  String get upgrade => '업그레이드';

  @override
  String get adBannerText => '광고 영역 - 스탠다드 업그레이드로 제거';

  @override
  String get enterTitle => '제목을 입력해주세요';

  @override
  String createNoteFailed(String error) {
    return '리튼 생성 실패: $error';
  }

  @override
  String deleteNoteFailed(String error) {
    return '노트 삭제 실패: $error';
  }

  @override
  String get upgradeComingSoon => '업그레이드 기능은 곧 제공될 예정입니다';
}
