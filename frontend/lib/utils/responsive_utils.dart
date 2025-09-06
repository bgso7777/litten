import 'package:flutter/material.dart';

class ResponsiveUtils {
  static const double tabletBreakpoint = 768.0;
  static const double desktopBreakpoint = 1024.0;
  
  static bool isTablet(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth >= tabletBreakpoint && screenWidth < desktopBreakpoint;
  }
  
  static bool isDesktop(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth >= desktopBreakpoint;
  }
  
  static bool isMobile(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth < tabletBreakpoint;
  }
  
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }
  
  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }
  
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.all(24.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(16.0);
    } else {
      return const EdgeInsets.all(12.0);
    }
  }
  
  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final screenWidth = getScreenWidth(context);
    if (screenWidth < 360) {
      return baseFontSize * 0.9;
    } else if (screenWidth < 400) {
      return baseFontSize * 0.95;
    } else if (screenWidth > 600) {
      return baseFontSize * 1.1;
    }
    return baseFontSize;
  }
  
  static double getResponsiveIconSize(BuildContext context, double baseIconSize) {
    final screenWidth = getScreenWidth(context);
    if (screenWidth < 360) {
      return baseIconSize * 0.9;
    } else if (screenWidth > 600) {
      return baseIconSize * 1.1;
    }
    return baseIconSize;
  }
  
  static int getResponsiveCrossAxisCount(BuildContext context) {
    final screenWidth = getScreenWidth(context);
    if (screenWidth > 1200) {
      return 4;
    } else if (screenWidth > 800) {
      return 3;
    } else if (screenWidth > 600) {
      return 2;
    } else {
      return 1;
    }
  }
  
  static double getCalendarRowHeight(BuildContext context) {
    final screenHeight = getScreenHeight(context);
    if (screenHeight < 600) {
      return 30.0; // 작은 화면
    } else if (screenHeight < 800) {
      return 35.0; // 중간 화면
    } else {
      return 40.0; // 큰 화면
    }
  }
  
  static double getCalendarDaysOfWeekHeight(BuildContext context) {
    final screenHeight = getScreenHeight(context);
    if (screenHeight < 600) {
      return 20.0; // 작은 화면
    } else if (screenHeight < 800) {
      return 25.0; // 중간 화면
    } else {
      return 30.0; // 큰 화면
    }
  }
  
  static double getBadgeFontSize(BuildContext context) {
    final screenWidth = getScreenWidth(context);
    if (screenWidth < 360) {
      return 7.0;
    } else if (screenWidth < 400) {
      return 7.5;
    } else {
      return 8.1;
    }
  }
  
  static double getBadgeIconSize(BuildContext context) {
    final screenWidth = getScreenWidth(context);
    if (screenWidth < 360) {
      return 8.0;
    } else if (screenWidth < 400) {
      return 8.5;
    } else {
      return 9.7;
    }
  }
  
  static EdgeInsets getBadgePadding(BuildContext context) {
    final screenWidth = getScreenWidth(context);
    if (screenWidth < 360) {
      return const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.2);
    } else if (screenWidth < 400) {
      return const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.4);
    } else {
      return const EdgeInsets.symmetric(horizontal: 4.9, vertical: 1.6);
    }
  }
  
  static double getBadgeBorderRadius(BuildContext context) {
    final screenWidth = getScreenWidth(context);
    if (screenWidth < 360) {
      return 8.0;
    } else if (screenWidth < 400) {
      return 8.5;
    } else {
      return 9.7;
    }
  }
}