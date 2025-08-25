import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';

/// 다국어 지원 Provider - 30개 언어
class LocaleProvider with ChangeNotifier {
  Locale _locale = const Locale('en');
  
  /// 지원 언어 목록 (30개)
  static const List<Locale> supportedLocales = [
    Locale('en'), // 영어 (기본값)
    Locale('zh'), // 중국어
    Locale('hi'), // 힌디어
    Locale('es'), // 스페인어
    Locale('fr'), // 프랑스어
    Locale('ar'), // 아랍어
    Locale('bn'), // 벵골어
    Locale('ru'), // 러시아어
    Locale('pt'), // 포르투갈어
    Locale('ur'), // 우르두어
    Locale('id'), // 인도네시아어
    Locale('de'), // 독일어
    Locale('ja'), // 일본어
    Locale('sw'), // 스와힐리어
    Locale('mr'), // 마라티어
    Locale('te'), // 텔루구어
    Locale('tr'), // 터키어
    Locale('ta'), // 타밀어
    Locale('fa'), // 페르시아어
    Locale('ko'), // 한국어
    Locale('uk'), // 우크라이나어
    Locale('it'), // 이탈리아어
    Locale('tl'), // 타갈로그어
    Locale('pl'), // 폴란드어
    Locale('ps'), // 파슈토어
    Locale('ms'), // 말레이어
    Locale('ro'), // 로마니아어
    Locale('nl'), // 네덜란드어
    Locale('ha'), // 하우사어
    Locale('th'), // 태국어
  ];
  
  /// 언어 이름 매핑
  static const Map<String, String> languageNames = {
    'en': 'English',
    'zh': '中文',
    'hi': 'हिन्दी',
    'es': 'Español',
    'fr': 'Français',
    'ar': 'العربية',
    'bn': 'বাংলা',
    'ru': 'Русский',
    'pt': 'Português',
    'ur': 'اردو',
    'id': 'Bahasa Indonesia',
    'de': 'Deutsch',
    'ja': '日本語',
    'sw': 'Kiswahili',
    'mr': 'मराठी',
    'te': 'తెలుగు',
    'tr': 'Türkçe',
    'ta': 'தமிழ்',
    'fa': 'فارسی',
    'ko': '한국어',
    'uk': 'Українська',
    'it': 'Italiano',
    'tl': 'Filipino',
    'pl': 'Polski',
    'ps': 'پښتو',
    'ms': 'Bahasa Melayu',
    'ro': 'Română',
    'nl': 'Nederlands',
    'ha': 'Hausa',
    'th': 'ไทย',
  };
  
  /// RTL(오른쪽에서 왼쪽) 언어 목록
  static const Set<String> rtlLanguages = {
    'ar', // 아랍어
    'ur', // 우르두어
    'fa', // 페르시아어
    'ps', // 파슈토어
  };
  
  LocaleProvider() {
    _initializeLocale();
  }
  
  /// 현재 로케일
  Locale get locale => _locale;
  
  /// 현재 언어 코드
  String get languageCode => _locale.languageCode;
  
  /// 현재 언어 이름
  String get currentLanguageName => languageNames[_locale.languageCode] ?? 'Unknown';
  
  /// RTL 여부
  bool get isRTL => rtlLanguages.contains(_locale.languageCode);
  
  /// 로케일 초기화
  Future<void> _initializeLocale() async {
    AppConfig.logDebug('LocaleProvider._initializeLocale - 로케일 초기화 시작');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString('language');
      
      if (savedLanguage != null && _isSupportedLanguage(savedLanguage)) {
        await setLocale(Locale(savedLanguage), saveToPrefs: false);
        AppConfig.logInfo('LocaleProvider._initializeLocale - 저장된 언어 복원: $savedLanguage');
      } else {
        // 시스템 언어 자동 감지
        final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
        final systemLanguage = systemLocale.languageCode;
        
        if (_isSupportedLanguage(systemLanguage)) {
          await setLocale(Locale(systemLanguage), saveToPrefs: true);
          AppConfig.logInfo('LocaleProvider._initializeLocale - 시스템 언어 감지: $systemLanguage');
        } else {
          // 기본 언어 (영어) 설정
          await setLocale(const Locale('en'), saveToPrefs: true);
          AppConfig.logInfo('LocaleProvider._initializeLocale - 기본 언어(영어) 설정');
        }
      }
    } catch (error, stackTrace) {
      AppConfig.logError('LocaleProvider._initializeLocale - 로케일 초기화 실패', error, stackTrace);
      // 기본 언어로 폴백
      await setLocale(const Locale('en'), saveToPrefs: false);
    }
  }
  
  /// 로케일 변경
  Future<void> setLocale(Locale locale, {bool saveToPrefs = true}) async {
    AppConfig.logDebug('LocaleProvider.setLocale - 로케일 변경: ${locale.languageCode}');
    
    if (!_isSupportedLanguage(locale.languageCode)) {
      AppConfig.logWarning('LocaleProvider.setLocale - 지원하지 않는 언어: ${locale.languageCode}');
      return;
    }
    
    if (_locale.languageCode == locale.languageCode) {
      AppConfig.logDebug('LocaleProvider.setLocale - 동일한 언어로 변경 시도: ${locale.languageCode}');
      return;
    }
    
    try {
      _locale = locale;
      
      if (saveToPrefs) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('language', locale.languageCode);
        AppConfig.logInfo('LocaleProvider.setLocale - 언어 저장 완료: ${locale.languageCode}');
      }
      
      notifyListeners();
      AppConfig.logInfo('LocaleProvider.setLocale - 로케일 변경 완료: ${languageNames[locale.languageCode]}');
    } catch (error, stackTrace) {
      AppConfig.logError('LocaleProvider.setLocale - 로케일 변경 실패', error, stackTrace);
      rethrow;
    }
  }
  
  /// 시스템 언어로 설정
  Future<void> setSystemLocale() async {
    AppConfig.logDebug('LocaleProvider.setSystemLocale - 시스템 언어로 설정');
    
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final systemLanguage = systemLocale.languageCode;
    
    if (_isSupportedLanguage(systemLanguage)) {
      await setLocale(Locale(systemLanguage));
      AppConfig.logInfo('LocaleProvider.setSystemLocale - 시스템 언어 적용: $systemLanguage');
    } else {
      AppConfig.logWarning('LocaleProvider.setSystemLocale - 시스템 언어 지원하지 않음: $systemLanguage');
    }
  }
  
  /// 지원 언어 확인
  bool _isSupportedLanguage(String languageCode) {
    return supportedLocales.any((locale) => locale.languageCode == languageCode);
  }
  
  /// 언어별 정보 가져오기
  Map<String, dynamic> getLanguageInfo(String languageCode) {
    if (!_isSupportedLanguage(languageCode)) {
      return {
        'code': languageCode,
        'name': 'Unknown',
        'isRTL': false,
        'isSupported': false,
      };
    }
    
    return {
      'code': languageCode,
      'name': languageNames[languageCode] ?? 'Unknown',
      'isRTL': rtlLanguages.contains(languageCode),
      'isSupported': true,
    };
  }
  
  /// 모든 지원 언어 정보
  List<Map<String, dynamic>> get allSupportedLanguages {
    return supportedLocales.map((locale) {
      return getLanguageInfo(locale.languageCode);
    }).toList();
  }
  
  /// 언어 검색
  List<Map<String, dynamic>> searchLanguages(String query) {
    if (query.isEmpty) return allSupportedLanguages;
    
    final lowercaseQuery = query.toLowerCase();
    
    return allSupportedLanguages.where((lang) {
      final code = lang['code'] as String;
      final name = lang['name'] as String;
      
      return code.toLowerCase().contains(lowercaseQuery) ||
             name.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }
}