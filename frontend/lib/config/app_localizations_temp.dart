import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  String get appTitle => 'Litten';
  String get homeTitle => locale.languageCode == 'ko' ? '홈' : 'Home';
  String get recordingTitle => locale.languageCode == 'ko' ? '듣기' : 'Listen';
  String get writingTitle => locale.languageCode == 'ko' ? '쓰기' : 'Write';
  String get settingsTitle => locale.languageCode == 'ko' ? '설정' : 'Settings';
  String get createLitten => locale.languageCode == 'ko' ? '리튼 생성' : 'Create Litten';
  String get emptyLittenTitle => locale.languageCode == 'ko' ? '리튼을 생성하거나 선택하세요' : 'Create or select a Litten';
  String get emptyLittenDescription => locale.languageCode == 'ko' 
      ? '하단의 \'리튼 생성\' 버튼을 사용해서 첫 번째 노트를 시작하세요' 
      : 'Use the \'Create Litten\' button below to start your first note';
  String get startRecording => locale.languageCode == 'ko' ? '녹음 시작' : 'Start Recording';
  String get stopRecording => locale.languageCode == 'ko' ? '녹음 중지' : 'Stop Recording';
  String get recording => locale.languageCode == 'ko' ? '녹음 중...' : 'Recording...';
  String get textWriting => locale.languageCode == 'ko' ? '텍스트 쓰기' : 'Text Writing';
  String get handwriting => locale.languageCode == 'ko' ? '필기' : 'Handwriting';
  String get save => locale.languageCode == 'ko' ? '저장' : 'Save';
  String get delete => locale.languageCode == 'ko' ? '삭제' : 'Delete';
  String get upgrade => locale.languageCode == 'ko' ? '업그레이드' : 'Upgrade';
  String get removeAds => locale.languageCode == 'ko' ? '광고 제거' : 'Remove Ads';
  String get freeVersion => locale.languageCode == 'ko' ? '무료' : 'Free';
  String get standardVersion => locale.languageCode == 'ko' ? '스탠다드' : 'Standard';
  String get premiumVersion => locale.languageCode == 'ko' ? '프리미엄' : 'Premium';
  String get theme => locale.languageCode == 'ko' ? '테마' : 'Theme';
  String get language => locale.languageCode == 'ko' ? '언어' : 'Language';
  String get classicBlue => locale.languageCode == 'ko' ? '클래식 블루' : 'Classic Blue';
  String get darkMode => locale.languageCode == 'ko' ? '다크 모드' : 'Dark Mode';
  String get natureGreen => locale.languageCode == 'ko' ? '네이처 그린' : 'Nature Green';
  String get sunsetOrange => locale.languageCode == 'ko' ? '선셋 오렌지' : 'Sunset Orange';
  String get monochromeGrey => locale.languageCode == 'ko' ? '모노크롬 그레이' : 'Monochrome Grey';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ko'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}