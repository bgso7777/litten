import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:provider/provider.dart';
import '../models/summary_result.dart';
import '../models/youtube_channel.dart';
import '../models/text_file.dart';
import '../services/api_service.dart';
import '../services/app_state_provider.dart';
import '../config/plan_limits.dart';
import '../services/usage_quota.dart';
import '../services/file_storage_service.dart';

// 앱 지원 30개 언어 목록
const _kLanguages = [
  ('ko', '한국어'),
  ('en', 'English'),
  ('zh', '中文'),
  ('ja', '日本語'),
  ('hi', 'हिन्दी'),
  ('es', 'Español'),
  ('fr', 'Français'),
  ('ar', 'العربية'),
  ('bn', 'বাংলা'),
  ('ru', 'Русский'),
  ('pt', 'Português'),
  ('ur', 'اردو'),
  ('id', 'Bahasa Indonesia'),
  ('de', 'Deutsch'),
  ('sw', 'Kiswahili'),
  ('mr', 'मराठी'),
  ('te', 'తెలుగు'),
  ('tr', 'Türkçe'),
  ('ta', 'தமிழ்'),
  ('fa', 'فارسی'),
  ('uk', 'Українська'),
  ('it', 'Italiano'),
  ('tl', 'Filipino'),
  ('pl', 'Polski'),
  ('ps', 'پښتو'),
  ('ms', 'Bahasa Melayu'),
  ('ro', 'Română'),
  ('nl', 'Nederlands'),
  ('ha', 'Hausa'),
  ('th', 'ไทย'),
];

/// YouTube IFrame 임베드 + 요약 버튼을 포함한 영상 플레이어 시트
Future<void> showYoutubeVideoPlayerSheet({
  required BuildContext context,
  required YoutubeVideo video,
  required YoutubeChannel channel,
  required String? token,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => YoutubeVideoPlayerSheet(
      video: video,
      channel: channel,
      token: token,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ⚠️ iOS 자막(스크립트) 미지원 — 알려진 한계 (2026-05-31 조사 완료)
//
// 이 시트는 데스크톱 YouTube watch 페이지를 WebView로 띄우고, '더보기 → 스크립트
// 표시'를 JS로 자동 클릭해 자막 패널을 연 뒤 그 DOM을 긁는다.
//
// ▸ Android(WebView): 정상 동작. 패널이 자막으로 채워지고 스크래핑 성공.
// ▸ iOS(WKWebView): 자막 패널이 열리지만 내용이 안 채워지고 로딩 스피너만 무한
//   회전한다(="뺑뺑이"). 이는 우리 코드 버그가 아니라 YouTube의 자막 봇 차단이다.
//
// 조사로 확인한 사실(진단 로그 기반):
//   - 패널은 열림(vis=EXPANDED)이나 세그먼트 0개 + 스피너 active.
//   - WebView JS에서 captionTracks[].baseUrl 을 직접 fetch → HTTP 200이지만 본문이
//     0바이트(빈 응답). get_transcript(InnerTube) 직접 호출은 400.
//   - 즉 PoToken(봇 토큰)/디바이스 검증 없이는 YouTube가 WKWebView 환경에 자막
//     데이터를 내려주지 않는다. 쿠키(CONSENT/SOCS) 사전 주입·fmt 변경으로 우회 불가.
//
// 결론: WebView 스크래핑/클라이언트 직접 fetch 방식은 iOS에서 구조적으로 막힘.
//   해결하려면 서버 추출(백엔드 yt-dlp: extractYoutubeTranscriptViaYtDlp)로 폴백해야
//   한다. 사용자 결정으로 현재는 iOS를 그대로 둠(자막 미표시). 같은 증상으로 다시
//   조사하지 말 것 — 위 경로들은 이미 모두 실패가 확인됐다.
// ─────────────────────────────────────────────────────────────────────────────
class YoutubeVideoPlayerSheet extends StatefulWidget {
  final YoutubeVideo video;
  final YoutubeChannel channel;
  final String? token;

  const YoutubeVideoPlayerSheet({
    super.key,
    required this.video,
    required this.channel,
    required this.token,
  });

  @override
  State<YoutubeVideoPlayerSheet> createState() => _YoutubeVideoPlayerSheetState();
}

class _YoutubeVideoPlayerSheetState extends State<YoutubeVideoPlayerSheet> {
  late final WebViewController _webViewController;
  // YouTube watch는 SPA라 onPageFinished가 여러 번 발생한다. 매번 재주입하면
  // '스크립트 표시'가 토글로 재클릭되어 자막 패널이 로딩 중 닫혔다 열렸다 하며
  // 내용이 안 채워지고 무한 로딩(뺑뺑이)된다. 최초 1회만 주입해 패널을 안정 유지한다.
  bool _transcriptScriptInjected = false;

  @override
  void initState() {
    super.initState();
    // 데스크톱 유튜브 페이지를 그대로 로드 (스크래핑 X).
    // '스크립트 표시(Show transcript)'는 데스크톱 웹에만 있으므로 데스크톱 UA 사용.
    // 사용자가 네이티브 '더보기 → 스크립트 표시'로 자막을 보고 직접 복사한다.
    // iOS: 인라인 재생 허용 (없으면 영상이 자동 전체화면으로 재생됨)
    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(allowsInlineMediaPlayback: true)
        : const PlatformWebViewControllerCreationParams();
    _webViewController = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36')
      ..addJavaScriptChannel('LittenDiag',
          onMessageReceived: (m) => debugPrint('[TranscriptAuto] ${m.message}'))
      ..setNavigationDelegate(NavigationDelegate(
        // 페이지 로드 후 '더보기' 펼치고 '스크립트 표시'를 자동 클릭.
        // onPageFinished가 여러 번 발생해도 최초 1회만 주입(중복 클릭→토글로 패널 로딩 방해 방지).
        onPageFinished: (_) {
          if (_transcriptScriptInjected) {
            debugPrint('[TranscriptAuto] onPageFinished 재발생 - 주입 생략');
            return;
          }
          _transcriptScriptInjected = true;
          debugPrint('[TranscriptAuto] onPageFinished 최초 1회 - 스크립트 주입');
          _webViewController.runJavaScript(_autoOpenTranscriptScript);
        },
      ))
      // 주의: hl=ko 등 언어 강제 시 한국어 자막 트랙 로딩이 차단되어 패널이 빈 채로
      // 무한 로딩(segs=0)되는 회귀가 있었다(2026-05-31 검증). 언어 미지정(영문 로드)이
      // 기본 자막을 정상 로드하므로 그대로 둔다.
      ..loadRequest(Uri.parse('https://www.youtube.com/watch?v=${widget.video.videoId}'));
  }

  /// 데스크톱 유튜브 페이지에서 '더보기 → 스크립트 표시'를 자동으로 클릭하는 스크립트.
  /// 콘텐츠가 비동기로 로드되므로 재시도 폴링한다.
  static const String _autoOpenTranscriptScript = r'''
(function(){
  if (window.__littenTranscriptAuto) return;
  window.__littenTranscriptAuto = true;
  var tries = 0;
  var opened = false;
  var re = /스크립트 표시|show transcript/i;
  // 자동재생 차단(이벤트 기반 — 0.3초 루프 제거로 유튜브 자막 로딩 간섭 방지)
  // 기본 음소거: 자동재생을 막아도 일시정지 직전 한순간 소리가 새는 것을 막기 위해
  // 사용자가 직접 재생을 누르기 전까지는 모든 video를 muted=true 로 둔다.
  var killAutoplay = true;
  function onVidPlay(e){ if (killAutoplay){ try { e.target.pause(); } catch(_){} } }
  // video에 playsinline + (자동재생 시 일시정지) play 리스너 1회 부착 + 기본 음소거
  function quiet(){
    var vs = document.querySelectorAll('video');
    for (var i=0;i<vs.length;i++){
      var v = vs[i];
      try {
        v.setAttribute('playsinline','');
        v.setAttribute('webkit-playsinline','');
        v.playsInline = true;
      } catch(e){}
      // 사용자 재생 전까지는 무음 유지 (자동재생 정책상으로도 muted가 안전)
      if (killAutoplay) { try { v.muted = true; } catch(e){} }
      if (!v.__littenTagged) {
        v.__littenTagged = true;
        v.addEventListener('play', onVidPlay);
        if (killAutoplay) { try { v.pause(); } catch(e){} }
      }
    }
  }
  // 사용자가 플레이어 영역을 직접 누르면 자동정지 해제 + 음소거 해제 (그때부터 소리 재생)
  document.addEventListener('click', function(e){
    if (e.target && e.target.closest && e.target.closest('#player, #movie_player, .html5-video-player, ytd-player')) {
      if (killAutoplay) {
        killAutoplay = false;
        var vs = document.querySelectorAll('video');
        for (var i=0;i<vs.length;i++){ try { vs[i].muted = false; } catch(_){} }
        diag('사용자 재생 허용 (음소거 해제)');
      }
    }
  }, true);
  // 초기 전체화면 방지 + 자동재생 차단: 즉시 + video 생성 즉시(Observer) + 빠른 초기 루프
  quiet();
  try {
    var mo = new MutationObserver(function(){ quiet(); });
    mo.observe(document.documentElement, {childList: true, subtree: true});
    setTimeout(function(){ try { mo.disconnect(); } catch(e){} }, 8000);
  } catch(e){}
  var fast = 0;
  (function fastLoop(){ quiet(); if (++fast < 45) setTimeout(fastLoop, 150); })();
  function diag(m){ try { LittenDiag.postMessage(m); } catch(e){} }
  // 유튜브 상단바 숨김 (공간 확보). sticky는 레이아웃을 꼬이게 해서 사용하지 않음.
  function hideMasthead(){
    if (document.getElementById('litten-pin-style')) return;
    var s = document.createElement('style');
    s.id = 'litten-pin-style';
    s.textContent = '#masthead-container, ytd-masthead { display:none !important; }';
    (document.head || document.documentElement).appendChild(s);
  }
  // 영상이 상단에 보이도록 모든 스크롤 컨테이너를 0으로
  function scrollPlayerToTop(){
    var p = document.querySelector('#player, #movie_player, ytd-player');
    if (!p) { diag('player 못찾음'); return; }
    var el = p.parentElement;
    while (el) {
      try { if (el.scrollHeight > el.clientHeight + 4) el.scrollTop = 0; } catch(e){}
      el = el.parentElement;
    }
    try { window.scrollTo(0,0); } catch(e){}
    try { if (document.scrollingElement) document.scrollingElement.scrollTop = 0; } catch(e){}
    p.scrollIntoView({block:'start'});
    var pr = p.getBoundingClientRect();
    diag('scrollPlayerToTop → player top='+Math.round(pr.top)+' h='+Math.round(pr.height));
  }
  // 진단: 클릭 후 자막 패널이 실제로 채워지는지(세그먼트 수·스피너) 폴링 로깅
  function diagPanel(t){
    var p = document.querySelector('ytd-transcript-renderer, ytd-transcript-search-panel-renderer, [target-id="engagement-panel-searchable-transcript"]');
    var segs = document.querySelectorAll('ytd-transcript-segment-renderer, .segment-text');
    var spinner = document.querySelector('tp-yt-paper-spinner[active], .ytd-transcript-renderer tp-yt-paper-spinner[active], yt-spinner');
    var vis = (p && p.getAttribute) ? (p.getAttribute('visibility')||'') : '';
    diag('PANEL t='+t+' panel='+(p?'found':'none')+' vis='+vis+' segs='+segs.length+' spinner='+(spinner?'active':'no'));
  }
  function visible(el){
    if (!el || !el.offsetParent) return false;
    var r = el.getBoundingClientRect();
    return r.width > 4 && r.height > 4;
  }
  // 1) 설명 '더보기' 펼치기 — 보이는 expander만, 이미 펼쳐졌으면 건드리지 않음(토글 방지)
  function ensureExpanded(){
    var exps = document.querySelectorAll('ytd-text-inline-expander');
    for (var i=0;i<exps.length;i++){
      var exp = exps[i];
      if (!visible(exp)) continue;
      if (exp.hasAttribute('is-expanded')) return true;
      var b = exp.querySelector('#expand, tp-yt-paper-button#expand');
      if (b && visible(b)) { b.click(); diag('expand 클릭(visible)'); return exp.hasAttribute('is-expanded'); }
    }
    return false;
  }
  // 이미 열린 transcript 패널이 있으면 '스크립트 표시'는 토글이라 재클릭 시 닫힌다 → 클릭 생략
  function transcriptPanelOpen(){
    var p = document.querySelector('ytd-transcript-renderer, ytd-transcript-search-panel-renderer, [target-id="engagement-panel-searchable-transcript"]');
    if (!p) return false;
    var vis = (p.getAttribute && p.getAttribute('visibility')) || '';
    if (vis) return vis.indexOf('EXPANDED') !== -1;
    return visible(p);
  }
  // 2) '스크립트 표시' 버튼 클릭 — 매칭 후보를 진단 로그로 출력하고 클릭 가능한 버튼만 클릭
  function clickTranscript(){
    if (transcriptPanelOpen()){ diag('패널 이미 열림 - 재클릭 생략'); return true; }
    var cand = document.querySelectorAll('button, tp-yt-paper-button, ytd-button-renderer, yt-button-shape, a, yt-formatted-string, span');
    var match = 0;
    for (var i=0;i<cand.length;i++){
      var el = cand[i];
      var lbl = (el.getAttribute && el.getAttribute('aria-label')) || '';
      var txt = (el.textContent || '').trim();
      if (!(re.test(lbl) || re.test(txt))) continue;
      match++;
      var clickable = (el.closest && el.closest('button, tp-yt-paper-button, ytd-button-renderer, yt-button-shape, a')) || el;
      var vis = visible(clickable);
      var top = Math.round(clickable.getBoundingClientRect().top);
      diag('cand#'+match+' '+clickable.tagName+' vis='+vis+' top='+top+' txt="'+txt.slice(0,16)+'" lbl="'+lbl.slice(0,16)+'"');
      if (!vis) continue;
      clickable.scrollIntoView({block:'center'});
      var btn = clickable.querySelector('button') || clickable;
      btn.click();
      diag('클릭 실행 → '+clickable.tagName);
      return true;
    }
    if (match === 0) diag('매칭 0');
    return false;
  }
  function step(){
    tries++;
    quiet();
    hideMasthead();
    if (!opened) {
      var ex = ensureExpanded();
      if (tries % 5 === 1) diag('step '+tries+' expanded='+ex);
      if (clickTranscript()) {
        opened = true; diag('완료');
        // 스크립트 열리면 유튜브가 스크립트 위치로 스크롤 → 여러 번 영상 상단 정렬
        [400, 900, 1500, 2500].forEach(function(t){ setTimeout(scrollPlayerToTop, t); });
        [1500, 3000, 6000, 10000].forEach(function(t){ setTimeout(function(){ diagPanel(t); }, t); });
      }
    }
    if (!opened && tries < 60) setTimeout(step, 600);
    else if (!opened) diag('포기 (tries='+tries+')');
  }
  setTimeout(step, 1500);
})();
''';

  @override
  void dispose() {
    // 닫기 버튼뿐 아니라 드래그·바깥 탭으로 닫을 때도 재생 중인 영상을 정지한다.
    try {
      _webViewController.runJavaScript(
        "document.querySelectorAll('video').forEach(function(v){try{v.pause();}catch(e){}});");
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    // 높이 보장을 위해 DraggableScrollableSheet 사용 (05-25 검증된 구조)
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context2, sc) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              // 드래그 핸들
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 유튜브 watch 페이지 (영상 + 더보기 → 스크립트 표시)
              Expanded(
                child: WebViewWidget(
                  controller: _webViewController,
                  gestureRecognizers: {
                    Factory<VerticalDragGestureRecognizer>(
                      () => VerticalDragGestureRecognizer(),
                    ),
                  },
                ),
              ),
              // 하단 버튼 바 (WebView 아래 별도 바 — 탭 충돌 방지)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      // 닫기 — 영상 정지 + 시트 닫기
                      OutlinedButton(
                        onPressed: _closePlayer,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        child: const Text('닫기'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _onCopyScript(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: color,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.content_copy, size: 18),
                          label: const Text('스크립트 복사 → 요약하기'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 닫기 — 재생 중인 유튜브 영상을 정지하고 시트를 닫는다
  Future<void> _closePlayer() async {
    try {
      await _webViewController.runJavaScript(
        "document.querySelectorAll('video').forEach(function(v){try{v.pause();}catch(e){}});");
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  /// 화면에 떠 있는 유튜브 스크립트 패널의 자막을 추출하는 JS (타임스탬프 + 텍스트)
  static const String _extractTranscriptJs = r'''
(function(){
  // 타임스탬프(0:03) 텍스트 leaf 요소를 찾되, 영상 플레이어 컨트롤은 제외 → 그 행(세그먼트) 텍스트 수집
  var tsRe = /^\d{1,2}(:\d{2}){1,2}$/;
  var leaves = document.querySelectorAll('*');
  var rows = []; var seen = {};
  for (var i=0;i<leaves.length;i++){
    var el = leaves[i];
    if (el.children.length > 0) continue;
    var t = (el.textContent || '').trim();
    if (!tsRe.test(t)) continue;
    if (el.closest('#movie_player, .html5-video-player, .ytp-chrome-bottom, .ytp-chrome-controls, .ytp-time-display, .ytp-progress-bar-container')) continue;
    // 타임스탬프 leaf에서 위로 올라가며 캡션 텍스트까지 포함하는 행을 찾음
    var seg = el; var segText = '';
    for (var d=0; d<4 && seg; d++){
      seg = seg.parentElement; if (!seg) break;
      var txt = (seg.innerText || '').replace(/\s+/g,' ').trim();
      if (txt.length > t.length + 3) { segText = txt; break; }
    }
    if (segText && !seen[segText]) { seen[segText] = 1; rows.push(segText); }
  }
  if (rows.length >= 2) return rows.join('\n');
  return 'DIAGEMPTY rows=' + rows.length;
})();
''';

  String _decodeJsResult(Object? raw) {
    if (raw == null) return '';
    var s = raw.toString();
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      try { return jsonDecode(s) as String; } catch (_) {}
    }
    return s.replaceAll('\\n', '\n');
  }

  /// 추출 텍스트 정리 — 헤더/타임스탬프 제거하고 본문만
  String _cleanTranscript(String raw) {
    final out = <String>[];
    for (var line in raw.split('\n')) {
      var l = line.trim();
      if (l.isEmpty) continue;
      // 패널 헤더 제거
      if (l == '스크립트' || l.startsWith('스크립트 검색') || l == '검색') continue;
      // 순수 타임스탬프 라인 제거 (0:03 / 3초 / 1분 2초 / 1분 / 1시간 ...)
      if (RegExp(r'^\d{1,2}(:\d{2}){1,2}$').hasMatch(l)) continue;
      if (RegExp(r'^\d+\s*시간(\s*\d+\s*분)?(\s*\d+\s*초)?$').hasMatch(l)) continue;
      if (RegExp(r'^\d+\s*분(\s*\d+\s*초)?$').hasMatch(l)) continue;
      if (RegExp(r'^\d+\s*초$').hasMatch(l)) continue;
      // 영어형 순수 타임스탬프 라인 제거 (45 seconds / 5 minutes, 3 seconds / 1 hour, 12 minutes, 30 seconds ...)
      if (RegExp(r'^\d+\s*hours?(\s*,?\s*(and\s+)?\d+\s*minutes?)?(\s*,?\s*(and\s+)?\d+\s*seconds?)?$', caseSensitive: false).hasMatch(l)) continue;
      if (RegExp(r'^\d+\s*minutes?(\s*,?\s*(and\s+)?\d+\s*seconds?)?$', caseSensitive: false).hasMatch(l)) continue;
      if (RegExp(r'^\d+\s*seconds?$', caseSensitive: false).hasMatch(l)) continue;
      // 라인 앞 타임스탬프 프리픽스 제거 (가장 긴 형태부터)
      l = l.replaceFirst(RegExp(r'^\d{1,2}(:\d{2}){1,2}\s*'), '');
      l = l.replaceFirst(RegExp(r'^\d+\s*시간\s*\d+\s*분\s*\d+\s*초\s*'), '');
      l = l.replaceFirst(RegExp(r'^\d+\s*시간\s*\d+\s*분\s*'), '');
      l = l.replaceFirst(RegExp(r'^\d+\s*분\s*\d+\s*초\s*'), '');
      l = l.replaceFirst(RegExp(r'^\d+\s*분\s*'), '');
      l = l.replaceFirst(RegExp(r'^\d+\s*초\s*'), '');
      // 영어형 타임스탬프 프리픽스 제거 (가장 긴 형태부터)
      l = l.replaceFirst(RegExp(r'^\d+\s*hours?\s*,?\s*(and\s+)?\d+\s*minutes?\s*,?\s*(and\s+)?\d+\s*seconds?\s*', caseSensitive: false), '');
      l = l.replaceFirst(RegExp(r'^\d+\s*hours?\s*,?\s*(and\s+)?\d+\s*minutes?\s*', caseSensitive: false), '');
      l = l.replaceFirst(RegExp(r'^\d+\s*minutes?\s*,?\s*(and\s+)?\d+\s*seconds?\s*', caseSensitive: false), '');
      l = l.replaceFirst(RegExp(r'^\d+\s*hours?\s*', caseSensitive: false), '');
      l = l.replaceFirst(RegExp(r'^\d+\s*minutes?\s*', caseSensitive: false), '');
      l = l.replaceFirst(RegExp(r'^\d+\s*seconds?\s*', caseSensitive: false), '');
      l = l.trim();
      if (l.isEmpty) continue;
      out.add(l);
    }
    return out.join('\n');
  }

  /// '스크립트 복사 → 요약하기' — 떠 있는 스크립트를 추출/복사하고 팝업으로 표시
  Future<void> _onCopyScript(BuildContext context) async {
    String text = '';
    try {
      final raw = await _webViewController.runJavaScriptReturningResult(_extractTranscriptJs);
      final rawStr = raw.toString();
      debugPrint('[CopyScript] raw type=${raw.runtimeType} len=${rawStr.length} head=${rawStr.substring(0, rawStr.length < 80 ? rawStr.length : 80)}');
      text = _decodeJsResult(raw);
      debugPrint('[CopyScript] decoded len=${text.length}');
    } catch (e) {
      debugPrint('[CopyScript] 스크립트 추출 오류: $e');
    }
    if (text.startsWith('DIAG')) {
      debugPrint('[CopyScript] $text'); // 진단(자막 미로드 등)
      text = '';
    }
    text = _cleanTranscript(text);
    if (!context.mounted) return;
    if (text.trim().isEmpty) {
      debugPrint('[CopyScript] 추출 결과 비어있음 → 안내 스낵바');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자막(스크립트)이 아직 로드되지 않았어요. 스크립트가 다 표시된 뒤 다시 눌러주세요.')),
      );
      return;
    }
    // 스크립트 최상단에 메타 정보(채널명/제목/영상 생성 일자) 추가
    final pub = widget.video.publishedAt;
    String dateStr = '-';
    if (pub != null && pub.isNotEmpty) {
      final d = DateTime.tryParse(pub);
      dateStr = d != null
          ? '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
          : pub;
    }
    text = '채널명: ${widget.channel.channelName}\n'
        '제목: ${widget.video.title}\n'
        '영상 생성 일자: $dateStr\n\n$text';
    await Clipboard.setData(ClipboardData(text: text));
    // 로그인 상태면 복사된 스크립트를 서버에 저장 (실패해도 흐름 유지)
    final tk = widget.token;
    if (tk != null && tk.isNotEmpty) {
      ApiService()
          .saveYoutubeTranscript(token: tk, videoId: widget.video.videoId, transcript: text)
          .then((ok) => debugPrint('[CopyScript] 서버 저장: $ok'))
          .catchError((e) { debugPrint('[CopyScript] 서버 저장 실패: $e'); });
    }
    if (!context.mounted) return;
    // 시트가 열린 동안 WebView 터치/스크롤 차단 (뒤 유튜브가 같이 스크롤되는 누수 방지)
    try { await _webViewController.runJavaScript(_blockWebViewJs); } catch (_) {}
    if (!context.mounted) return;
    // 화면 끝까지 올라오는 바텀시트
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 1.0,
        child: _ScriptSummarySheet(
          transcript: text,
          token: widget.token,
          videoId: widget.video.videoId,
          channelName: widget.channel.channelName,
          videoTitle: widget.video.title,
        ),
      ),
    );
    try { await _webViewController.runJavaScript(_unblockWebViewJs); } catch (_) {}
  }

  // 투명 오버레이로 WebView 터치/스크롤을 막는다 (시트 동안)
  static const String _blockWebViewJs = r'''
(function(){
  if (document.getElementById('litten-block')) return;
  var o = document.createElement('div');
  o.id = 'litten-block';
  o.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;z-index:2147483647;background:transparent';
  o.addEventListener('touchmove', function(e){ e.preventDefault(); }, {passive:false});
  o.addEventListener('wheel', function(e){ e.preventDefault(); }, {passive:false});
  (document.body || document.documentElement).appendChild(o);
})();
''';
  static const String _unblockWebViewJs = r'''
(function(){ var o = document.getElementById('litten-block'); if (o) o.remove(); })();
''';

  Future<void> _onSummaryTap(BuildContext context) async {
    debugPrint('[YoutubeVideoPlayerSheet] _onSummaryTap 진입 - videoId: ${widget.video.videoId}');

    if (widget.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    // 저작권 동의 + 자막 로딩 다이얼로그 — transcript 문자열을 직접 반환
    if (!context.mounted) return;
    final transcript = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CopyrightConsentDialog(
        token: widget.token!,
        videoId: widget.video.videoId,
      ),
    );

    if (transcript == null || transcript.isEmpty || !context.mounted) return;

    // 자막을 요약 다이얼로그에 전달 — 재요청 없이 바로 요약
    await showDialog<void>(
      context: context,
      builder: (ctx) => _YoutubeSummaryDialog(
        token: widget.token!,
        video: widget.video,
        transcript: transcript,
      ),
    );
  }
}

/// YouTube 스타일 더보기/접기 텍스트 위젯
class _ExpandableText extends StatefulWidget {
  final String text;
  const _ExpandableText({required this.text});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Text(
            widget.text,
            style: const TextStyle(fontSize: 14, height: 1.65),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
          secondChild: Text(
            widget.text,
            style: const TextStyle(fontSize: 14, height: 1.65),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? '접기' : '더보기',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// 저작권 동의 체크박스 + 자막 데이터 로딩 다이얼로그
class _CopyrightConsentDialog extends StatefulWidget {
  final String token;
  final String videoId;

  const _CopyrightConsentDialog({
    required this.token,
    required this.videoId,
  });

  @override
  State<_CopyrightConsentDialog> createState() => _CopyrightConsentDialogState();
}

class _CopyrightConsentDialogState extends State<_CopyrightConsentDialog> {
  bool _agreed = false;
  bool _loading = false;
  String? _errorMessage;
  String? _transcript;

  Future<void> _fetchTranscript() async {
    debugPrint('[_CopyrightConsentDialog] _fetchTranscript 진입 - videoId: ${widget.videoId}');
    setState(() { _loading = true; _errorMessage = null; });
    try {
      final transcript = await ApiService().extractYoutubeTranscriptViaYtDlp(
        token: widget.token,
        videoId: widget.videoId,
      );
      debugPrint('[_CopyrightConsentDialog] 자막 결과 length: ${transcript?.length}');
      if (!mounted) return;
      if (transcript != null && transcript.isNotEmpty) {
        setState(() { _transcript = transcript; _loading = false; });
      } else {
        setState(() {
          _loading = false;
          _errorMessage = '자막을 가져올 수 없습니다. 자막이 없거나 지원하지 않는 영상입니다.';
        });
      }
    } catch (e) {
      debugPrint('[_CopyrightConsentDialog] 자막 오류: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = '자막 가져오기 실패: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    final canConfirm = _agreed && !_loading && _transcript != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.policy_outlined, color: color, size: 20),
          const SizedBox(width: 8),
          const Text('자막 요약', style: TextStyle(fontSize: 15)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 로딩 / 완료 / 에러 상태
            if (_loading) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: color),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '자막 데이터를 가져오는 중입니다...',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ] else if (_transcript != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    Text(
                      '자막 ${_transcript!.length}자 로드 완료',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_errorMessage!,
                    style: const TextStyle(fontSize: 12, color: Colors.red)),
              ),
              const SizedBox(height: 12),
            ] else ...[
              // 초기 상태: 자막 가져오기 안내
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text(
                  '요약을 시작하려면 먼저 자막을 가져와야 합니다.\n아래 체크박스에 동의하면 자막을 가져옵니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 저작권 동의 체크박스
            InkWell(
              onTap: _loading ? null : () async {
                final newValue = !_agreed;
                setState(() => _agreed = newValue);
                if (newValue && _transcript == null && _errorMessage == null) {
                  await _fetchTranscript();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreed,
                    onChanged: _loading ? null : (v) async {
                      setState(() => _agreed = v ?? false);
                      if ((v ?? false) && _transcript == null && _errorMessage == null) {
                        await _fetchTranscript();
                      }
                    },
                    activeColor: color,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Text(
                        '저작권 정책을 준수하며 학습 용도로만 자막을 요약합니다.',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 재시도 버튼 (에러 상태)
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _fetchTranscript,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('다시 시도', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: canConfirm
              ? () => Navigator.of(context).pop(_transcript)
              : null,
          child: const Text('요약하기'),
        ),
      ],
    );
  }
}

/// 요약 옵션 설정 + 실행 다이얼로그 (SummaryDialog와 동일한 UI)
class _YoutubeSummaryDialog extends StatefulWidget {
  final String token;
  final YoutubeVideo video;
  final String transcript;

  const _YoutubeSummaryDialog({
    required this.token,
    required this.video,
    required this.transcript,
  });

  @override
  State<_YoutubeSummaryDialog> createState() => _YoutubeSummaryDialogState();
}

class _YoutubeSummaryDialogState extends State<_YoutubeSummaryDialog> {
  String _textLanguage = 'ko';
  String _summaryLanguage = 'ko';
  int _summaryLevel = 3;
  bool _isLoading = false;
  String? _errorMessage;
  String? _summaryResult;

  String _levelDescription() => switch (_summaryLevel) {
    1 => '핵심 주제와 결론만 · 약 10%',
    2 => '주요 기능과 핵심 논의 · 약 25%',
    3 => '실무 흐름과 설계 의도 · 약 40~50%',
    4 => '전체 논의 흐름 대부분 · 약 70%',
    5 => '전체 맥락 최대한 유지 · 약 90%',
    _ => '실무 흐름과 설계 의도 · 약 40~50%',
  };

  Future<void> _onSummarize() async {
    debugPrint('[_YoutubeSummaryDialog] _onSummarize 진입 - videoId: ${widget.video.videoId}');
    setState(() { _isLoading = true; _errorMessage = null; _summaryResult = null; });

    try {
      // 요약 실행 (자막은 이미 동의 단계에서 가져옴)
      final summary = await ApiService().summarizeText(
        text: widget.transcript,
        textLanguage: _textLanguage,
        summaryLanguage: _summaryLanguage,
        summaryLevel: _summaryLevel,
      );

      debugPrint('[_YoutubeSummaryDialog] 요약 완료 - length: ${summary.length}');

      // 자막 저장
      await ApiService().saveYoutubeTranscript(
        token: widget.token,
        videoId: widget.video.videoId,
        transcript: widget.transcript,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _summaryResult = summary;
      });
    } catch (e) {
      debugPrint('[_YoutubeSummaryDialog] 오류: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '요약 실패: $e';
      });
    }
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );

  Widget _buildDropdown({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isDense: true,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: _kLanguages
          .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2, style: const TextStyle(fontSize: 13))))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildLevelDropdown() {
    const items = [
      (1, '한줄 요약'),
      (2, '간단 요약'),
      (3, '일반 요약'),
      (4, '상세 요약'),
      (5, '거의 전체'),
    ];
    return DropdownButtonFormField<int>(
      initialValue: _summaryLevel,
      isDense: true,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2, style: const TextStyle(fontSize: 13))))
          .toList(),
      onChanged: (v) => setState(() => _summaryLevel = v!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.video.title,
              style: const TextStyle(fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 요약 결과 표시
              if (_summaryResult != null) ...[
                Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    _summaryResult!,
                    style: const TextStyle(fontSize: 13, height: 1.65),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
              ],

              // 대상 언어
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 80, child: _buildLabel('대상 언어')),
                  Expanded(
                    child: _buildDropdown(
                      value: _textLanguage,
                      onChanged: (v) => setState(() => _textLanguage = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 요약 언어
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 80, child: _buildLabel('요약 언어')),
                  Expanded(
                    child: _buildDropdown(
                      value: _summaryLanguage,
                      onChanged: (v) => setState(() => _summaryLanguage = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // 요약 수준
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 80, child: _buildLabel('요약 수준')),
                  Expanded(child: _buildLevelDropdown()),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _levelDescription(),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.5),
                ),
              ),

              // 에러
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.maxFinite,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(_errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),
              ],

              // 로딩
              if (_isLoading) ...[
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: color),
                      const SizedBox(height: 8),
                      const Text('자막을 가져와 요약 중입니다...',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        if (_summaryResult == null)
          FilledButton.icon(
            onPressed: _isLoading ? null : _onSummarize,
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('요약하기'),
          ),
      ],
    );
  }
}

/// 복사된 스크립트(채널명/제목/일자 헤더 포함) + 요약 설정/실행을 담는 바텀시트
/// 영상 항목의 요약 아이콘 → 저장된 요약만 보여주는 팝업 (스크립트/다시요약 없음)
Future<void> showYoutubeSummarySheet({
  required BuildContext context,
  required String videoId,
  required String channelName,
  required String videoTitle,
  String? token,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ScriptSummarySheet(
      token: token,
      videoId: videoId,
      channelName: channelName,
      videoTitle: videoTitle,
      summaryOnly: true,
    ),
  );
}

class _ScriptSummarySheet extends StatefulWidget {
  final String transcript;
  final String? token;
  final String videoId;
  final String channelName;
  final String videoTitle;
  final bool summaryOnly; // true = 저장된 요약만 보기(스크립트/언어/다시요약 숨김)
  const _ScriptSummarySheet({
    this.transcript = '',
    this.token,
    required this.videoId,
    required this.channelName,
    required this.videoTitle,
    this.summaryOnly = false,
  });

  @override
  State<_ScriptSummarySheet> createState() => _ScriptSummarySheetState();
}

class _ScriptSummarySheetState extends State<_ScriptSummarySheet> {
  String _textLanguage = 'ko';
  String _summaryLanguage = 'ko';
  int _summaryLevel = 3;
  bool _loading = false;
  String? _summary;
  SummaryResult? _result;
  String? _error;
  final ScrollController _scriptScrollCtrl = ScrollController();
  final ScrollController _summaryScrollCtrl = ScrollController();

  // 요약 사용 제한 (무료 2회 누적 / 스탠다드 10회 월별 / 프리미엄 무제한, 메모 요약과 카운트 공유). -1=무제한
  int _summaryLimit = -1;
  int _summaryUsed = 0;
  bool _summaryIsFree = false; // 무료=누적, 그 외=월별

  bool _checkingCache = true;
  final Set<int> _savedLevels = {}; // 서버에 저장된 요약 수준들
  bool _memoSaved = false; // 현재 표시 요약을 메모로 저장했는지

  @override
  void initState() {
    super.initState();
    final subType = Provider.of<AppStateProvider>(context, listen: false).subscriptionType;
    _summaryLimit = PlanLimits.summaryPerMonth(subType);
    _summaryIsFree = subType == SubscriptionType.free;
    if (_summaryLimit >= 0) {
      UsageQuota.usedBy(UsageQuota.summary, cumulative: _summaryIsFree).then((u) {
        if (mounted) setState(() => _summaryUsed = u);
      });
    }
    _loadCachedSummary();
  }

  // 레벨 1~5의 저장 여부를 병렬 조회해 _savedLevels 구성, 저장된 레벨이 있으면 하나 표시
  Future<void> _loadCachedSummary() async {
    final api = ApiService();
    final results = await Future.wait([
      for (int lv = 1; lv <= 5; lv++)
        api.getYoutubeSummaryCache(videoId: widget.videoId, summaryLevel: lv, token: widget.token),
    ]);
    if (!mounted) return;
    SummaryResult? toShow;
    for (int i = 0; i < results.length; i++) {
      if (results[i] != null) {
        _savedLevels.add(i + 1);
        if (i + 1 == _summaryLevel) toShow = results[i]; // 현재 레벨 우선
      }
    }
    // 현재 레벨이 저장 안 됐으면 가장 높은 저장 레벨 표시
    if (toShow == null) {
      for (int lv = 5; lv >= 1; lv--) {
        if (_savedLevels.contains(lv)) { toShow = results[lv - 1]; _summaryLevel = lv; break; }
      }
    }
    setState(() {
      _checkingCache = false;
      if (toShow != null) { _result = toShow; _summary = toShow.displaySummary; }
    });
    debugPrint('[ScriptSummary] 저장된 레벨: $_savedLevels (표시 레벨 $_summaryLevel)');
  }

  // 드롭다운에서 레벨 변경 시: 저장돼 있으면 그 레벨 캐시 로드, 없으면 비움
  Future<void> _onLevelChanged(int level) async {
    setState(() { _summaryLevel = level; _memoSaved = false; });
    if (_savedLevels.contains(level)) {
      final r = await ApiService().getYoutubeSummaryCache(videoId: widget.videoId, summaryLevel: level, token: widget.token);
      if (!mounted) return;
      setState(() {
        if (r != null) { _result = r; _summary = r.displaySummary; _error = null; }
      });
    } else {
      setState(() { _result = null; _summary = null; _error = null; });
    }
  }

  @override
  void dispose() {
    _scriptScrollCtrl.dispose();
    _summaryScrollCtrl.dispose();
    super.dispose();
  }

  String _levelDesc() => switch (_summaryLevel) {
    1 => '핵심 주제와 결론만 · 약 10%',
    2 => '주요 기능과 핵심 논의 · 약 25%',
    3 => '실무 흐름과 설계 의도 · 약 40~50%',
    4 => '전체 논의 흐름 대부분 · 약 70%',
    5 => '전체 맥락 최대한 유지 · 약 90%',
    _ => '실무 흐름과 설계 의도 · 약 40~50%',
  };

  Future<void> _summarize() async {
    // 이 레벨이 이미 저장돼 있으면 새로 생성하지 않음(캐시 재사용 → 무료 횟수/비용 미차감)
    final generating = !_savedLevels.contains(_summaryLevel);
    // 플랜별 월 요약 제한 — 신규 생성 시에만 차감(캐시 재사용은 무료)
    if (_summaryLimit >= 0 && generating && !await UsageQuota.canUseBy(UsageQuota.summary, _summaryLimit, cumulative: _summaryIsFree)) {
      if (mounted) setState(() {
        _summaryUsed = _summaryLimit;
        _error = _summaryIsFree
            ? '무료 요약 $_summaryLimit회를 모두 사용했습니다. 상위 플랜으로 업그레이드하면 계속 이용할 수 있어요.'
            : '이번 달 요약 $_summaryLimit회를 모두 사용했습니다. 다음 달에 다시 이용하거나 상위 플랜으로 업그레이드하세요.';
      });
      return;
    }
    setState(() { _loading = true; _error = null; _summary = null; _result = null; _memoSaved = false; });
    try {
      // 통합 처리 API — 레벨별 캐시 재사용(forceRegenerate:false) + 저장 + 리마인드
      final r = await ApiService().processSummary(
        fileType: 'text',
        youtubeVideoId: widget.videoId,
        text: widget.transcript,
        textLanguage: _textLanguage,
        summaryLanguage: _summaryLanguage,
        summaryLevel: _summaryLevel,
        forceRegenerate: false,
        token: widget.token,
      );
      if (!mounted) return;
      // 신규 생성 성공 시에만 사용 횟수 증가 (무료=누적 / 그 외=월별)
      if (_summaryLimit >= 0 && generating) {
        await UsageQuota.incrementBy(UsageQuota.summary, cumulative: _summaryIsFree);
        if (mounted) _summaryUsed += 1;
      }
      if (!mounted) return;
      setState(() {
        _loading = false; _result = r; _summary = r.displaySummary;
        _savedLevels.add(_summaryLevel); // 이제 이 레벨은 저장됨
      });
      // 자동 저장 제거 — 사용자가 "메모로 저장" 버튼으로 직접 저장
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '요약 실패: $e'; });
    }
  }

  /// 원본 스크립트(상단) + 요약(하단)을 메모(텍스트 파일)로 저장.
  /// 텍스트 메모에서 요약 후 저장하는 것과 동일한 형식:
  ///   상단 = 원본 스크립트 본문, 하단 = SUMMARY_START 마커 + 구분선 + 📋 AI 요약 + 요약.
  /// 제목 = 채널명 앞 5자 + "-" + 제목 7자
  Future<void> _saveSummaryAsMemo(SummaryResult result) async {
    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final litten = appState.selectedLitten;
      if (litten == null) {
        debugPrint('[메모저장] 선택된 리튼 없음 → 저장 생략');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('선택된 리튼이 없어 저장할 수 없습니다.')),
          );
        }
        return;
      }

      String head(String s, int n) => s.length > n ? s.substring(0, n) : s;
      final title = '${head(widget.channelName.trim(), 5)}-${head(widget.videoTitle.trim(), 7)}';

      String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
      String html(String s) => esc(s).replaceAll('\n', '<br>');
      // 상단: 원본 스크립트 본문
      final scriptHtml = '<p>${html(widget.transcript)}</p>';
      // 하단: 요약 블록 (text_tab._summaryToHtml과 동일한 마커/구분선 형식 → 재요약 시 호환)
      final summaryBuf = StringBuffer()
        ..write('<!-- SUMMARY_START --><hr/><p><strong>📋 AI 요약</strong></p>');
      for (final line in result.displaySummary.split('\n')) {
        final t = line.trim();
        if (t.isEmpty) continue;
        if (t.startsWith('# ')) {
          summaryBuf.write('<p><strong>${esc(t.substring(2))}</strong></p>');
        } else {
          summaryBuf.write('<p>${esc(t)}</p>');
        }
      }
      summaryBuf.write('<!-- SUMMARY_END -->');
      final content = '$scriptHtml$summaryBuf';

      // 요약 메타데이터(summary/summaryHistory)를 채워야 파일리스트에서 요약 아이콘이
      // 활성(테마색)으로 보이고, 요약 보기/재요약(SummaryDialog)이 정상 동작한다.
      // (TextFile.hasSummary = summary != null && summary.isNotEmpty)
      final memo = TextFile(
        littenId: litten.id,
        title: title,
        content: content,
        summary: result.displaySummary,
        summaryHistory: [
          SummaryRecord(
            summary: result.displaySummary,
            createdAt: DateTime.now(),
            level: _summaryLevel,
            summaryLanguage: _summaryLanguage,
            textLanguage: _textLanguage,
          ),
        ],
      );
      final storage = FileStorageService.instance;
      await storage.saveTextFileContent(memo);
      final list = await storage.loadTextFiles(litten.id);
      list.insert(0, memo);
      await storage.saveTextFiles(litten.id, list);
      await appState.updateFileCount();
      appState.notifyFileListChanged(); // 파일 목록 UI 즉시 새로고침
      debugPrint('[메모저장] 완료 - "$title" (litten: ${litten.id})');
      if (mounted) {
        setState(() => _memoSaved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('메모로 저장됨: $title')),
        );
      }
    } catch (e) {
      debugPrint('[메모저장] 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('메모 저장에 실패했습니다.')),
        );
      }
    }
  }

  // 리마인드 그룹(1단) → 항목(2단) → 부가설명(3단) 표시
  Widget _buildRemindGroup(RemindGroup g) {
    final color = Theme.of(context).primaryColor;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (g.groupName.isNotEmpty)
            Text(g.groupName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ...g.items.map((it) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        margin: const EdgeInsets.only(top: 1, right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                        child: Text(it.type, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                      ),
                      Expanded(child: Text(it.content, style: const TextStyle(fontSize: 13, height: 1.4))),
                    ]),
                    if ((it.deadline ?? '').isNotEmpty || (it.assignee ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 2),
                        child: Text(
                          [if ((it.assignee ?? '').isNotEmpty) '담당 ${it.assignee}', if ((it.deadline ?? '').isNotEmpty) '기한 ${it.deadline}'].join(' · '),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ),
                    ...it.details.map((d) => Padding(
                          padding: const EdgeInsets.only(left: 10, top: 2),
                          child: Text('· $d', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4)),
                        )),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _langDropdown(String value, ValueChanged<String?> onChanged) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        isDense: true,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        items: _kLanguages
            .map((e) => DropdownMenuItem(value: e.$1, child: Text('${e.$2}  (${e.$1})', style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: onChanged,
      );

  // 요약 보기 전용 본문: 요약 수준 + 설명 + (하단 버튼 위까지 채우는) 요약/리마인드 박스
  Widget _buildSummaryOnlyBody(Color color) {
    const levels = [(1,'1. 한줄 요약'),(2,'2. 간단 요약'),(3,'3. 일반 요약'),(4,'4. 상세 요약'),(5,'5. 거의 전체')];
    final levelRow = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        const SizedBox(width: 76, child: Text('요약 수준', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _summaryLevel,
            isDense: true,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: levels.map((e) {
              final isSaved = _savedLevels.contains(e.$1);
              return DropdownMenuItem(
                value: e.$1,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(e.$2, style: const TextStyle(fontSize: 13)),
                  if (isSaved) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.check_circle, size: 13, color: Colors.green),
                    const SizedBox(width: 2),
                    const Text('요약됨', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                  ],
                ]),
              );
            }).toList(),
            onChanged: (v){ if(v!=null) _onLevelChanged(v); },
          ),
        ),
      ]),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          levelRow,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
            child: Text(_levelDesc(), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ),
          if (_checkingCache && _summary == null) ...[
            const SizedBox(height: 12),
            Row(children: const [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text('저장된 요약 확인 중…', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ],
          if (_summary != null) ...[
            const SizedBox(height: 14),
            // 하단 버튼 위까지 남은 공간을 모두 채움
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Scrollbar(
                  controller: _summaryScrollCtrl,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _summaryScrollCtrl,
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(_summary!, style: const TextStyle(fontSize: 13, height: 1.65)),
                        if (_result != null && _result!.reminds.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Row(children: [
                            Icon(Icons.checklist_rtl, size: 16, color: color),
                            const SizedBox(width: 6),
                            Text('리마인드 ${_result!.totalRemindCount}개',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 6),
                          ..._result!.reminds.map(_buildRemindGroup),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    const levels = [(1,'1. 한줄 요약'),(2,'2. 간단 요약'),(3,'3. 일반 요약'),(4,'4. 상세 요약'),(5,'5. 거의 전체')];

    Widget row(String label, Widget field) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 76, child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        Expanded(child: field),
      ]),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          // 스크롤 영역 (메타헤더+스크립트 + 요약 설정 + 결과)
          Expanded(
            child: widget.summaryOnly
              ? _buildSummaryOnlyBody(color)
              : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ② 복사된 스크립트 (요약 보기 전용에서는 숨김)
                  if (!widget.summaryOnly) ...[
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Scrollbar(
                        controller: _scriptScrollCtrl,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _scriptScrollCtrl,
                          padding: const EdgeInsets.only(right: 8),
                          // 긴 스크립트(수만 자)에서 SelectableText는 선택 영역 계산으로 메인 스레드를 멈추므로
                          // 가벼운 Text 사용 (스크립트는 이미 클립보드에 복사됨)
                          child: Text(widget.transcript, style: const TextStyle(fontSize: 13, height: 1.6)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                  ],
                  // ③ 요약 설정 (언어 선택은 요약 보기 전용에서는 숨김)
                  if (!widget.summaryOnly) ...[
                    row('대상 언어', _langDropdown(_textLanguage, (v){ if(v!=null) setState(()=>_textLanguage=v); })),
                    row('요약 언어', _langDropdown(_summaryLanguage, (v){ if(v!=null) setState(()=>_summaryLanguage=v); })),
                  ],
                  row('요약 수준', DropdownButtonFormField<int>(
                    initialValue: _summaryLevel,
                    isDense: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: levels.map((e) {
                      // 이미 요약된 수준 항목에 '✓ 요약됨' 표시
                      final isSaved = _savedLevels.contains(e.$1);
                      return DropdownMenuItem(
                        value: e.$1,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(e.$2, style: const TextStyle(fontSize: 13)),
                          if (isSaved) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.check_circle, size: 13, color: Colors.green),
                            const SizedBox(width: 2),
                            const Text('요약됨', style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
                          ],
                        ]),
                      );
                    }).toList(),
                    onChanged: (v){ if(v!=null) _onLevelChanged(v); },
                  )),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
                    child: Text(_levelDesc(), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ),
                  if (_checkingCache && _summary == null) ...[
                    const SizedBox(height: 12),
                    Row(children: const [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('저장된 요약 확인 중…', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
                  ],
                  if (_summary != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 240),
                      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                      ),
                      child: Scrollbar(
                        controller: _summaryScrollCtrl,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _summaryScrollCtrl,
                          padding: const EdgeInsets.only(right: 8),
                          child: SelectableText(_summary!, style: const TextStyle(fontSize: 13, height: 1.65)),
                        ),
                      ),
                    ),
                  ],
                  // 리마인드(계층) 표시
                  if (_result != null && _result!.reminds.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(children: [
                      Icon(Icons.checklist_rtl, size: 16, color: color),
                      const SizedBox(width: 6),
                      Text('리마인드 ${_result!.totalRemindCount}개',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 6),
                    ..._result!.reminds.map(_buildRemindGroup),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          // 고정 하단 버튼바 (항상 보임)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Builder(builder: (context) {
                final limitReached = _summaryLimit >= 0 && _summaryUsed >= _summaryLimit;
                // 현재 레벨이 이미 요약(저장)돼 있으면 '다시 요약' 비활성화
                final alreadySummarized = _savedLevels.contains(_summaryLevel);
                final canSaveMemo = _result != null && !_loading && !_memoSaved;
                final saveMemoButton = FilledButton.icon(
                  onPressed: canSaveMemo ? () => _saveSummaryAsMemo(_result!) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  icon: Icon(_memoSaved ? Icons.check : Icons.save_alt, size: 18),
                  label: Text(_memoSaved ? '저장됨' : '메모로 저장'),
                );
                return Row(children: [
                  // 닫기 — 유튜브 플레이어 시트와 동일 스타일
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    child: const Text('닫기'),
                  ),
                  const SizedBox(width: 8),
                  // 요약 보기 전용에서는 '다시 요약' 버튼 제거, '메모로 저장'을 넓게
                  if (widget.summaryOnly)
                    Expanded(child: saveMemoButton)
                  else ...[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (_loading || limitReached || alreadySummarized) ? null : _summarize,
                        style: FilledButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 14)),
                        icon: _loading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(
                          () {
                            final base = _summary == null ? '요약하기' : '다시 요약';
                            if (_summaryLimit < 0) return base; // 무제한 플랜
                            final used = _summaryUsed.clamp(0, _summaryLimit);
                            return '$base (${_summaryIsFree ? "무료 " : "이번달 "}$used/$_summaryLimit)';
                          }(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    saveMemoButton,
                  ],
                ]);
              }),
            ),
          ),
        ],
      ),
    );
  }
}
