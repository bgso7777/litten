import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// WebView로 YouTube 자막 수집.
/// 전략 1: fetch/XHR 인터셉터 (get_transcript + timedtext 모두)
/// 전략 2: YouTube UI "Show transcript" 클릭 → DOM 스크래핑
/// 전략 3: get_transcript API (올바른 헤더)
class YoutubeWebViewTranscriptService {
  Future<String?> fetchTranscript(BuildContext context, String videoId) async {
    debugPrint('[YoutubeWebViewTranscript] fetchTranscript 진입 - videoId: $videoId');
    final completer = Completer<String?>();
    OverlayEntry? entry;

    void cleanup() {
      try { entry?.remove(); } catch (_) {}
    }

    void completeWith(String? result) {
      if (!completer.isCompleted) {
        completer.complete(result);
        cleanup();
      }
    }

    late final WebViewController controller;
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36');

    if (Platform.isAndroid && controller.platform is AndroidWebViewController) {
      await (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    controller
      ..addJavaScriptChannel('TranscriptResult', onMessageReceived: (msg) {
        final text = msg.message.trim();
        debugPrint('[YoutubeWebViewTranscript] JS: ${text.substring(0, text.length.clamp(0, 400))}');
        if (text.startsWith('DIAG:')) return;
        if (text.startsWith('FAIL:') || text.isEmpty) {
          completeWith(null);
          return;
        }
        completeWith(text);
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) async {
          debugPrint('[YoutubeWebViewTranscript] 페이지 로드 완료: ${url.substring(0, url.length.clamp(0, 80))}');
          final isEmbed = url.contains('/embed/');
          await controller.runJavaScript(
            isEmbed ? _buildEmbedScript(videoId) : _buildScript(videoId),
          );
        },
        onWebResourceError: (error) {
          debugPrint('[YoutubeWebViewTranscript] 오류: ${error.description}');
        },
      ));

    // embed URL: cc_load_policy=1 로 자막 강제, autoplay=1 로 플레이어 즉시 시작
    // 플레이어가 자동으로 timedtext 요청 → interceptor가 캡처
    await controller.loadRequest(
      Uri.parse('https://www.youtube.com/embed/$videoId'
          '?cc_load_policy=1&cc_lang_pref=ko&hl=ko'
          '&autoplay=1&enablejsapi=1&origin=https://www.youtube.com'),
      headers: {'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7'},
    );

    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: -2000, left: -2000, width: 1280, height: 800,
        child: WebViewWidget(controller: controller),
      ),
    );
    Overlay.of(context).insert(entry);

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        debugPrint('[YoutubeWebViewTranscript] 타임아웃 - videoId: $videoId');
        completeWith(null);
        return null;
      },
    );
  }

  String _buildScript(String videoId) {
    final safeId = videoId.replaceAll("'", "\\'");
    return "var _littenVideoId='" + safeId + "';\n" + _mainJs;
  }

  // embed 페이지 전용 스크립트: timedtext/get_transcript interceptor만 설치
  static const String _embedJs = r'''
(function() {
  var transcriptSent = false;
  var videoId = _littenVideoId;

  function sendTranscript(text) {
    if (!transcriptSent && text && text.trim().length > 10) {
      transcriptSent = true;
      TranscriptResult.postMessage(text.trim().substring(0, 8000));
    }
  }

  try { TranscriptResult.postMessage('DIAG: embed script started videoId=' + videoId); } catch(e) {}

  function parseAny(text) {
    if (!text || text.length < 10) return null;
    try {
      if (text.charAt(0) === '{') {
        var json = JSON.parse(text);
        var events = json.events || [], r = '';
        for (var i = 0; i < events.length; i++) {
          var ss = events[i].segs;
          if (ss) { for (var j = 0; j < ss.length; j++) if (ss[j].utf8 && ss[j].utf8 !== '\n') r += ss[j].utf8; r += ' '; }
          if (r.length >= 8000) break;
        }
        if (r.trim().length > 10) return r.trim();
      }
      if (text.indexOf('<text') !== -1) {
        var re = /<text[^>]*>([\s\S]*?)<\/text>/g, r2 = '', m;
        while ((m = re.exec(text)) !== null) {
          var t = m[1].replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&#39;/g,"'").replace(/\n/g,' ').trim();
          if (t) r2 += t + ' '; if (r2.length >= 8000) break;
        }
        return r2.trim() || null;
      }
    } catch(e) {}
    return null;
  }

  // XHR 인터셉터
  var oXOpen = XMLHttpRequest.prototype.open;
  var oXSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function(m, url) { this._iurl = url; return oXOpen.apply(this, arguments); };
  XMLHttpRequest.prototype.send = function() {
    var self = this, url = self._iurl || '';
    if (!transcriptSent && url.indexOf('/api/timedtext') !== -1) {
      TranscriptResult.postMessage('DIAG: [xhr] ' + url.substring(0, 120));
      var orig = self.onload;
      self.onload = function() {
        if (!transcriptSent && self.responseText && self.responseText.length > 50) {
          var p = parseAny(self.responseText); if (p) sendTranscript(p);
        }
        if (orig) orig.call(self);
      };
    }
    return oXSend.apply(this, arguments);
  };

  // fetch 인터셉터
  var oFetch = window.fetch;
  window.fetch = function(input, init) {
    var url = typeof input === 'string' ? input : (input && input.url ? input.url : '');
    if (!transcriptSent && url.indexOf('/api/timedtext') !== -1) {
      TranscriptResult.postMessage('DIAG: [fetch] ' + url.substring(0, 120));
      return oFetch.apply(this, arguments).then(function(r) {
        TranscriptResult.postMessage('DIAG: timedtext status=' + r.status);
        r.clone().text().then(function(t) {
          TranscriptResult.postMessage('DIAG: timedtext len=' + (t ? t.length : 0) + ' preview=' + (t ? t.substring(0, 80) : ''));
          if (!transcriptSent && t && t.length > 50) { var p = parseAny(t); if (p) sendTranscript(p); }
        }).catch(function(){});
        return r;
      });
    }
    return oFetch.apply(this, arguments);
  };

  // 60초 후 실패 처리
  setTimeout(function() {
    if (!transcriptSent) { transcriptSent = true; TranscriptResult.postMessage('FAIL: embed timeout'); }
  }, 60000);
})();
''';

  String _buildEmbedScript(String videoId) {
    final safeId = videoId.replaceAll("'", "\\'");
    return "var _littenVideoId='" + safeId + "';\n" + _embedJs;
  }

  static const String _mainJs = r'''
(function() {
  var videoId = _littenVideoId;
  var transcriptSent = false;

  function sendTranscript(text) {
    if (!transcriptSent && text && text.trim().length > 10) {
      transcriptSent = true;
      TranscriptResult.postMessage(text.trim().substring(0, 8000));
    }
  }
  function sendFail(reason) {
    if (!transcriptSent) { transcriptSent = true; TranscriptResult.postMessage('FAIL: ' + reason); }
  }

  try { TranscriptResult.postMessage('DIAG: script started videoId=' + videoId); } catch(e) {}

  // ── 인터셉터 설정: timedtext + get_transcript 모두 캡처 ──────────
  (function() {
    var oXOpen = XMLHttpRequest.prototype.open;
    var oXSend = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.open = function(m, url) {
      this._iurl = url; return oXOpen.apply(this, arguments);
    };
    XMLHttpRequest.prototype.send = function() {
      var self = this, url = self._iurl || '';
      if (!transcriptSent && url && (url.indexOf('/api/timedtext') !== -1 || url.indexOf('get_transcript') !== -1)) {
        TranscriptResult.postMessage('DIAG: [intercept-xhr] ' + url.substring(0, 120));
        var orig = self.onload;
        self.onload = function() {
          if (!transcriptSent && self.responseText && self.responseText.length > 50) {
            var p = parseAny(self.responseText); if (p) sendTranscript(p);
          }
          if (orig) orig.call(self);
        };
      }
      return oXSend.apply(this, arguments);
    };

    var oFetch = window.fetch;
    window.fetch = function(input, init) {
      var url = typeof input === 'string' ? input : (input && input.url ? input.url : '');
      if (!transcriptSent && url && (url.indexOf('/api/timedtext') !== -1 || url.indexOf('get_transcript') !== -1)) {
        TranscriptResult.postMessage('DIAG: [intercept-fetch] ' + url.substring(0, 120));
        return oFetch.apply(this, arguments).then(function(r) {
          r.clone().text().then(function(t) {
            if (!transcriptSent && t && t.length > 50) { var p = parseAny(t); if (p) sendTranscript(p); }
          }).catch(function(){});
          return r;
        });
      }
      return oFetch.apply(this, arguments);
    };
  })();

  // ── MutationObserver: 자막 패널 DOM 변화 감지 ───────────────────
  (function() {
    var observer = new MutationObserver(function() {
      if (transcriptSent) { observer.disconnect(); return; }
      var segs = document.querySelectorAll('.segment-text, ytd-transcript-segment-renderer .segment-text, .ytd-transcript-body-renderer .cue');
      if (segs.length > 0) {
        var result = '';
        for (var i = 0; i < segs.length; i++) {
          result += (segs[i].innerText || '').trim() + ' ';
          if (result.length >= 8000) break;
        }
        if (result.trim().length > 10) {
          TranscriptResult.postMessage('DIAG: DOM scrape found ' + segs.length + ' segments');
          sendTranscript(result.trim());
          observer.disconnect();
        }
      }
    });
    observer.observe(document.body, { childList: true, subtree: true });
    // 60초 후 자동 해제
    setTimeout(function() { observer.disconnect(); }, 60000);
  })();

  // ── ytcfg 대기 후 전략 실행 ─────────────────────────────────────
  function run(attempt) {
    try {
      if (attempt > 40) {
        TranscriptResult.postMessage('DIAG: ytcfg timeout - UI approach only');
        clickShowTranscript(1);
        return;
      }
      var cfg = window.ytcfg, ipr = window.ytInitialPlayerResponse;
      if (!cfg || !cfg.get || !ipr) {
        setTimeout(function() { run(attempt + 1); }, 500);
        return;
      }

      var ctx = cfg.get('INNERTUBE_CONTEXT') || {};
      var apiKey = cfg.get('INNERTUBE_API_KEY') || 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';
      var clientVer = (ctx.client && ctx.client.clientVersion) || '2.20240101.00.00';
      var visitorData = cfg.get('VISITOR_DATA') || '';

      TranscriptResult.postMessage('DIAG: ytcfg ready client=' + (ctx.client ? ctx.client.clientName : '?') + ' visitorData_len=' + visitorData.length);
      TranscriptResult.postMessage('DIAG: ua=' + navigator.userAgent.substring(0, 120));
      TranscriptResult.postMessage('DIAG: vp=' + window.innerWidth + 'x' + window.innerHeight);
      TranscriptResult.postMessage('DIAG: title=' + document.title.substring(0, 60));
      var appEl = document.querySelector('ytd-app');
      var watchEl = document.querySelector('ytd-watch-flexy, ytd-watch-metadata');
      var playerEl = document.querySelector('#movie_player, #player');
      TranscriptResult.postMessage('DIAG: appEl=' + (appEl?'yes':'no') + ' watchEl=' + (watchEl?'yes':'no') + ' playerEl=' + (playerEl?'yes':'no'));
      var bodySnippet = document.body ? document.body.innerHTML.substring(0, 150).replace(/\n/g,' ') : 'no body';
      TranscriptResult.postMessage('DIAG: body=' + bodySnippet);

      // ytInitialData panels 로깅
      var yid = window.ytInitialData || {};
      var yidPanels = yid.engagementPanels || [];
      TranscriptResult.postMessage('DIAG: panels=' + yidPanels.length);
      for (var pi = 0; pi < Math.min(yidPanels.length, 10); pi++) {
        try {
          var pid = ((yidPanels[pi].engagementPanelSectionListRenderer || {}).panelIdentifier) || '?';
          TranscriptResult.postMessage('DIAG: panel[' + pi + ']=' + pid);
        } catch(ePi) {}
      }
      // transcript 패널에서 직접 추출 시도
      for (var px = 0; px < yidPanels.length; px++) {
        var pr = yidPanels[px].engagementPanelSectionListRenderer;
        if (!pr) continue;
        var pxId = pr.panelIdentifier || '';
        if (pxId.indexOf('transcript') !== -1) {
          var segsFromPanel = [];
          findSegs(pr, segsFromPanel);
          if (segsFromPanel.length > 0) {
            TranscriptResult.postMessage('DIAG: ytInitialData transcript segs=' + segsFromPanel.length);
            sendTranscript(segsFromPanel.join(' '));
            return;
          }
          // 전체 패널 구조 로그 (continuationEndpoint.params 찾기)
          var panelJson = JSON.stringify(pr);
          TranscriptResult.postMessage('DIAG: transcript panel len=' + panelJson.length);
          for (var ci = 0; ci < panelJson.length; ci += 400) {
            TranscriptResult.postMessage('DIAG: panel_chunk=' + panelJson.substring(ci, ci + 400));
          }
          // continuationEndpoint params 추출 시도
          var contParams = null;
          try {
            var findParam = function(obj) {
              if (!obj || typeof obj !== 'object') return null;
              if (obj.getTranscriptEndpoint && obj.getTranscriptEndpoint.params) return obj.getTranscriptEndpoint.params;
              if (obj.continuationEndpoint && obj.continuationEndpoint.getTranscriptEndpoint) return obj.continuationEndpoint.getTranscriptEndpoint.params;
              for (var k in obj) { var r = findParam(obj[k]); if (r) return r; }
              return null;
            };
            contParams = findParam(pr);
          } catch(eFp) {}
          if (contParams) {
            TranscriptResult.postMessage('DIAG: found getTranscriptEndpoint params=' + contParams.substring(0, 80));
            // 추출한 params로 get_transcript 재시도
            if (ctx.client && visitorData) ctx.client.visitorData = visitorData;
            fetch('https://www.youtube.com/youtubei/v1/get_transcript?prettyPrint=false', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'X-Origin': 'https://www.youtube.com',
                'X-Youtube-Client-Name': '1',
                'X-Youtube-Client-Version': clientVer,
                'X-Goog-Visitor-Id': visitorData,
              },
              credentials: 'include',
              body: JSON.stringify({context: ctx, params: contParams})
            })
            .then(function(r) { TranscriptResult.postMessage('DIAG: contParams get_transcript status=' + r.status); return r.json(); })
            .then(function(json) {
              var result = parseGetTranscript(json);
              if (result && result.length > 10) { sendTranscript(result); return; }
              TranscriptResult.postMessage('DIAG: contParams get_transcript fail=' + JSON.stringify(json).substring(0, 100));
            }).catch(function(e) { TranscriptResult.postMessage('DIAG: contParams err=' + e.message); });
          } else {
            TranscriptResult.postMessage('DIAG: no getTranscriptEndpoint found in panel');
          }
        }
      }

      // captionTracks
      var tracks = null;
      try { tracks = ipr.captions.playerCaptionsTracklistRenderer.captionTracks; } catch(e) {}
      if (!tracks || tracks.length === 0) {
        TranscriptResult.postMessage('DIAG: no caption tracks, trying UI click');
        clickShowTranscript(1);
        return;
      }
      TranscriptResult.postMessage('DIAG: ' + tracks.length + ' caption track(s)');

      var langs = ['ko', 'en', 'ja', 'zh'], track = null;
      for (var i = 0; i < langs.length && !track; i++)
        for (var j = 0; j < tracks.length; j++)
          if (tracks[j].languageCode && tracks[j].languageCode.indexOf(langs[i]) === 0) { track = tracks[j]; break; }
      if (!track) track = tracks[0];
      TranscriptResult.postMessage('DIAG: track lang=' + (track.languageCode||'?') + ' kind=' + (track.kind||'?'));

      // ── 전략 A0: captionTrack baseUrl 직접 fetch (브라우저 세션/쿠키 포함) ──
      function encodeParams(vid) {
        try {
          var enc = new TextEncoder(), idBytes = enc.encode(vid);
          var bytes = [0x0A, idBytes.length].concat(Array.from(idBytes));
          var bin = String.fromCharCode.apply(null, bytes);
          return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
        } catch(e) { return ''; }
      }

      function tryGetTranscript() {
        if (transcriptSent) return;
        var params = encodeParams(videoId);
        if (ctx.client && visitorData) ctx.client.visitorData = visitorData;
        fetch('https://www.youtube.com/youtubei/v1/get_transcript?prettyPrint=false', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Origin': 'https://www.youtube.com',
            'X-Youtube-Client-Name': '1',
            'X-Youtube-Client-Version': clientVer,
            'X-Goog-Visitor-Id': visitorData,
          },
          credentials: 'include',
          body: JSON.stringify({context: ctx, params: params})
        })
        .then(function(r) { return r.json(); })
        .then(function(json) {
          if (transcriptSent) return;
          var result = parseGetTranscript(json);
          if (result && result.length > 10) { sendTranscript(result); return; }
          TranscriptResult.postMessage('DIAG: get_transcript fail: ' + JSON.stringify(json).substring(0, 120));
          clickShowTranscript(1);
        })
        .catch(function(e) {
          TranscriptResult.postMessage('DIAG: get_transcript err: ' + e.message);
          if (!transcriptSent) clickShowTranscript(1);
        });
      }

      var baseUrl = (track.baseUrl || '');
      TranscriptResult.postMessage('DIAG: baseUrl fetch start, len=' + baseUrl.length);
      fetch(baseUrl, {credentials: 'include'})
        .then(function(r) {
          TranscriptResult.postMessage('DIAG: baseUrl status=' + r.status + ' ok=' + r.ok);
          return r.text();
        })
        .then(function(t) {
          if (transcriptSent) return;
          TranscriptResult.postMessage('DIAG: baseUrl len=' + (t ? t.length : 0) + ' preview=' + (t ? t.substring(0, 80) : ''));
          if (t && t.length > 50) {
            var p = parseAny(t); if (p) { sendTranscript(p); return; }
          }
          // exp=xpe 만 제거 (fmt 변경 없음)
          var simpleUrl = baseUrl.replace(/[&?]exp=[^&]*/g, '');
          TranscriptResult.postMessage('DIAG: simpleUrl fetch');
          fetch(simpleUrl, {credentials: 'include'})
            .then(function(r2) {
              TranscriptResult.postMessage('DIAG: simpleUrl status=' + r2.status + ' ok=' + r2.ok);
              return r2.text();
            })
            .then(function(t2) {
              if (transcriptSent) return;
              TranscriptResult.postMessage('DIAG: simpleUrl len=' + (t2 ? t2.length : 0) + ' preview=' + (t2 ? t2.substring(0, 200) : ''));
              if (t2 && t2.length > 50 && t2.indexOf('<!DOCTYPE') === -1 && t2.indexOf('<html') === -1) {
                var p2 = parseAny(t2); if (p2) { sendTranscript(p2); return; }
              }
              // 간단한 timedtext URL 시도 (fmt=json3 명시)
              var lang = (track.languageCode || 'ko').split('-')[0];
              var freshUrl = 'https://www.youtube.com/api/timedtext?v=' + videoId + '&lang=' + lang + '&fmt=json3&kind=' + (track.kind || 'asr');
              TranscriptResult.postMessage('DIAG: freshUrl fetch');
              fetch(freshUrl, {credentials: 'include'})
                .then(function(r3) {
                  TranscriptResult.postMessage('DIAG: freshUrl status=' + r3.status + ' ok=' + r3.ok);
                  return r3.text();
                })
                .then(function(t3) {
                  if (transcriptSent) return;
                  TranscriptResult.postMessage('DIAG: freshUrl len=' + (t3 ? t3.length : 0) + ' preview=' + (t3 ? t3.substring(0, 100) : ''));
                  if (t3 && t3.length > 50 && t3.indexOf('<!DOCTYPE') === -1) {
                    var p3 = parseAny(t3); if (p3) { sendTranscript(p3); return; }
                  }
                  tryGetTranscript();
                }).catch(function() { tryGetTranscript(); });
            }).catch(function() { tryGetTranscript(); });
        })
        .catch(function(e) {
          TranscriptResult.postMessage('DIAG: baseUrl err=' + e.message);
          tryGetTranscript();
        });

    } catch(outerErr) {
      TranscriptResult.postMessage('FAIL: outer: ' + outerErr.message);
    }
  }

  // ── 전략 B: YouTube UI "Show transcript" 버튼 클릭 ──────────────
  function clickShowTranscript(attempt) {
    if (transcriptSent || attempt > 8) {
      if (!transcriptSent) sendFail('UI transcript click exhausted');
      return;
    }
    TranscriptResult.postMessage('DIAG: clickShowTranscript attempt=' + attempt);

    // 1) ytInitialData engagementPanels에서 직접 찾기
    try {
      var panels = (window.ytInitialData || {}).engagementPanels || [];
      for (var p = 0; p < panels.length; p++) {
        var segs = [];
        findSegs(panels[p], segs);
        if (segs.length > 0) {
          TranscriptResult.postMessage('DIAG: ytInitialData transcript found, segs=' + segs.length);
          sendTranscript(segs.join(' '));
          return;
        }
      }
    } catch(e) {}

    // 2) "..." (more actions) 메뉴 버튼 클릭
    // 데스크톱 YouTube: 세점 버튼은 actions 행에 위치 (primary info 영역)
    var secInfo = document.querySelector('ytd-video-secondary-info-renderer');
    var primaryInfo = document.querySelector('ytd-video-primary-info-renderer');
    var watchMeta = document.querySelector('ytd-watch-metadata');
    TranscriptResult.postMessage('DIAG: secInfo=' + (secInfo ? 'yes' : 'no') + ' primaryInfo=' + (primaryInfo ? 'yes' : 'no') + ' watchMeta=' + (watchMeta ? 'yes' : 'no'));
    var menuBtn = document.querySelector(
      '#actions ytd-menu-renderer yt-icon-button, ' +
      '#actions-inner ytd-menu-renderer yt-icon-button, ' +
      'ytd-watch-metadata #actions ytd-menu-renderer yt-icon-button, ' +
      'ytd-video-primary-info-renderer #actions ytd-menu-renderer yt-icon-button, ' +
      'ytd-video-primary-info-renderer ytd-menu-renderer yt-icon-button, ' +
      '#info ytd-menu-renderer yt-icon-button, ' +
      'ytd-video-secondary-info-renderer ytd-menu-renderer yt-icon-button'
    );
    if (menuBtn) {
      var outerText = (menuBtn.getAttribute('aria-label') || menuBtn.innerText || '').substring(0, 50);
      TranscriptResult.postMessage('DIAG: clicking more-actions menu btn aria=' + outerText);
      menuBtn.click();
      setTimeout(function() { findAndClickTranscriptItem(attempt); }, 1500);
      return;
    }

    // 3) "더보기" / "Show more" 버튼 (description 확장)
    var moreBtn = document.querySelector('#description tp-yt-paper-button, #description .ytd-text-inline-expander');
    if (moreBtn) { moreBtn.click(); }

    // 4) aria-label로 직접 찾기
    var allBtns = document.querySelectorAll('button, yt-icon-button, tp-yt-paper-button, ytd-button-renderer');
    for (var i = 0; i < allBtns.length; i++) {
      var aria = (allBtns[i].getAttribute('aria-label') || '').toLowerCase();
      var text = (allBtns[i].innerText || '').toLowerCase();
      if (aria.includes('more action') || aria.includes('추가 작업') || aria.includes('추가 옵션') || aria.includes('more options')) {
        TranscriptResult.postMessage('DIAG: found btn by aria: ' + aria);
        allBtns[i].click();
        setTimeout(function() { findAndClickTranscriptItem(attempt); }, 2000);
        return;
      }
    }

    TranscriptResult.postMessage('DIAG: no menu btn found, retry in 2s');
    setTimeout(function() { clickShowTranscript(attempt + 1); }, 2000);
  }

  function findAndClickTranscriptItem(attempt) {
    var items = document.querySelectorAll(
      'ytd-menu-service-item-renderer, tp-yt-paper-item, ytd-menu-popup-renderer tp-yt-paper-item, ' +
      '.ytd-menu-popup-renderer yt-formatted-string'
    );
    TranscriptResult.postMessage('DIAG: menu items found: ' + items.length);
    for (var i = 0; i < items.length; i++) {
      var t = (items[i].innerText || items[i].textContent || '').trim().toLowerCase();
      TranscriptResult.postMessage('DIAG: item[' + i + ']=' + t.substring(0, 40));
      if (t.includes('transcript') || t.includes('자막') || t.includes('대본') || t.includes('스크립트') || t.includes('script')) {
        TranscriptResult.postMessage('DIAG: clicking transcript item: ' + t.substring(0, 40));
        items[i].click();
        // DOM 스크래핑은 MutationObserver가 처리
        // get_transcript 인터셉트도 처리
        return;
      }
    }
    TranscriptResult.postMessage('DIAG: transcript item not found in ' + items.length + ' items');
    // Escape menu and retry
    document.dispatchEvent(new KeyboardEvent('keydown', {key: 'Escape', bubbles: true}));
    setTimeout(function() { clickShowTranscript(attempt + 1); }, 2000);
  }

  function findSegs(obj, segs) {
    if (!obj || typeof obj !== 'object') return;
    if (Array.isArray(obj)) { for (var i=0;i<obj.length;i++) findSegs(obj[i], segs); return; }
    if (obj.transcriptSegmentRenderer) {
      var seg = obj.transcriptSegmentRenderer, text = '';
      if (seg.snippet && seg.snippet.runs) for (var r=0;r<seg.snippet.runs.length;r++) text += (seg.snippet.runs[r].text||'');
      if (text) segs.push(text);
      return;
    }
    var keys = Object.keys(obj);
    for (var k=0; k<keys.length; k++) { findSegs(obj[keys[k]], segs); if (segs.length > 1000) break; }
  }

  function parseGetTranscript(json) {
    try {
      var segs = [];
      findSegs(json, segs);
      TranscriptResult.postMessage('DIAG: parseGetTranscript segs=' + segs.length);
      var r = ''; for (var i=0;i<segs.length;i++) { r += segs[i]+' '; if (r.length>=8000) break; }
      return r.trim();
    } catch(e) { return ''; }
  }

  function parseAny(text) {
    try {
      if (text.charAt(0) === '{') {
        var json = JSON.parse(text);
        // get_transcript response
        var segs = []; findSegs(json, segs);
        if (segs.length > 0) {
          var r = ''; for (var i=0;i<segs.length;i++) { r+=segs[i]+' '; if (r.length>=8000) break; }
          if (r.trim()) return r.trim();
        }
        // json3 timedtext
        var events = json.events || [], r2 = '';
        for (var i=0;i<events.length;i++) {
          var ss = events[i].segs;
          if (ss) { for (var j=0;j<ss.length;j++) if (ss[j].utf8 && ss[j].utf8!=='\n') r2+=ss[j].utf8; r2+=' '; }
          if (r2.length>=8000) break;
        }
        if (r2.trim().length > 10) return r2.trim();
      }
      if (text.indexOf('<text') !== -1) {
        var re = /<text[^>]*>([\s\S]*?)<\/text>/g, r3='', m;
        while ((m=re.exec(text))!==null) {
          var t = m[1].replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&#39;/g,"'").replace(/\n/g,' ').trim();
          if (t) r3+=t+' '; if (r3.length>=8000) break;
        }
        return r3.trim() || null;
      }
      return null;
    } catch(e) { return null; }
  }

  run(0);
})();
''';
}
