import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';
import '../../config/theme_config.dart';

/// 테마 관리 Provider
class ThemeProvider with ChangeNotifier {
  String _currentTheme = 'classicBlue';
  ThemeData _themeData = ThemeConfig.classicBlueTheme;
  
  ThemeProvider() {
    _initializeTheme();
  }
  
  /// 현재 테마 키
  String get currentTheme => _currentTheme;
  
  /// 현재 테마 데이터
  ThemeData get themeData => _themeData;
  
  /// 현재 테마 이름
  String get currentThemeName => ThemeConfig.themeNames[_currentTheme] ?? 'Unknown';
  
  /// 모든 테마 목록
  Map<String, String> get availableThemes => ThemeConfig.themeNames;
  
  /// 테마 초기화
  Future<void> _initializeTheme() async {
    AppConfig.logDebug('ThemeProvider._initializeTheme - 테마 초기화 시작');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('theme');
      
      if (savedTheme != null && ThemeConfig.themeNames.containsKey(savedTheme)) {
        await setTheme(savedTheme, saveToPrefs: false);
        AppConfig.logInfo('ThemeProvider._initializeTheme - 저장된 테마 복원: $savedTheme');
      } else {
        // 시스템 언어에 따른 추천 테마 설정
        final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
        final recommendedTheme = ThemeConfig.getRecommendedTheme(systemLocale.languageCode);
        await setTheme(recommendedTheme, saveToPrefs: true);
        AppConfig.logInfo('ThemeProvider._initializeTheme - 추천 테마 설정: $recommendedTheme (언어: ${systemLocale.languageCode})');
      }
    } catch (error, stackTrace) {
      AppConfig.logError('ThemeProvider._initializeTheme - 테마 초기화 실패', error, stackTrace);
      // 기본 테마로 폴백
      await setTheme('classicBlue', saveToPrefs: false);
    }
  }
  
  /// 테마 변경
  Future<void> setTheme(String themeKey, {bool saveToPrefs = true}) async {
    AppConfig.logDebug('ThemeProvider.setTheme - 테마 변경: $themeKey');
    
    if (!ThemeConfig.themeNames.containsKey(themeKey)) {
      AppConfig.logWarning('ThemeProvider.setTheme - 유효하지 않은 테마: $themeKey');
      return;
    }
    
    if (_currentTheme == themeKey) {
      AppConfig.logDebug('ThemeProvider.setTheme - 동일한 테마로 변경 시도: $themeKey');
      return;
    }
    
    try {
      _currentTheme = themeKey;
      _themeData = ThemeConfig.getThemeData(themeKey);
      
      if (saveToPrefs) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('theme', themeKey);
        AppConfig.logInfo('ThemeProvider.setTheme - 테마 저장 완료: $themeKey');
      }
      
      notifyListeners();
      AppConfig.logInfo('ThemeProvider.setTheme - 테마 변경 완료: ${ThemeConfig.themeNames[themeKey]}');
    } catch (error, stackTrace) {
      AppConfig.logError('ThemeProvider.setTheme - 테마 변경 실패', error, stackTrace);
      rethrow;
    }
  }
  
  /// 다음 테마로 변경 (디버그용)
  Future<void> cycleTheme() async {
    AppConfig.logDebug('ThemeProvider.cycleTheme - 다음 테마로 변경');
    
    final themes = ThemeConfig.themeNames.keys.toList();
    final currentIndex = themes.indexOf(_currentTheme);
    final nextIndex = (currentIndex + 1) % themes.length;
    final nextTheme = themes[nextIndex];
    
    await setTheme(nextTheme);
  }
  
  /// 언어에 맞는 추천 테마로 변경
  Future<void> setRecommendedThemeForLanguage(String languageCode) async {
    AppConfig.logDebug('ThemeProvider.setRecommendedThemeForLanguage - 언어: $languageCode');
    
    final recommendedTheme = ThemeConfig.getRecommendedTheme(languageCode);
    if (recommendedTheme != _currentTheme) {
      await setTheme(recommendedTheme);
      AppConfig.logInfo('ThemeProvider.setRecommendedThemeForLanguage - 언어별 추천 테마 적용: $recommendedTheme');
    }
  }
  
  /// 테마 정보 가져오기
  Map<String, dynamic> getThemeInfo(String themeKey) {
    final themeName = ThemeConfig.themeNames[themeKey] ?? 'Unknown';
    final themeData = ThemeConfig.getThemeData(themeKey);
    
    return {
      'key': themeKey,
      'name': themeName,
      'primaryColor': themeData.colorScheme.primary.value,
      'backgroundColor': themeData.colorScheme.background.value,
      'brightness': themeData.colorScheme.brightness.name,
    };
  }
  
  /// 현재 테마가 다크 모드인지 확인
  bool get isDarkMode => _themeData.colorScheme.brightness == Brightness.dark;
  
  /// 테마 미리보기 색상 리스트
  List<Color> getThemePreviewColors(String themeKey) {
    final themeData = ThemeConfig.getThemeData(themeKey);
    return [
      themeData.colorScheme.primary,
      themeData.colorScheme.secondary,
      themeData.colorScheme.surface,
      themeData.colorScheme.background,
    ];
  }
}