import 'package:flutter/foundation.dart';

/// 앱 세션 동안 임시 데이터를 관리하는 서비스
class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  // 보기탭 마지막 방문 URL 저장
  String? _lastVisitedUrl;

  // 보기탭 현재 활성 URL 저장 (세션 동안 유지)
  String? _currentActiveUrl;

  /// 마지막 방문한 URL을 저장합니다
  void setLastVisitedUrl(String url) {
    _lastVisitedUrl = url;
    debugPrint('💾 세션 저장: 마지막 방문 URL = $url');
  }

  /// 마지막 방문한 URL을 가져옵니다
  String? getLastVisitedUrl() {
    return _lastVisitedUrl;
  }

  /// 현재 활성 URL을 저장합니다 (탭 전환 시 사용)
  void setCurrentActiveUrl(String url) {
    _currentActiveUrl = url;
    debugPrint('💾 세션 저장: 현재 활성 URL = $url');
  }

  /// 현재 활성 URL을 가져옵니다
  String? getCurrentActiveUrl() {
    return _currentActiveUrl;
  }

  /// 기본 URL을 가져옵니다 (마지막 방문 URL이 없는 경우)
  String getDefaultUrl() {
    return _lastVisitedUrl ?? 'https://www.google.com';
  }

  /// 세션 초기화 (앱 재시작 시)
  void clearSession() {
    _lastVisitedUrl = null;
    _currentActiveUrl = null;
    debugPrint('🗑️ 세션 초기화 완료');
  }
}