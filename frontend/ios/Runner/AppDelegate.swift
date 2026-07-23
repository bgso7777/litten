import Flutter
import UIKit
import NidThirdPartyLogin

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 소셜 로그인 URL 콜백 처리.
  // ⚠️ 순서 중요: 먼저 Flutter 플러그인(구글·카카오 등)에 위임하고, 아무도 처리하지 않은
  //    URL만 네이버(NidOAuth)로 넘긴다. (네이버 핸들러를 앞에 두면 카카오 콜백이
  //    가로채져 로그인이 무한 대기(뺑뺑이)하는 문제가 생길 수 있어 super를 먼저 부른다.)
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if super.application(app, open: url, options: options) {
      return true
    }
    return NidOAuth.shared.handleURL(url)
  }
}
