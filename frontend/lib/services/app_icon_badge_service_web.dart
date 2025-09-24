import 'dart:html' as html;

// Web implementation for app icon badge
class PlatformAppIconBadge {
  String _originalTitle = '';

  void initialize() {
    _originalTitle = html.document.title ?? 'Litten';
  }

  void updateBadge(int count) {
    updateTitle(_originalTitle, count);
    updateFavicon(count);
  }

  void updateTitle(String originalTitle, int badgeCount) {
    final String newTitle;
    if (badgeCount > 0) {
      final badgeText = badgeCount > 99 ? '99+' : badgeCount.toString();
      newTitle = '($badgeText) $originalTitle';
    } else {
      newTitle = originalTitle;
    }

    html.document.title = newTitle;
  }

  void updateFavicon(int badgeCount) {
    try {
      // 기존 파비콘 링크 제거
      final existingFavicons = html.document.querySelectorAll('link[rel*="icon"]');
      for (final favicon in existingFavicons) {
        favicon.remove();
      }

      // 새 파비콘 생성
      final String faviconUrl = createFaviconWithBadge(badgeCount);

      // 새 파비콘 링크 추가
      final faviconLink = html.LinkElement()
        ..rel = 'icon'
        ..type = 'image/x-icon'
        ..href = faviconUrl;

      html.document.head?.append(faviconLink);
    } catch (e) {
      // 에러 무시
    }
  }

  String createFaviconWithBadge(int badgeCount) {
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
    if (badgeCount > 0) {
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

      final badgeText = badgeCount > 9 ? '9+' : badgeCount.toString();
      ctx.fillText(badgeText, 24, 8);
    }

    return canvas.toDataUrl();
  }

  String getOriginalTitle() {
    return _originalTitle;
  }
}