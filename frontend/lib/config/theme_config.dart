import 'package:flutter/material.dart';

/// 5가지 테마 설정을 관리하는 클래스
class ThemeConfig {
  // 테마 타입 정의
  static const Map<String, String> themeNames = {
    'classicBlue': 'Classic Blue',
    'darkMode': 'Dark Mode',
    'natureGreen': 'Nature Green',
    'sunsetOrange': 'Sunset Orange',
    'monochromeGrey': 'Monochrome Grey',
  };
  
  // 언어/국가별 기본 테마 매핑
  static const Map<String, String> localeThemeMapping = {
    // 아시아권
    'ko': 'classicBlue', // 한국어
    'ja': 'classicBlue', // 일본어
    'zh': 'classicBlue', // 중국어
    'hi': 'classicBlue', // 힌디어
    'bn': 'classicBlue', // 벵골어
    'mr': 'classicBlue', // 마라티어
    'te': 'classicBlue', // 텔루구어
    'ta': 'classicBlue', // 타밀어
    'th': 'classicBlue', // 태국어
    'id': 'classicBlue', // 인도네시아어
    'ms': 'classicBlue', // 말레이어
    'tl': 'classicBlue', // 타갈로그어
    
    // 유럽권
    'de': 'darkMode', // 독일어
    'fr': 'darkMode', // 프랑스어
    'it': 'darkMode', // 이탈리아어
    'ru': 'darkMode', // 러시아어
    'uk': 'darkMode', // 우크라이나어
    'pl': 'darkMode', // 폴란드어
    'ro': 'darkMode', // 로마니아어
    'nl': 'darkMode', // 네덜란드어
    'tr': 'darkMode', // 터키어
    
    // 아메리카권
    'en': 'natureGreen', // 영어
    'es': 'natureGreen', // 스페인어
    'pt': 'natureGreen', // 포르투갈어
    
    // 중동/아프리카권
    'ar': 'sunsetOrange', // 아랍어
    'fa': 'sunsetOrange', // 페르시아어
    'ur': 'sunsetOrange', // 우르두어
    'ps': 'sunsetOrange', // 파슈토어
    'sw': 'sunsetOrange', // 스와힐리어
    'ha': 'sunsetOrange', // 하우사어
  };
  
  /// 1. Classic Blue 테마
  static ThemeData get classicBlueTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: Colors.blue,
        onPrimary: Colors.white,
        secondary: Colors.blueAccent,
        onSecondary: Colors.white,
        surface: Color(0xFFF5F5F5),
        onSurface: Color(0xFF1A1A1A),
        background: Colors.white,
        onBackground: Colors.black87,
        error: Colors.red,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
  
  /// 2. Dark Mode 테마
  static ThemeData get darkModeTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: Colors.blue.shade300,
        onPrimary: Colors.black,
        secondary: Colors.blueAccent.shade200,
        onSecondary: Colors.black,
        surface: Colors.grey.shade800,
        onSurface: Colors.white,
        background: Colors.grey.shade900,
        onBackground: Colors.white,
        error: Colors.red.shade300,
        onError: Colors.black,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade300,
          foregroundColor: Colors.black,
        ),
      ),
    );
  }
  
  /// 3. Nature Green 테마
  static ThemeData get natureGreenTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: Colors.green.shade600,
        onPrimary: Colors.white,
        secondary: Colors.lightGreen,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: Colors.green.shade900,
        background: Colors.green.shade50,
        onBackground: Colors.green.shade900,
        error: Colors.red,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
  
  /// 4. Sunset Orange 테마
  static ThemeData get sunsetOrangeTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: Colors.orange.shade600,
        onPrimary: Colors.white,
        secondary: Colors.deepOrange,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: Colors.orange.shade900,
        background: Colors.orange.shade50,
        onBackground: Colors.orange.shade900,
        error: Colors.red,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade600,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
  
  /// 5. Monochrome Grey 테마
  static ThemeData get monochromeGreyTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: Colors.grey.shade700,
        onPrimary: Colors.white,
        secondary: Colors.grey.shade500,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: Colors.black87,
        background: Colors.grey.shade100,
        onBackground: Colors.black87,
        error: Colors.red,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade700,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
  
  /// 테마 키에 따른 ThemeData 반환
  static ThemeData getThemeData(String themeKey) {
    switch (themeKey) {
      case 'classicBlue':
        return classicBlueTheme;
      case 'darkMode':
        return darkModeTheme;
      case 'natureGreen':
        return natureGreenTheme;
      case 'sunsetOrange':
        return sunsetOrangeTheme;
      case 'monochromeGrey':
        return monochromeGreyTheme;
      default:
        return classicBlueTheme;
    }
  }
  
  /// 언어 코드에 따른 추천 테마 반환
  static String getRecommendedTheme(String languageCode) {
    return localeThemeMapping[languageCode] ?? 'monochromeGrey';
  }
  
  // 기능별 색상 (모든 테마 공통)
  static const Color recordingColor = Colors.red;
  static const Color writingColor = Colors.green;
  static const Color successColor = Colors.green;
  static const Color warningColor = Colors.orange;
  static const Color errorColor = Colors.red;
  static const Color infoColor = Colors.blue;
}