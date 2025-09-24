import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

class AppIconBadgeService {
  static final AppIconBadgeService _instance = AppIconBadgeService._internal();
  factory AppIconBadgeService() => _instance;
  AppIconBadgeService._internal();

  String _originalTitle = '';
  int _currentBadgeCount = 0;

  void initialize() {
    if (kIsWeb) {
      _originalTitle = html.document.title ?? 'Litten';
      debugPrint('🔰 앱 아이콘 배지 서비스 초기화: $_originalTitle');
    }
  }

  void updateBadge(int count) {
    if (!kIsWeb) return;

    _currentBadgeCount = count;
    _updateTitle();
    _updateFavicon();

    debugPrint('🔰 앱 아이콘 배지 업데이트: $count');
  }

  void _updateTitle() {
    if (!kIsWeb) return;

    final String newTitle;
    if (_currentBadgeCount > 0) {
      final badgeText = _currentBadgeCount > 99 ? '99+' : _currentBadgeCount.toString();
      newTitle = '($badgeText) $_originalTitle';
    } else {
      newTitle = _originalTitle;
    }

    html.document.title = newTitle;
  }

  void _updateFavicon() {
    if (!kIsWeb) return;

    try {
      // 기존 파비콘 링크 제거
      final existingFavicons = html.document.querySelectorAll('link[rel*="icon"]');
      for (final favicon in existingFavicons) {
        favicon.remove();
      }

      // 새 파비콘 생성
      final String faviconUrl = _createFaviconWithBadge();

      // 새 파비콘 링크 추가
      final faviconLink = html.LinkElement()
        ..rel = 'icon'
        ..type = 'image/x-icon'
        ..href = faviconUrl;

      html.document.head?.append(faviconLink);
    } catch (e) {
      debugPrint('🔰 파비콘 업데이트 오류: $e');
    }
  }

  String _createFaviconWithBadge() {
    // Canvas를 사용하여 배지가 있는 파비콘 생성
    final canvas = html.CanvasElement(width: 32, height: 32);
    final ctx = canvas.context2D;

    // 배경색 설정 (리튼 앱 테마 색상)
    ctx.fillStyle = '#4CAF50'; // Nature Green 테마 색상
    ctx.fillRect(0, 0, 32, 32);

    // 앱 아이콘 텍스트 (L)
    ctx.fillStyle = '#FFFFFF';
    ctx.font = 'bold 20px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('L', 16, 16);

    // 배지 표시
    if (_currentBadgeCount > 0) {
      // 배지 배경
      ctx.fillStyle = '#FF0000';
      ctx.beginPath();
      ctx.arc(24, 8, 8, 0, 2 * 3.14159);
      ctx.fill();

      // 배지 텍스트
      ctx.fillStyle = '#FFFFFF';
      ctx.font = 'bold 10px sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';

      final badgeText = _currentBadgeCount > 9 ? '9+' : _currentBadgeCount.toString();
      ctx.fillText(badgeText, 24, 8);
    }

    return canvas.toDataUrl();
  }

  void clearBadge() {
    updateBadge(0);
  }

  int get currentBadgeCount => _currentBadgeCount;
  String get originalTitle => _originalTitle;
}