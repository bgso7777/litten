import 'package:flutter/material.dart';

class AppConfig {
  // 앱 정보
  static const String appName = 'Litten';
  static const String appVersion = '1.0.0';
  
  // 무료 버전 제한
  static const int maxNotesForFree = 5;
  static const int maxAudioFilesPerNoteForFree = 2;
  static const int maxTextFilesPerNoteForFree = 1;
  static const int maxHandwritingFilesPerNoteForFree = 1;
  
  // 지원 언어 목록 (30개)
  static const List<Locale> supportedLocales = [
    Locale('en', ''), // 영어 (기본값)
    Locale('zh', ''), // 중국어
    Locale('hi', ''), // 힌디어
    Locale('es', ''), // 스페인어
    Locale('fr', ''), // 프랑스어
    Locale('ar', ''), // 아랍어
    Locale('bn', ''), // 벵골어
    Locale('ru', ''), // 러시아어
    Locale('pt', ''), // 포르투갈어
    Locale('ur', ''), // 우르두어
    Locale('id', ''), // 인도네시아어
    Locale('de', ''), // 독일어
    Locale('ja', ''), // 일본어
    Locale('sw', ''), // 스와힐리어
    Locale('mr', ''), // 마라티어
    Locale('te', ''), // 텔루구어
    Locale('tr', ''), // 터키어
    Locale('ta', ''), // 타밀어
    Locale('fa', ''), // 페르시아어
    Locale('ko', ''), // 한국어
    Locale('uk', ''), // 우크라이나어
    Locale('it', ''), // 이탈리아어
    Locale('tl', ''), // 타갈로그어
    Locale('pl', ''), // 폴란드어
    Locale('ps', ''), // 파슈토어
    Locale('ms', ''), // 말레이어
    Locale('ro', ''), // 로마니아어
    Locale('nl', ''), // 네덜란드어
    Locale('ha', ''), // 하우사어
    Locale('th', ''), // 태국어
  ];
  
  // RTL 언어 목록
  static const List<String> rtlLanguages = [
    'ar', 'fa', 'ur', 'ps'
  ];
  
  // 언어별 선호 테마 매핑
  static const Map<String, String> languageThemeMapping = {
    // 아시아권 - Classic Blue
    'ko': 'classic_blue',
    'ja': 'classic_blue',
    'zh': 'classic_blue',
    
    // 유럽권 - Dark Mode
    'de': 'dark_mode',
    'fr': 'dark_mode',
    'it': 'dark_mode',
    'es': 'dark_mode',
    'pt': 'dark_mode',
    'ru': 'dark_mode',
    'uk': 'dark_mode',
    'pl': 'dark_mode',
    'ro': 'dark_mode',
    'nl': 'dark_mode',
    
    // 아메리카권 - Nature Green
    'en': 'nature_green',
    
    // 중동/아프리카권 - Sunset Orange
    'ar': 'sunset_orange',
    'fa': 'sunset_orange',
    'ha': 'sunset_orange',
    
    // 남아시아권 - Sunset Orange
    'hi': 'sunset_orange',
    'bn': 'sunset_orange',
    'ur': 'sunset_orange',
    'mr': 'sunset_orange',
    'te': 'sunset_orange',
    'ta': 'sunset_orange',
    
    // 동남아시아권 - Nature Green
    'id': 'nature_green',
    'ms': 'nature_green',
    'th': 'nature_green',
    'tl': 'nature_green',
    
    // 아프리카 - Sunset Orange
    'sw': 'sunset_orange',
    'ps': 'sunset_orange',
    
    // 기타 - Monochrome Grey
    'tr': 'monochrome_grey',
  };
  
  // 기본 테마 (매핑에 없는 언어용)
  static const String defaultTheme = 'monochrome_grey';
  
  // 오디오 설정
  static const List<double> audioPlaybackSpeeds = [1.0, 1.2, 1.5, 2.0];
  static const int maxRecordingDurationMinutes = 60;
  
  // 자동 저장 간격 옵션 (초)
  static const List<int> autoSaveIntervals = [10, 30, 60, 180, 300, 600];
  static const int defaultAutoSaveInterval = 60;
  
  // 파일 크기 제한
  static const int maxFileSizeMB = 10;
  
  // 광고 설정
  static const bool showAdsForFreeUsers = true;
  static const int adBannerHeight = 50;
}

// 사용자 구독 타입
enum SubscriptionType {
  free,
  standard,
  premium,
}

// 파일 타입
enum FileType {
  audio,
  text,
  handwriting,
  convertedImage,
}