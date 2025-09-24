import 'dart:async';
import 'package:flutter/foundation.dart';

// 조건부 import: 웹에서만 html 라이브러리 사용
import 'app_icon_badge_service_stub.dart'
    if (dart.library.html) 'app_icon_badge_service_web.dart' as platform;

class AppIconBadgeService {
  static final AppIconBadgeService _instance = AppIconBadgeService._internal();
  factory AppIconBadgeService() => _instance;
  AppIconBadgeService._internal();

  final _platformBadge = platform.PlatformAppIconBadge();
  int _currentBadgeCount = 0;

  void initialize() {
    _platformBadge.initialize();
    debugPrint('🔰 앱 아이콘 배지 서비스 초기화: ${_platformBadge.getOriginalTitle()}');
  }

  void updateBadge(int count) {
    _currentBadgeCount = count;
    _platformBadge.updateBadge(count);
    debugPrint('🔰 앱 아이콘 배지 업데이트: $count');
  }

  void clearBadge() {
    updateBadge(0);
  }

  int get currentBadgeCount => _currentBadgeCount;
  String get originalTitle => _platformBadge.getOriginalTitle();
}