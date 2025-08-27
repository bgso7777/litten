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
}
