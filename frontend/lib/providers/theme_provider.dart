import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/preferences_service.dart';

class ThemeProvider extends ChangeNotifier {
  String _currentThemeName = AppConfig.defaultTheme;
  ThemeMode _themeMode = ThemeMode.light;
  
  String get currentThemeName => _currentThemeName;
  ThemeMode get themeMode => _themeMode;
  
  ThemeProvider() {
    _loadTheme();
  }
  
  // 저장된 테마 설정 로드
  Future<void> _loadTheme() async {
    final savedTheme = PreferencesService.getThemeName();
    final savedThemeMode = PreferencesService.getThemeMode();
    
    if (savedTheme != null) {
      _currentThemeName = savedTheme;
    } else {
      // 저장된 테마가 없으면 현재 언어에 맞는 기본 테마 적용
      await _setLanguageBasedTheme();
    }
    
    _themeMode = savedThemeMode;
    notifyListeners();
  }
  
  // 현재 언어에 따른 기본 테마 설정
  Future<void> _setLanguageBasedTheme() async {
    final currentLanguage = PreferencesService.getLanguageCode();
    
    if (currentLanguage != null) {
      final languageTheme = AppConfig.languageThemeMapping[currentLanguage] 
          ?? AppConfig.defaultTheme;
      
      _currentThemeName = languageTheme;
      await PreferencesService.setThemeName(languageTheme);
    }
  }
  
  // 테마 변경
  Future<void> setTheme(String themeName) async {
    if (_currentThemeName == themeName) return;
    
    _currentThemeName = themeName;
    await PreferencesService.setThemeName(themeName);
    notifyListeners();
  }
  
  // 테마 모드 변경 (라이트/다크)
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    await PreferencesService.setThemeMode(mode);
    notifyListeners();
  }
  
  // 라이트 테마 생성
  ThemeData get lightTheme {
    final colorScheme = _getColorScheme(_currentThemeName, false);
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      cardTheme: CardTheme(
        color: colorScheme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  // 다크 테마 생성
  ThemeData get darkTheme {
    final colorScheme = _getColorScheme(_currentThemeName, true);
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      cardTheme: CardTheme(
        color: colorScheme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
  
  // 테마별 컬러 스키마 생성
  ColorScheme _getColorScheme(String themeName, bool isDark) {
    switch (themeName) {
      case 'classic_blue':
        return isDark
            ? ColorScheme.dark(
                primary: const Color(0xFF1976D2),
                secondary: const Color(0xFF42A5F5),
                surface: const Color(0xFF121212),
                background: const Color(0xFF000000),
              )
            : ColorScheme.light(
                primary: const Color(0xFF1976D2),
                secondary: const Color(0xFF42A5F5),
                surface: const Color(0xFFF5F5F5),
                background: const Color(0xFFFFFFFF),
              );
      
      case 'dark_mode':
        return ColorScheme.dark(
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF8B5CF6),
          surface: const Color(0xFF1F2937),
          background: const Color(0xFF111827),
        );
      
      case 'nature_green':
        return isDark
            ? ColorScheme.dark(
                primary: const Color(0xFF4CAF50),
                secondary: const Color(0xFF8BC34A),
                surface: const Color(0xFF121212),
                background: const Color(0xFF000000),
              )
            : ColorScheme.light(
                primary: const Color(0xFF4CAF50),
                secondary: const Color(0xFF8BC34A),
                surface: const Color(0xFFF1F8E9),
                background: const Color(0xFFFFFFFF),
              );
      
      case 'sunset_orange':
        return isDark
            ? ColorScheme.dark(
                primary: const Color(0xFFFF9800),
                secondary: const Color(0xFFFFB74D),
                surface: const Color(0xFF121212),
                background: const Color(0xFF000000),
              )
            : ColorScheme.light(
                primary: const Color(0xFFFF9800),
                secondary: const Color(0xFFFFB74D),
                surface: const Color(0xFFFFF3E0),
                background: const Color(0xFFFFFFFF),
              );
      
      case 'monochrome_grey':
        return isDark
            ? ColorScheme.dark(
                primary: const Color(0xFF607D8B),
                secondary: const Color(0xFF90A4AE),
                surface: const Color(0xFF121212),
                background: const Color(0xFF000000),
              )
            : ColorScheme.light(
                primary: const Color(0xFF607D8B),
                secondary: const Color(0xFF90A4AE),
                surface: const Color(0xFFFAFAFA),
                background: const Color(0xFFFFFFFF),
              );
      
      default:
        return isDark ? ColorScheme.dark() : ColorScheme.light();
    }
  }
  
  // 테마 표시명 가져오기
  String getThemeDisplayName(String themeName) {
    const themeNames = {
      'classic_blue': 'Classic Blue',
      'dark_mode': 'Dark Mode',
      'nature_green': 'Nature Green',
      'sunset_orange': 'Sunset Orange',
      'monochrome_grey': 'Monochrome Grey',
    };
    
    return themeNames[themeName] ?? themeName;
  }
  
  // 언어 변경 시 테마 자동 업데이트 (LocaleProvider에서 호출)
  Future<void> updateThemeForLanguage(String languageCode) async {
    final userHasCustomTheme = PreferencesService.getThemeName() != null;
    
    // 사용자가 수동으로 테마를 설정한 적이 있다면 변경하지 않음
    if (userHasCustomTheme) return;
    
    final languageTheme = AppConfig.languageThemeMapping[languageCode] 
        ?? AppConfig.defaultTheme;
    
    if (_currentThemeName != languageTheme) {
      _currentThemeName = languageTheme;
      await PreferencesService.setThemeName(languageTheme);
      notifyListeners();
    }
  }
  
  // 사용 가능한 테마 목록
  List<String> get availableThemes => [
    'classic_blue',
    'dark_mode',
    'nature_green',
    'sunset_orange',
    'monochrome_grey',
  ];
  
  // 현재 언어에 대한 추천 테마 가져오기
  String getRecommendedThemeForLanguage(String languageCode) {
    return AppConfig.languageThemeMapping[languageCode] ?? AppConfig.defaultTheme;
  }
}