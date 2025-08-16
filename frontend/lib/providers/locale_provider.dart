import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../config/app_config.dart';
import '../services/preferences_service.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en', '');
  
  Locale get locale => _locale;
  
  LocaleProvider() {
    _loadLocale();
  }
  
  // 저장된 언어 설정 로드
  Future<void> _loadLocale() async {
    final savedLanguageCode = PreferencesService.getLanguageCode();
    
    if (savedLanguageCode != null) {
      // 저장된 언어가 있으면 사용
      _locale = Locale(savedLanguageCode, '');
    } else {
      // 저장된 언어가 없으면 시스템 언어 자동 감지
      await _detectSystemLanguage();
    }
    
    notifyListeners();
  }
  
  // 시스템 언어 자동 감지
  Future<void> _detectSystemLanguage() async {
    final systemLocale = ui.window.locale;
    final systemLanguageCode = systemLocale.languageCode;
    
    // 지원하는 언어인지 확인
    final supportedLanguageCodes = AppConfig.supportedLocales
        .map((locale) => locale.languageCode)
        .toList();
    
    if (supportedLanguageCodes.contains(systemLanguageCode)) {
      _locale = Locale(systemLanguageCode, '');
      
      // 자동 감지된 언어를 저장
      await PreferencesService.setLanguageCode(systemLanguageCode);
      
      // 언어에 따른 기본 테마도 자동 설정
      await _setDefaultThemeForLanguage(systemLanguageCode);
    } else {
      // 지원하지 않는 언어면 영어를 기본값으로
      _locale = const Locale('en', '');
      await PreferencesService.setLanguageCode('en');
      await _setDefaultThemeForLanguage('en');
    }
  }
  
  // 언어에 따른 기본 테마 설정
  Future<void> _setDefaultThemeForLanguage(String languageCode) async {
    // 첫 실행 시에만 언어에 따른 테마를 자동 설정
    final isFirstLaunch = PreferencesService.isFirstLaunch();
    final savedTheme = PreferencesService.getThemeName();
    
    // 이미 사용자가 테마를 설정했거나 첫 실행이 아니면 변경하지 않음
    if (savedTheme != null && !isFirstLaunch) return;
    
    final defaultTheme = AppConfig.languageThemeMapping[languageCode] 
        ?? AppConfig.defaultTheme;
    
    await PreferencesService.setThemeName(defaultTheme);
    
    debugPrint('언어별 테마 자동 설정: $languageCode -> $defaultTheme');
  }
  
  // 언어 변경
  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    
    _locale = locale;
    await PreferencesService.setLanguageCode(locale.languageCode);
    notifyListeners();
  }
  
  // 언어 코드로 언어 변경
  Future<void> setLanguageByCode(String languageCode) async {
    await setLocale(Locale(languageCode, ''));
  }
  
  // 현재 언어가 RTL(Right-to-Left)인지 확인
  bool get isRTL {
    return AppConfig.rtlLanguages.contains(_locale.languageCode);
  }
  
  // 현재 언어의 표시명 가져오기
  String getLanguageDisplayName(String languageCode) {
    const languageNames = {
      'en': 'English',
      'zh': '简体中文',
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
    
    return languageNames[languageCode] ?? languageCode.toUpperCase();
  }
}