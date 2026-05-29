import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../models/youtube_channel.dart';
import '../services/api_service.dart';

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
        // 페이지 로드 후 '더보기' 펼치고 '스크립트 표시'를 자동 클릭
        onPageFinished: (_) => _webViewController.runJavaScript(_autoOpenTranscriptScript),
      ))
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
  function forceInline(){
    var vs = document.querySelectorAll('video');
    for (var i=0;i<vs.length;i++){
      try {
        vs[i].setAttribute('playsinline','');
        vs[i].setAttribute('webkit-playsinline','');
        vs[i].playsInline = true;
      } catch(e){}
    }
  }
  // 자동재생 차단: 사용자가 플레이어를 직접 누르기 전까지 계속 정지 유지
  var killAutoplay = true;
  function pauseVideo(){
    var vs = document.querySelectorAll('video');
    for (var i=0;i<vs.length;i++){ try { if (!vs[i].paused) vs[i].pause(); } catch(e){} }
  }
  function quiet(){ forceInline(); if (killAutoplay) pauseVideo(); }
  // 사용자가 플레이어 영역을 직접 누르면 자동정지 해제 (그때부터 재생 허용)
  document.addEventListener('click', function(e){
    if (e.target && e.target.closest && e.target.closest('#player, #movie_player, .html5-video-player, ytd-player')) {
      if (killAutoplay) { killAutoplay = false; diag('사용자 재생 허용'); }
    }
  }, true);
  // 자동정지 유지 루프 (사용자가 누르기 전까지)
  setInterval(function(){ if (killAutoplay) pauseVideo(); }, 300);
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
  // 2) '스크립트 표시' 버튼 클릭 — 매칭 후보를 진단 로그로 출력하고 클릭 가능한 버튼만 클릭
  function clickTranscript(){
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
              // 스크립트 복사 → 요약하기 버튼 (WebView 아래 별도 바 — 탭 충돌 방지)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 화면에 떠 있는 유튜브 스크립트 패널의 자막을 추출하는 JS (타임스탬프 + 텍스트)
  static const String _extractTranscriptJs = r'''
(function(){
  function collect(segs){
    var out=[];
    for (var i=0;i<segs.length;i++){
      var s=segs[i];
      var tEl = s.querySelector('.segment-text') || s.querySelector('yt-formatted-string.segment-text') || s.querySelector('[class*="segment-text"]');
      var tsEl = s.querySelector('.segment-timestamp') || s.querySelector('[class*="segment-timestamp"]');
      var text = ((tEl ? tEl.textContent : s.textContent) || '').replace(/\s+/g,' ').trim();
      var ts = tsEl ? tsEl.textContent.trim() : '';
      if (text) out.push(ts ? (ts + '  ' + text) : text);
    }
    return out;
  }
  // 1) 세그먼트 렌더러에서 추출
  var sels = ['ytd-transcript-segment-renderer', '[class*="transcript-segment"]', 'yt-transcript-segment-renderer'];
  for (var k=0;k<sels.length;k++){
    var segs = document.querySelectorAll(sels[k]);
    if (segs.length){ var out = collect(segs); if (out.length) return out.join('\n'); }
  }
  // 2) 트랜스크립트 패널 innerText 통째로
  var panel = document.querySelector('ytd-transcript-renderer')
           || document.querySelector('ytd-engagement-panel-section-list-renderer[target-id*="transcript"]')
           || document.querySelector('[target-id*="transcript"]');
  if (panel){
    var t = (panel.innerText || '').trim();
    if (t.length > 30) return t;
    return 'DIAG panel-empty len=' + t.length;
  }
  return 'DIAG no-panel';
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
      // 라인 앞 타임스탬프 프리픽스 제거 (가장 긴 형태부터)
      l = l.replaceFirst(RegExp(r'^\d{1,2}(:\d{2}){1,2}\s*'), '');
      l = l.replaceFirst(RegExp(r'^\d+\s*시간\s*\d+\s*분\s*\d+\s*초\s*'), '');
      l = l.replaceFirst(RegExp(r'^\d+\s*시간\s*\d+\s*분\s*'), '');
      l = l.replaceFirst(RegExp(r'^\d+\s*분\s*\d+\s*초\s*'), '');
      l = l.replaceFirst(RegExp(r'^\d+\s*분\s*'), '');
      l = l.replaceFirst(RegExp(r'^\d+\s*초\s*'), '');
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
    if (text.startsWith('DIAG ')) {
      debugPrint('[CopyScript] $text'); // 셀렉터 진단
      text = '';
    }
    text = _cleanTranscript(text);
    if (!context.mounted) return;
    if (text.trim().isEmpty) {
      debugPrint('[CopyScript] 추출 결과 비어있음 → 안내 스낵바');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('스크립트가 화면에 표시된 상태에서 눌러주세요.')),
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
        child: _ScriptSummarySheet(transcript: text),
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
class _ScriptSummarySheet extends StatefulWidget {
  final String transcript;
  const _ScriptSummarySheet({required this.transcript});

  @override
  State<_ScriptSummarySheet> createState() => _ScriptSummarySheetState();
}

class _ScriptSummarySheetState extends State<_ScriptSummarySheet> {
  String _textLanguage = 'ko';
  String _summaryLanguage = 'ko';
  int _summaryLevel = 3;
  bool _loading = false;
  String? _summary;
  String? _error;
  final ScrollController _scriptScrollCtrl = ScrollController();
  final ScrollController _summaryScrollCtrl = ScrollController();

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
    setState(() { _loading = true; _error = null; _summary = null; });
    try {
      final s = await ApiService().summarizeText(
        text: widget.transcript,
        textLanguage: _textLanguage,
        summaryLanguage: _summaryLanguage,
        summaryLevel: _summaryLevel,
      );
      if (!mounted) return;
      setState(() { _loading = false; _summary = s; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '요약 실패: $e'; });
    }
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ② 복사된 스크립트 (라벨 없이 박스만, 넘치면 우측 스크롤바)
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
                        child: SelectableText(widget.transcript, style: const TextStyle(fontSize: 13, height: 1.6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  // ③ 요약 설정
                  row('대상 언어', _langDropdown(_textLanguage, (v){ if(v!=null) setState(()=>_textLanguage=v); })),
                  row('요약 언어', _langDropdown(_summaryLanguage, (v){ if(v!=null) setState(()=>_summaryLanguage=v); })),
                  row('요약 수준', DropdownButtonFormField<int>(
                    initialValue: _summaryLevel,
                    isDense: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: levels.map((e)=>DropdownMenuItem(value: e.$1, child: Text(e.$2, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v){ if(v!=null) setState(()=>_summaryLevel=v); },
                  )),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
                    child: Text(_levelDesc(), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ),
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
              child: Row(children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('닫기')),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _loading ? null : _summarize,
                  style: FilledButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  icon: _loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_summary == null ? '요약하기' : '다시 요약'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
