// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '리튼';

  @override
  String get homeTitle => '홈';

  @override
  String get recordingTitle => '듣기';

  @override
  String get writingTitle => '쓰기';

  @override
  String get settingsTitle => '설정';

  @override
  String get createLitten => '리튼 생성';

  @override
  String get emptyLittenTitle => '리튼을 생성하거나 선택하세요';

  @override
  String get emptyLittenDescription => '하단의 \'리튼 생성\' 버튼을 사용해서 첫 번째 노트를 시작하세요';

  @override
  String get startRecording => '녹음 시작';

  @override
  String get stopRecording => '녹음 중지';

  @override
  String get recording => '녹음 중...';

  @override
  String get textWriting => '텍스트 쓰기';

  @override
  String get handwriting => '필기';

  @override
  String get save => '저장';

  @override
  String get delete => '삭제';

  @override
  String get upgrade => '업그레이드';

  @override
  String get removeAds => '광고 제거';

  @override
  String get freeVersion => '무료';

  @override
  String get standardVersion => '스탠다드';

  @override
  String get premiumVersion => '프리미엄';

  @override
  String get theme => '테마';

  @override
  String get language => '언어';

  @override
  String get classicBlue => '클래식 블루';

  @override
  String get darkMode => '다크 모드';

  @override
  String get natureGreen => '네이처 그린';

  @override
  String get sunsetOrange => '선셋 오렌지';

  @override
  String get monochromeGrey => '모노크롬 그레이';

  @override
  String get accountAndSubscription => '계정 및 구독';

  @override
  String get userStatus => '사용자 상태';

  @override
  String get usageStatistics => '사용량 통계';

  @override
  String get appSettings => '앱 설정';

  @override
  String get startScreen => '시작 화면';

  @override
  String get recordingSettings => '듣기 설정';

  @override
  String get maxRecordingTime => '최대 녹음 시간';

  @override
  String get audioQuality => '오디오 품질';

  @override
  String get writingSettings => '쓰기 설정';

  @override
  String get autoSaveInterval => '자동 저장 간격';

  @override
  String get defaultFont => '기본 폰트';

  @override
  String get freeWithAds => '무료 (광고 포함)';

  @override
  String get standardMonthly => '스탠다드 (₩4.99/월)';

  @override
  String get premiumMonthly => '프리미엄 (₩9.99/월)';

  @override
  String get littensCount => '개 리튼';

  @override
  String get filesCount => '개 파일';

  @override
  String get removeAdsAndUnlimited => '광고 제거 및 무제한 기능';

  @override
  String get maxRecordingTimeValue => '1시간';

  @override
  String get standardQuality => '표준';

  @override
  String get autoSaveIntervalValue => '3분';

  @override
  String get systemFont => '시스템 폰트';

  @override
  String get appVersion => '리튼 v1.0.0';

  @override
  String get appDescription => '크로스 플랫폼 통합 노트 앱';

  @override
  String get close => '닫기';

  @override
  String get cancel => '취소';

  @override
  String get freeUserLimits => '무료 사용자 제한:';

  @override
  String get maxLittens => '• 리튼';

  @override
  String get maxRecordingFiles => '• 녹음 파일';

  @override
  String get maxTextFiles => '• 텍스트 파일';

  @override
  String get maxHandwritingFiles => '• 필기 파일';

  @override
  String get maxLittensLimit => '최대 5개';

  @override
  String get maxRecordingFilesLimit => '최대 10개';

  @override
  String get maxTextFilesLimit => '최대 5개';

  @override
  String get maxHandwritingFilesLimit => '최대 5개';

  @override
  String get upgradeToStandard => '스탠다드 플랜으로 업그레이드하시겠습니까?';

  @override
  String get upgradeBenefits => '• 광고 제거\n• 무제한 리튼 및 파일\n• 월 ₩4.99';

  @override
  String get upgradedToStandard => '스탠다드 플랜으로 업그레이드되었습니다! (시뮬레이션)';

  @override
  String get selectTheme => '테마 선택';

  @override
  String get selectLanguage => '언어 선택';

  @override
  String get totalFiles => '총 파일 수';

  @override
  String get noLittenSelected => '리튼을 선택해주세요';

  @override
  String get selectLittenFirst => '듣기를 시작하려면 먼저 홈 탭에서 리튼을 선택하거나 생성해주세요.';

  @override
  String get goToHome => '홈으로 이동';

  @override
  String get noAudioFilesYet => '아직 듣기 파일이 없습니다';

  @override
  String get startFirstRecording => '아래 버튼을 눌러 첫 번째 듣기를 시작하세요';

  @override
  String get selectLittenFirstMessage => '먼저 리튼을 선택하거나 생성해주세요.';

  @override
  String get recordingStoppedAndSaved => '듣기가 중지되고 파일이 저장되었습니다.';

  @override
  String get recordingStarted => '듣기가 시작되었습니다.';

  @override
  String get recordingFailed => '듣기 시작에 실패했습니다. 권한을 확인해주세요.';

  @override
  String get playbackFailed => '재생에 실패했습니다.';

  @override
  String get deleteFile => '파일 삭제';

  @override
  String confirmDeleteFile(String fileName) {
    return '$fileName 파일을 삭제하시겠습니까?';
  }

  @override
  String get fileDeleted => '파일이 삭제되었습니다.';

  @override
  String get selectPlaybackSpeed => '재생 속도 선택';

  @override
  String get playbackSpeed => '재생 속도';

  @override
  String get recordingInProgress => '듣기 중...';

  @override
  String get created => '생성';

  @override
  String get title => '제목';

  @override
  String get create => '생성';

  @override
  String get pleaseEnterTitle => '제목을 입력해주세요.';

  @override
  String littenCreated(String title) {
    return '$title 리튼이 생성되었습니다.';
  }

  @override
  String get error => '오류';

  @override
  String get renameLitten => '리튼 이름 변경';

  @override
  String get newName => '새 이름';

  @override
  String get change => '변경';

  @override
  String littenRenamed(String newName) {
    return '리튼 이름이 \'$newName\'로 변경되었습니다.';
  }

  @override
  String get deleteLitten => '리튼 삭제';

  @override
  String confirmDeleteLitten(String title) {
    return '\'$title\' 리튼을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없으며, 관련된 모든 파일이 함께 삭제됩니다.';
  }

  @override
  String get freeUserLimitMessage =>
      '무료 사용자는 최대 5개의 리튼만 생성할 수 있습니다. 업그레이드하여 무제한으로 생성하세요!';

  @override
  String littenDeleted(String title) {
    return '$title 리튼이 삭제되었습니다.';
  }

  @override
  String confirmDeleteLittenMessage(String title) {
    return '\'$title\' 리튼을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없으며, 관련된 모든 파일이 함께 삭제됩니다.';
  }

  @override
  String get defaultLitten => '기본리튼';

  @override
  String get lecture => '강의';

  @override
  String get meeting => '회의';

  @override
  String get defaultLittenDescription => '리튼을 선택하지 않고 생성된 파일들이 저장되는 기본 공간입니다.';

  @override
  String get lectureDescription => '강의에 관련된 파일들을 저장하세요.';

  @override
  String get meetingDescription => '회의에 관련된 파일들을 저장하세요.';
}
