/// 한국 소셜 로그인(카카오/네이버) 키·설정.
///
/// ⚠️ 아래 값은 각 개발자 콘솔에서 발급받은 실제 값으로 교체해야 로그인이 동작한다.
/// 미설정(placeholder) 상태에서는 카카오/네이버 로그인이 실패한다.
class SocialLoginConfig {
  /// 카카오 네이티브 앱 키 — developers.kakao.com > 내 애플리케이션 > 앱 키 > 네이티브 앱 키.
  /// iOS URL 스킴은 `kakao{네이티브앱키}` 형식으로 Info.plist에도 등록해야 한다.
  static const String kakaoNativeAppKey = '55e15f9a2d19524e49115d1035e4ef89';

  // 네이버는 네이티브 설정(Android strings.xml / iOS Info.plist)에 Client ID/Secret/앱이름을
  // 직접 넣으므로 여기서 관리하지 않는다. (developers.naver.com > 애플리케이션 등록)
}
