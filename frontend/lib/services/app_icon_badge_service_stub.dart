// Stub implementation for non-web platforms
class PlatformAppIconBadge {
  void initialize() {
    // 웹이 아닌 플랫폼에서는 아무 작업을 하지 않음
  }

  void updateBadge(int count) {
    // 웹이 아닌 플랫폼에서는 아무 작업을 하지 않음
  }

  void updateTitle(String originalTitle, int badgeCount) {
    // 웹이 아닌 플랫폼에서는 아무 작업을 하지 않음
  }

  void updateFavicon(int badgeCount) {
    // 웹이 아닌 플랫폼에서는 아무 작업을 하지 않음
  }

  String createFaviconWithBadge(int badgeCount) {
    // 웹이 아닌 플랫폼에서는 빈 문자열 반환
    return '';
  }

  String getOriginalTitle() {
    return 'Litten';
  }
}