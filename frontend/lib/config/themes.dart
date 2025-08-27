import 'package:flutter/material.dart';

enum AppThemeType {
  classicBlue,
  darkMode,
  natureGreen,
  sunsetOrange,
  monochromeGrey,
}

class AppColors {
  // 기능별 색상 (테마 무관)
  static const Color recordingColor = Color(0xFFF44336);  // 듣기 - 빨간색
  static const Color writingColor = Color(0xFF4CAF50);    // 쓰기 - 초록색
  static const Color handwritingColor = Color(0xFF9C27B0); // 필기 - 보라색
  
  // 상태 색상
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);
  
  // 회색 계열
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey800 = Color(0xFF424242);
}

class AppTextStyles {
  // 제목
  static const TextStyle headline1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );
  
  static const TextStyle headline2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
  );
  
  static const TextStyle headline3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  
  // 본문
  static const TextStyle bodyText1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.15,
  );
  
  static const TextStyle bodyText2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.25,
  );
  
  // 캡션
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    letterSpacing: 0.4,
  );
  
  static const TextStyle caption2 = TextStyle(
    fontSize: 10,
    letterSpacing: 0.5,
  );
  
  // 버튼
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.75,
  );
  
  // 라벨
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );
}

class AppSpacing {
  // 기본 간격
  static const double xs = 4.0;
  static const double s = 8.0;
  static const double m = 12.0;
  static const double l = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  
  // 패딩
  static const EdgeInsets paddingXS = EdgeInsets.all(xs);
  static const EdgeInsets paddingS = EdgeInsets.all(s);
  static const EdgeInsets paddingM = EdgeInsets.all(m);
  static const EdgeInsets paddingL = EdgeInsets.all(l);
  static const EdgeInsets paddingXL = EdgeInsets.all(xl);
  
  // 수직 간격
  static const SizedBox verticalSpaceXS = SizedBox(height: xs);
  static const SizedBox verticalSpaceS = SizedBox(height: s);
  static const SizedBox verticalSpaceM = SizedBox(height: m);
  static const SizedBox verticalSpaceL = SizedBox(height: l);
  static const SizedBox verticalSpaceXL = SizedBox(height: xl);
  
  // 수평 간격
  static const SizedBox horizontalSpaceXS = SizedBox(width: xs);
  static const SizedBox horizontalSpaceS = SizedBox(width: s);
  static const SizedBox horizontalSpaceM = SizedBox(width: m);
  static const SizedBox horizontalSpaceL = SizedBox(width: l);
  static const SizedBox horizontalSpaceXL = SizedBox(width: xl);
}

// 테마 1: 클래식 블루 (기본) - 아시아권 선호
class ClassicBlueTheme {
  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF4A90E2),
      secondary: Color(0xFF6BB6FF),
      surface: Colors.white,
      error: AppColors.errorColor,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 1,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12))
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
  );
}

// 테마 2: 다크 모드 - 유럽권 선호
class DarkModeTheme {
  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primarySwatch: Colors.blue,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF64B5F6),
      secondary: Color(0xFF90CAF9),
      surface: Color(0xFF1E1E1E),
      error: AppColors.errorColor,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 1,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF1E1E1E),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12))
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF64B5F6),
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
  );
}

// 테마 3: 네이처 그린 - 아메리카권 선호
class NatureGreenTheme {
  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primarySwatch: Colors.green,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF4CAF50),
      secondary: Color(0xFF81C784),
      surface: Colors.white,
      error: AppColors.errorColor,
    ),
    scaffoldBackgroundColor: const Color(0xFFF1F8E9),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF2E7D32),
      elevation: 1,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12))
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
  );
}

// 테마 4: 선셋 오렌지 - 중동/아프리카권 선호
class SunsetOrangeTheme {
  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primarySwatch: Colors.orange,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFFF9800),
      secondary: Color(0xFFFFB74D),
      surface: Colors.white,
      error: AppColors.errorColor,
    ),
    scaffoldBackgroundColor: const Color(0xFFFFF3E0),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFFE65100),
      elevation: 1,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12))
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF9800),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
  );
}

// 테마 5: 모노크롬 그레이 - 기타 지역
class MonochromeGreyTheme {
  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primarySwatch: Colors.grey,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF757575),
      secondary: Color(0xFF9E9E9E),
      surface: Colors.white,
      error: AppColors.errorColor,
    ),
    scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF424242),
      elevation: 1,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12))
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF757575),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
  );
}

class ThemeManager {
  static ThemeData getThemeByType(AppThemeType type) {
    switch (type) {
      case AppThemeType.classicBlue:
        return ClassicBlueTheme.theme;
      case AppThemeType.darkMode:
        return DarkModeTheme.theme;
      case AppThemeType.natureGreen:
        return NatureGreenTheme.theme;
      case AppThemeType.sunsetOrange:
        return SunsetOrangeTheme.theme;
      case AppThemeType.monochromeGrey:
        return MonochromeGreyTheme.theme;
    }
  }
  
  static AppThemeType getThemeByLocale(String languageCode) {
    // 언어/국가 코드에 따른 테마 매핑
    final regionThemeMap = {
      // 아시아권 - Classic Blue
      'ko': AppThemeType.classicBlue, // 한국어
      'ja': AppThemeType.classicBlue, // 일본어
      'zh': AppThemeType.classicBlue, // 중국어
      'hi': AppThemeType.classicBlue, // 힌디어
      'bn': AppThemeType.classicBlue, // 벵골어
      'te': AppThemeType.classicBlue, // 텔루구어
      'mr': AppThemeType.classicBlue, // 마라티어
      'ta': AppThemeType.classicBlue, // 타밀어
      'th': AppThemeType.classicBlue, // 태국어
      
      // 유럽권 - Dark Mode
      'de': AppThemeType.darkMode,    // 독일어
      'fr': AppThemeType.darkMode,    // 프랑스어
      'it': AppThemeType.darkMode,    // 이탈리아어
      'ru': AppThemeType.darkMode,    // 러시아어
      'uk': AppThemeType.darkMode,    // 우크라이나어
      'pl': AppThemeType.darkMode,    // 폴란드어
      'ro': AppThemeType.darkMode,    // 로마니아어
      'nl': AppThemeType.darkMode,    // 네덜란드어
      
      // 아메리카권 - Nature Green
      'en': AppThemeType.natureGreen, // 영어
      'es': AppThemeType.natureGreen, // 스페인어
      'pt': AppThemeType.natureGreen, // 포르투갈어
      'tl': AppThemeType.natureGreen, // 타갈로그어
      
      // 중동/아프리카권 - Sunset Orange
      'ar': AppThemeType.sunsetOrange, // 아랍어
      'fa': AppThemeType.sunsetOrange, // 페르시아어
      'ur': AppThemeType.sunsetOrange, // 우르두어
      'ps': AppThemeType.sunsetOrange, // 파슈토어
      'sw': AppThemeType.sunsetOrange, // 스와힐리어
      'ha': AppThemeType.sunsetOrange, // 하우사어
      
      // 기타 지역 - Monochrome Grey (기본값)
      'id': AppThemeType.monochromeGrey, // 인도네시아어
      'ms': AppThemeType.monochromeGrey, // 말레이어
      'tr': AppThemeType.monochromeGrey, // 터키어
    };
    
    return regionThemeMap[languageCode] ?? AppThemeType.monochromeGrey;
  }
}

// RTL 언어 지원
class RTLHelper {
  static const List<String> rtlLanguages = ['ar', 'fa', 'ur', 'ps'];
  
  static bool isRTL(String languageCode) {
    return rtlLanguages.contains(languageCode);
  }
  
  static TextDirection getTextDirection(String languageCode) {
    return isRTL(languageCode) ? TextDirection.rtl : TextDirection.ltr;
  }
}