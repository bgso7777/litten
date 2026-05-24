import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// 사용자에게 보이는 WebView로 YouTube 자막 수집.
/// 1) WebView에서 YouTube 페이지를 보여줌 (BotGuard 정상 통과)
/// 2) JS로 자막 패널 자동 오픈 시도
/// 3) 사용자가 "자막 가져오기" 버튼 탭 → 화면의 자막 텍스트 수집
class YoutubeTranscriptSheet extends StatefulWidget {
  final String videoId;
  final String videoTitle;
  final Future<void> Function(String transcript) onTranscriptFound;

  const YoutubeTranscriptSheet({
    super.key,
    required this.videoId,
    required this.videoTitle,
    required this.onTranscriptFound,
  });

  static Future<void> show(
    BuildContext context, {
    required String videoId,
    required String videoTitle,
    required Future<void> Function(String transcript) onTranscriptFound,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => YoutubeTranscriptSheet(
        videoId: videoId,
        videoTitle: videoTitle,
        onTranscriptFound: onTranscriptFound,
      ),
    );
  }

  @override
  State<YoutubeTranscriptSheet> createState() => _YoutubeTranscriptSheetState();
}

class _YoutubeTranscriptSheetState extends State<YoutubeTranscriptSheet> {
  late final WebViewController _controller;
  bool _pageLoaded = false;
  bool _extracting = false;
  String _statusMsg = '페이지 로딩 중...';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      );

    if (Platform.isAndroid && _controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller
      ..addJavaScriptChannel('TranscriptExtract', onMessageReceived: (msg) {
        final text = msg.message.trim();
        debugPrint('[TranscriptSheet] JS: ${text.substring(0, text.length.clamp(0, 200))}');
        if (text.startsWith('STATUS:')) {
          if (mounted) setState(() => _statusMsg = text.substring(7));
          return;
        }
        if (text.startsWith('FAIL:')) {
          if (mounted) setState(() { _extracting = false; _statusMsg = '자막을 찾을 수 없습니다. 직접 "스크립트 보기"를 눌러주세요.'; });
          return;
        }
        // 성공 - 자막 텍스트 수신
        _handleTranscript(text);
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() { _pageLoaded = false; _statusMsg = '페이지 로딩 중...'; });
        },
        onPageFinished: (url) async {
          debugPrint('[TranscriptSheet] 페이지 로드: $url');
          if (mounted) setState(() { _pageLoaded = true; _statusMsg = '자막 패널 열기 시도 중...'; });
          await Future.delayed(const Duration(seconds: 3));
          await _controller.runJavaScript(_autoOpenScript);
        },
        onWebResourceError: (e) {
          debugPrint('[TranscriptSheet] 오류: ${e.description}');
        },
      ))
      ..loadRequest(
        Uri.parse('https://www.youtube.com/watch?v=${widget.videoId}'),
        headers: {'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8'},
      );
  }

  Future<void> _handleTranscript(String text) async {
    if (!mounted) return;
    setState(() { _extracting = false; _statusMsg = '자막 수집 완료!'; });
    Navigator.of(context).pop();
    await widget.onTranscriptFound(text);
  }

  Future<void> _extractTranscript() async {
    if (_extracting) return;
    setState(() { _extracting = true; _statusMsg = '자막 텍스트 수집 중...'; });
    await _controller.runJavaScript(_extractScript);
    // 3초 후에도 결과 없으면 상태 초기화
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _extracting) {
        setState(() { _extracting = false; _statusMsg = '자막을 찾을 수 없습니다. 화면에 자막이 보이는지 확인하세요.'; });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return SizedBox(
      height: screenH * 0.85,
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YouTube 자막 가져오기',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text(widget.videoTitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          // 안내 메시지
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.blue.shade50,
            child: Text(
              _statusMsg,
              style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
            ),
          ),
          // WebView
          Expanded(child: WebViewWidget(controller: _controller)),
          // 하단 버튼
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '화면에 자막이 보이면 아래 버튼을 눌러주세요.\n자막이 안 보이면 "..." → "스크립트 보기"를 직접 눌러보세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _pageLoaded && !_extracting ? _extractTranscript : null,
                      icon: _extracting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.content_copy),
                      label: Text(_extracting ? '수집 중...' : '자막 가져오기'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 페이지 로드 후 실행: 3가지 방법 순차 시도
  static const String _autoOpenScript = r'''
(function() {
  var _done = false;

  function succeed(text) {
    if (_done) return;
    _done = true;
    TranscriptExtract.postMessage(text.substring(0, 8000));
  }

  // ── 공통: transcriptSegmentRenderer 재귀 탐색 ──
  function extractSegs(data) {
    var segs = [];
    function fs(o, d) {
      if (_done || !o || typeof o !== 'object' || d > 20) return;
      if (Array.isArray(o)) { o.forEach(function(i){ fs(i,d+1); }); return; }
      if (o.transcriptSegmentRenderer) {
        var t = ((o.transcriptSegmentRenderer.snippet||{}).runs||[]).map(function(r){return r.text||'';}).join('');
        if(t) segs.push(t); return;
      }
      Object.values(o).forEach(function(v){ fs(v,d+1); });
    }
    fs(data, 0);
    return segs;
  }

  // ── 방법 1: fetch 인터셉터 (YouTube 자체 API 호출 가로채기) ──
  var _origFetch = window.fetch;
  window.fetch = function() {
    var args = Array.from(arguments);
    var url = typeof args[0] === 'string' ? args[0] : ((args[0]||{}).url||'');
    var p = _origFetch.apply(window, args);
    if (url.includes('get_transcript')) {
      p.then(function(resp) {
        resp.clone().json().then(function(data) {
          var segs = extractSegs(data);
          if (segs.length > 0) succeed(segs.join(' '));
        }).catch(function(){});
      }).catch(function(){});
    }
    return p;
  };

  // ── 방법 2: ytInitialPlayerResponse caption track URL (서명된 timedtext URL) ──
  TranscriptExtract.postMessage('STATUS: 자막 트랙 URL 시도 중...');
  try {
    var resp = window.ytInitialPlayerResponse || {};
    var tracks = ((resp.captions||{}).playerCaptionsTracklistRenderer||{}).captionTracks||[];
    TranscriptExtract.postMessage('STATUS: 자막 트랙 수=' + tracks.length);
    var track = null;
    for (var i = 0; i < tracks.length; i++) {
      if (!track) track = tracks[i];
      if ((tracks[i].languageCode||'') === 'ko') { track = tracks[i]; break; }
    }
    if (track && track.baseUrl) {
      TranscriptExtract.postMessage('STATUS: 자막 트랙 URL 수집 중...');

      function parseXmlTranscript(xml) {
        var matches = xml.match(/<text[^>]*>[\s\S]*?<\/text>/g) || [];
        if (matches.length === 0) return '';
        return matches.map(function(m) {
          return m.replace(/<[^>]*>/g,'')
            .replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>')
            .replace(/&#39;/g,"'").replace(/&quot;/g,'"').replace(/\n/g,' ').trim();
        }).filter(function(t){ return t.length > 0; }).join(' ');
      }

      // fmt=json3 시도 → 실패 시 XML(srv1) 시도 → 실패 시 원본 URL 시도
      function tryFmt(fmts, idx) {
        if (idx >= fmts.length) {
          TranscriptExtract.postMessage('STATUS: 자막 URL 모두 실패. "스크립트 보기"를 눌러주세요.');
          return;
        }
        var suffix = fmts[idx];
        var url = track.baseUrl + suffix;
        fetch(url, { credentials: 'include' })
          .then(function(r) {
            TranscriptExtract.postMessage('STATUS: timedtext[' + idx + '] ' + r.status);
            if (!r.ok) throw new Error('HTTP ' + r.status);
            return r.text();
          })
          .then(function(body) {
            if (!body || body.trim().length < 10) { tryFmt(fmts, idx + 1); return; }
            var text = '';
            if (body.trim().startsWith('{') || body.trim().startsWith('[')) {
              try {
                var data = JSON.parse(body);
                text = (data.events||[]).map(function(e){ return (e.segs||[]).map(function(s){ return s.utf8||''; }).join(''); }).filter(function(t){ return t.trim().length>0; }).join(' ');
              } catch(e) { tryFmt(fmts, idx + 1); return; }
            } else {
              text = parseXmlTranscript(body);
            }
            if (text.trim().length > 10) { succeed(text.trim()); }
            else { tryFmt(fmts, idx + 1); }
          })
          .catch(function(e) {
            TranscriptExtract.postMessage('STATUS: timedtext[' + idx + '] 오류: ' + e.message);
            tryFmt(fmts, idx + 1);
          });
      }

      tryFmt(['&fmt=json3', '&fmt=srv1', '&fmt=srv3', ''], 0);
    } else {
      TranscriptExtract.postMessage('STATUS: 자막 트랙 없음. "스크립트 보기"를 눌러주세요.');
    }
  } catch(e) {
    TranscriptExtract.postMessage('STATUS: 오류: ' + e.message);
  }

  // ── 방법 3: YouTube 내부 이벤트로 transcript 패널 직접 열기 ──
  function tryOpenPanel(attempt) {
    if (_done || attempt > 20) {
      TranscriptExtract.postMessage('STATUS: 자막을 자동으로 가져올 수 없습니다. 영상 아래 "좋아요/공유" 버튼 옆 "..." → "스크립트 보기"를 눌러주세요.');
      return;
    }

    // 방법 A: ytd-app의 yt-action 이벤트 디스패치 (YouTube 내부 SPA 명령)
    if (attempt === 1) {
      try {
        var panelId = null;
        var panels = (window.ytInitialData||{}).engagementPanels||[];
        for (var i=0; i<panels.length; i++) {
          var pr = (panels[i].engagementPanelSectionListRenderer||{});
          if ((pr.panelIdentifier||'').includes('transcript')) { panelId = pr.panelIdentifier; break; }
        }
        if (panelId) {
          var app = document.querySelector('ytd-app');
          if (app) {
            app.dispatchEvent(new CustomEvent('yt-action', {
              bubbles: true, composed: true,
              detail: { actionName: 'yt-open-engagement-panel-command',
                args: [{ openEngagementPanelCommand: { identifier: panelId } }] }
            }));
            TranscriptExtract.postMessage('STATUS: 패널 명령 전송 (id=' + panelId + ')');
          }
        }
      } catch(e) { TranscriptExtract.postMessage('STATUS: 패널 명령 오류: ' + e.message); }
    }

    // 방법 B: DOM에서 "스크립트 보기" 텍스트 직접 탐색 후 클릭
    var allText = document.querySelectorAll('ytd-menu-service-item-renderer, tp-yt-paper-item, yt-formatted-string, button span, a span');
    for (var j=0; j<allText.length; j++) {
      var t = (allText[j].innerText||allText[j].textContent||'').trim().toLowerCase();
      if (t==='스크립트 보기'||t==='show transcript'||t==='view transcript'||t==='open transcript') {
        allText[j].click();
        TranscriptExtract.postMessage('STATUS: 스크립트 버튼 클릭!');
        return;
      }
    }

    // 방법 C: 영상 액션 "..." 버튼 클릭
    var moreBtn = null;
    var candidates = document.querySelectorAll('yt-icon-button, button');
    for (var k=0; k<candidates.length; k++) {
      var lbl = (candidates[k].getAttribute('aria-label')||'').toLowerCase();
      var parent = candidates[k].closest('ytd-watch-metadata, #primary-inner, ytd-video-primary-info-renderer');
      if (parent && (lbl.includes('추가') || lbl.includes('more action') || lbl.includes('more option'))) {
        moreBtn = candidates[k]; break;
      }
    }
    if (!moreBtn) {
      // 더 넓게 탐색
      candidates = document.querySelectorAll('[aria-label]');
      for (var l=0; l<candidates.length; l++) {
        var lbl2 = (candidates[l].getAttribute('aria-label')||'').toLowerCase();
        if (lbl2==='추가 작업' || lbl2==='more actions' || lbl2==='more options') { moreBtn=candidates[l]; break; }
      }
    }
    if (moreBtn) {
      moreBtn.click();
      TranscriptExtract.postMessage('STATUS: 더보기 버튼 클릭');
      setTimeout(function(){
        document.querySelectorAll('ytd-menu-service-item-renderer, tp-yt-paper-item').forEach(function(item){
          var t2=(item.innerText||'').toLowerCase();
          if(t2.includes('transcript')||t2.includes('자막')||t2.includes('스크립트')){ item.click(); }
        });
      }, 1000);
      return;
    }

    setTimeout(function(){ tryOpenPanel(attempt+1); }, 1000);
  }

  tryOpenPanel(1);
})();
''';

  // 버튼 클릭 시: 트랜스크립트 전용 셀렉터로 DOM 수집 후 API 재시도
  static const String _extractScript = r'''
(function() {
  TranscriptExtract.postMessage('STATUS: DOM 수집 중...');

  // 1) 트랜스크립트 세그먼트 전용 셀렉터
  var segs = document.querySelectorAll(
    'ytd-transcript-segment-renderer .segment-text, ' +
    '.segment-text, ' +
    'ytd-transcript-segment-renderer'
  );
  if (segs.length > 0) {
    var result = Array.from(segs).map(function(s) { return (s.innerText||'').replace(/\d+:\d+/g,'').trim(); }).join(' ');
    if (result.trim().length > 10) { TranscriptExtract.postMessage(result.trim().substring(0,8000)); return; }
  }

  // 2) 모바일 YouTube 세그먼트
  var mSegs = document.querySelectorAll('ytm-transcript-segment-renderer');
  if (mSegs.length > 0) {
    var result2 = Array.from(mSegs).map(function(s){ return (s.innerText||'').replace(/\d+:\d+/g,'').trim(); }).join(' ');
    if (result2.trim().length > 10) { TranscriptExtract.postMessage(result2.trim().substring(0,8000)); return; }
  }

  // 3) ytd-transcript-renderer (트랜스크립트 전용 패널)
  var transcriptRenderer = document.querySelector('ytd-transcript-renderer, ytd-transcript-search-panel-renderer');
  if (transcriptRenderer) {
    var txt = (transcriptRenderer.innerText||'').replace(/\d+:\d+/g,'').trim();
    if (txt.length > 10) { TranscriptExtract.postMessage(txt.substring(0,8000)); return; }
  }

  // 4) 트랜스크립트 패널만 (댓글/다른 패널 제외)
  var panels = document.querySelectorAll('ytd-engagement-panel-section-list-renderer');
  for (var i = 0; i < panels.length; i++) {
    var panelId = (panels[i].getAttribute('target-id')||panels[i].id||'').toLowerCase();
    if (!panelId.includes('transcript')) continue;
    var panelTxt = (panels[i].innerText||'').replace(/\d+:\d+/g,'').trim();
    if (panelTxt.length > 50) { TranscriptExtract.postMessage(panelTxt.substring(0,8000)); return; }
  }

  // 5) DOM 실패 → API 재시도 (INNERTUBE_API_KEY + SAPISIDHASH)
  TranscriptExtract.postMessage('STATUS: API 재시도 중...');

  function findParams(obj, d) {
    if (!obj || typeof obj !== 'object' || d > 15) return null;
    if (obj.getTranscriptEndpoint && obj.getTranscriptEndpoint.params) return obj.getTranscriptEndpoint.params;
    var vals = Array.isArray(obj) ? obj : Object.values(obj);
    for (var i = 0; i < vals.length; i++) { var r = findParams(vals[i], d+1); if (r) return r; }
    return null;
  }

  var params = findParams(window.ytInitialData||{}, 0);
  if (!params) { TranscriptExtract.postMessage('FAIL: 자막 없음'); return; }

  var ctx; try { ctx = ytcfg.get('INNERTUBE_CONTEXT'); } catch(e) {}
  if (!ctx) { TranscriptExtract.postMessage('FAIL: ytcfg 없음'); return; }

  var apiKey = ''; try { apiKey = ytcfg.get('INNERTUBE_API_KEY')||''; } catch(e) {}
  var url = '/youtubei/v1/get_transcript' + (apiKey ? '?key='+apiKey : '');

  var sapisid = '';
  var m = document.cookie.match(/(?:^|;\s*)(?:SAPISID|__Secure-3PAPISID)=([^;]*)/);
  if (m) sapisid = m[1];

  function doFetch(auth) {
    var hdrs = { 'Content-Type':'application/json', 'X-Origin':'https://www.youtube.com',
      'X-YouTube-Client-Name':'1', 'X-YouTube-Client-Version':(ctx.client||{}).clientVersion||'' };
    if (auth) hdrs['Authorization'] = auth;
    fetch(url, { method:'POST', headers:hdrs, credentials:'include', body:JSON.stringify({context:ctx, params:params}) })
      .then(function(r){ if(!r.ok) throw new Error('HTTP '+r.status); return r.json(); })
      .then(function(data){
        var segsArr = [];
        function fs(o, d) {
          if (!o || typeof o !== 'object' || d > 20) return;
          if (Array.isArray(o)) { o.forEach(function(i){ fs(i,d+1); }); return; }
          if (o.transcriptSegmentRenderer) {
            var t = ((o.transcriptSegmentRenderer.snippet||{}).runs||[]).map(function(r){return r.text||'';}).join('');
            if(t) segsArr.push(t); return;
          }
          Object.values(o).forEach(function(v){ fs(v,d+1); });
        }
        fs(data, 0);
        if (segsArr.length > 0) TranscriptExtract.postMessage(segsArr.join(' ').substring(0,8000));
        else TranscriptExtract.postMessage('FAIL: 자막 없음 (API 0개)');
      })
      .catch(function(e){ TranscriptExtract.postMessage('FAIL: ' + e.message); });
  }

  if (sapisid) {
    var ts = Math.floor(Date.now()/1000);
    crypto.subtle.digest('SHA-1', new TextEncoder().encode(ts+' '+sapisid+' https://www.youtube.com'))
      .then(function(buf){ var hex=Array.from(new Uint8Array(buf)).map(function(b){return b.toString(16).padStart(2,'0');}).join(''); doFetch('SAPISIDHASH '+ts+'_'+hex); })
      .catch(function(){ doFetch(null); });
  } else { doFetch(null); }
})();
''';
}
