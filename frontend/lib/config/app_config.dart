import 'package:logger/logger.dart';

/// 앱 전체 설정을 관리하는 클래스
class AppConfig {
  static final Logger logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  // 디버그 모드 여부
  static const bool isDebugMode = true;
  
  // 앱 버전 정보
  static const String appVersion = '1.0.0';
  static const int buildNumber = 1;
  
  // 앱 기본 정보
  static const String appName = '리튼';
  static const String appDescription = '듣기와 쓰기를 하나로';
  
  // 구독 플랜 설정
  static const Map<String, dynamic> subscriptionPlans = {
    'free': {
      'name': '무료',
      'maxLittens': 5,
      'maxAudioFiles': 10,
      'maxTextFiles': 5,
      'maxDrawingFiles': 5,
      'hasAds': true,
      'hasCloudSync': false,
    },
    'standard': {
      'name': '스탠다드',
      'maxLittens': -1, // 무제한
      'maxAudioFiles': -1,
      'maxTextFiles': -1,
      'maxDrawingFiles': -1,
      'hasAds': false,
      'hasCloudSync': false,
      'price': 4.99,
    },
    'premium': {
      'name': '프리미엄',
      'maxLittens': -1,
      'maxAudioFiles': -1,
      'maxTextFiles': -1,
      'maxDrawingFiles': -1,
      'hasAds': false,
      'hasCloudSync': true,
      'price': 9.99,
    },
  };
  
  // 기본 설정값
  static const Map<String, dynamic> defaultSettings = {
    'maxRecordingDuration': 3600, // 1시간 (초)
    'autoSaveInterval': 60, // 1분 (초)
    'defaultLanguage': 'en',
    'defaultTheme': 'classicBlue',
  };
  
  // 로깅 헬퍼 메서드
  static void logDebug(String message, [dynamic error, StackTrace? stackTrace]) {
    if (isDebugMode) {
      logger.d(message, error: error, stackTrace: stackTrace);
    }
  }
  
  static void logInfo(String message, [dynamic error, StackTrace? stackTrace]) {
    logger.i(message, error: error, stackTrace: stackTrace);
  }
  
  static void logWarning(String message, [dynamic error, StackTrace? stackTrace]) {
    logger.w(message, error: error, stackTrace: stackTrace);
  }
  
  static void logError(String message, [dynamic error, StackTrace? stackTrace]) {
    logger.e(message, error: error, stackTrace: stackTrace);
  }
}