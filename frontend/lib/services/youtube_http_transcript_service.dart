import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 프론트엔드 직접 HTTP 방식으로 YouTube 자막 수집.
/// 사용자 기기 IP로 요청하므로 백엔드 IP 차단 문제 없음.
/// 전략: YouTube 페이지 HTML → ytInitialPlayerResponse → captionTracks URL → 자막 fetch
class YoutubeHttpTranscriptService {
  static const _ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static const _headers = {
    'User-Agent': _ua,
    'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  };

  Future<String?> fetchTranscript(String videoId) async {
    debugPrint('[YoutubeHttp] fetchTranscript 진입 - videoId: $videoId');
    try {
      // 0단계: ANDROID 클라이언트로 get_transcript (BotGuard 우회)
      final androidResult = await _fetchViaAndroidClient(videoId);
      if (androidResult != null) return androidResult;

      // 1단계: YouTube 페이지 HTML 가져오기
      final html = await _fetchPage(videoId);
      if (html == null) return null;

      // 2단계: captionTracks 추출
      final tracks = _extractCaptionTracks(html);
      if (tracks == null || tracks.isEmpty) {
        debugPrint('[YoutubeHttp] captionTracks 없음 - 자막 미제공 영상');
        return null;
      }
      debugPrint('[YoutubeHttp] captionTracks: ${tracks.length}개');

      // 3단계: 선호 언어 선택 (ko → en → ja → zh → 첫번째)
      final track = _selectTrack(tracks);
      if (track == null) return null;
      final lang = (track['languageCode'] as String? ?? 'ko').split('-')[0];
      final kind = track['kind'] as String? ?? 'asr';
      debugPrint('[YoutubeHttp] 선택 track: lang=$lang kind=$kind');

      // 4단계: 여러 URL 전략으로 자막 fetch
      final baseUrl = track['baseUrl'] as String? ?? '';

      // 전략 A: baseUrl에서 exp=xpe 제거
      if (baseUrl.isNotEmpty) {
        final simpleUrl = baseUrl.replaceAll(RegExp(r'[&?]exp=[^&]*'), '');
        debugPrint('[YoutubeHttp] 전략A simpleUrl fetch');
        final result = await _fetchAndParseXml(simpleUrl);
        if (result != null) return result;

        // 전략 B: baseUrl 원본 (exp=xpe 포함)
        debugPrint('[YoutubeHttp] 전략B baseUrl 원본 fetch');
        final result2 = await _fetchAndParseXml(baseUrl);
        if (result2 != null) return result2;

        // 전략 C: json3 포맷으로 simpleUrl 요청
        final json3Url = simpleUrl.contains('fmt=')
            ? simpleUrl.replaceAll(RegExp(r'fmt=[^&]*'), 'fmt=json3')
            : '$simpleUrl&fmt=json3';
        debugPrint('[YoutubeHttp] 전략C json3 URL fetch');
        final result3 = await _fetchAndParseJson3(json3Url);
        if (result3 != null) return result3;
      }

      // 전략 D: 완전 단순 URL
      final freshUrl = 'https://www.youtube.com/api/timedtext'
          '?v=$videoId&lang=$lang&fmt=json3&kind=$kind';
      debugPrint('[YoutubeHttp] 전략D freshUrl: $freshUrl');
      final result4 = await _fetchAndParseJson3(freshUrl);
      if (result4 != null) return result4;

      // 전략 E: xml 포맷 단순 URL
      final xmlUrl = 'https://www.youtube.com/api/timedtext'
          '?v=$videoId&lang=$lang&kind=$kind';
      debugPrint('[YoutubeHttp] 전략E xmlUrl: $xmlUrl');
      final result5 = await _fetchAndParseXml(xmlUrl);
      return result5;
    } catch (e) {
      debugPrint('[YoutubeHttp] 오류: $e');
      return null;
    }
  }

  Future<String?> _fetchPage(String videoId) async {
    try {
      final uri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
      final resp = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 20));
      debugPrint('[YoutubeHttp] 페이지 status=${resp.statusCode} len=${resp.body.length}');
      if (resp.statusCode == 200 && resp.body.length > 1000) return resp.body;
      return null;
    } catch (e) {
      debugPrint('[YoutubeHttp] 페이지 fetch 오류: $e');
      return null;
    }
  }

  List<Map<String, dynamic>>? _extractCaptionTracks(String html) {
    // 방법 1: ytInitialPlayerResponse 전체 JSON 파싱
    final iprPatterns = [
      RegExp(r'var ytInitialPlayerResponse\s*=\s*(\{)', ),
      RegExp(r'ytInitialPlayerResponse\s*=\s*(\{)'),
    ];
    for (final pat in iprPatterns) {
      final match = pat.firstMatch(html);
      if (match == null) continue;
      try {
        final start = match.start + match.group(0)!.length - 1;
        final jsonStr = _extractBalancedJson(html, start);
        if (jsonStr == null) continue;
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final tracks = _tracksFromPlayerResponse(data);
        if (tracks != null && tracks.isNotEmpty) {
          debugPrint('[YoutubeHttp] ytInitialPlayerResponse 파싱 성공');
          return tracks;
        }
      } catch (e) {
        debugPrint('[YoutubeHttp] ytInitialPlayerResponse 파싱 오류: $e');
      }
    }

    // 방법 2: captionTracks 배열 직접 추출
    final ctMatch = RegExp(r'"captionTracks":\s*(\[)').firstMatch(html);
    if (ctMatch != null) {
      try {
        final start = ctMatch.start + ctMatch.group(0)!.length - 1;
        final jsonStr = _extractBalancedJsonArray(html, start);
        if (jsonStr != null) {
          final list = jsonDecode(jsonStr) as List;
          final tracks = list.cast<Map<String, dynamic>>();
          if (tracks.isNotEmpty) {
            debugPrint('[YoutubeHttp] captionTracks 직접 추출 성공: ${tracks.length}개');
            return tracks;
          }
        }
      } catch (e) {
        debugPrint('[YoutubeHttp] captionTracks 직접 추출 오류: $e');
      }
    }

    debugPrint('[YoutubeHttp] captionTracks 추출 실패');
    return null;
  }

  List<Map<String, dynamic>>? _tracksFromPlayerResponse(Map<String, dynamic> data) {
    try {
      final captions = data['captions'] as Map<String, dynamic>?;
      final renderer = captions?['playerCaptionsTracklistRenderer'] as Map<String, dynamic>?;
      final tracks = renderer?['captionTracks'] as List<dynamic>?;
      return tracks?.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  /// JSON 객체 `{...}` 범위를 괄호 matching으로 추출
  String? _extractBalancedJson(String html, int start) {
    if (start >= html.length || html[start] != '{') return null;
    var depth = 0;
    var inStr = false;
    var escape = false;
    for (var i = start; i < html.length; i++) {
      final c = html[i];
      if (escape) { escape = false; continue; }
      if (c == '\\' && inStr) { escape = true; continue; }
      if (c == '"') { inStr = !inStr; continue; }
      if (inStr) continue;
      if (c == '{') depth++;
      else if (c == '}') {
        depth--;
        if (depth == 0) return html.substring(start, i + 1);
      }
    }
    return null;
  }

  /// JSON 배열 `[...]` 범위를 괄호 matching으로 추출
  String? _extractBalancedJsonArray(String html, int start) {
    if (start >= html.length || html[start] != '[') return null;
    var depth = 0;
    var inStr = false;
    var escape = false;
    for (var i = start; i < html.length; i++) {
      final c = html[i];
      if (escape) { escape = false; continue; }
      if (c == '\\' && inStr) { escape = true; continue; }
      if (c == '"') { inStr = !inStr; continue; }
      if (inStr) continue;
      if (c == '[') depth++;
      else if (c == ']') {
        depth--;
        if (depth == 0) return html.substring(start, i + 1);
      }
    }
    return null;
  }

  Map<String, dynamic>? _selectTrack(List<Map<String, dynamic>> tracks) {
    for (final lang in ['ko', 'en', 'ja', 'zh']) {
      for (final t in tracks) {
        if ((t['languageCode'] as String? ?? '').startsWith(lang)) return t;
      }
    }
    return tracks.isNotEmpty ? tracks.first : null;
  }

  Future<String?> _fetchAndParseXml(String url) async {
    try {
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent': _ua,
        'Accept-Language': 'ko-KR,ko;q=0.9',
        'Referer': 'https://www.youtube.com/',
      }).timeout(const Duration(seconds: 10));

      debugPrint('[YoutubeHttp] XML status=${resp.statusCode} len=${resp.body.length}'
          ' preview=${resp.body.substring(0, resp.body.length.clamp(0, 60))}');

      if (resp.statusCode != 200) return null;
      final body = resp.body;
      if (body.length < 20) return null;
      if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) return null;
      if (!body.contains('<text')) return null;

      return _parseXml(body);
    } catch (e) {
      debugPrint('[YoutubeHttp] XML fetch 오류: $e');
      return null;
    }
  }

  Future<String?> _fetchAndParseJson3(String url) async {
    try {
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent': _ua,
        'Accept-Language': 'ko-KR,ko;q=0.9',
        'Referer': 'https://www.youtube.com/',
      }).timeout(const Duration(seconds: 10));

      debugPrint('[YoutubeHttp] JSON3 status=${resp.statusCode} len=${resp.body.length}'
          ' preview=${resp.body.substring(0, resp.body.length.clamp(0, 60))}');

      if (resp.statusCode != 200) return null;
      final body = resp.body;
      if (body.length < 20) return null;
      if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) return null;

      try {
        final data = jsonDecode(body) as Map<String, dynamic>;
        final events = data['events'] as List<dynamic>? ?? [];
        final buf = StringBuffer();
        for (final e in events) {
          final segs = e['segs'] as List<dynamic>? ?? [];
          for (final s in segs) {
            final t = s['utf8'] as String? ?? '';
            if (t != '\n') buf.write(t);
          }
          buf.write(' ');
          if (buf.length >= 8000) break;
        }
        final result = buf.toString().trim();
        if (result.length > 10) return result;
      } catch (e) {
        debugPrint('[YoutubeHttp] JSON3 파싱 오류: $e');
      }
      return null;
    } catch (e) {
      debugPrint('[YoutubeHttp] JSON3 fetch 오류: $e');
      return null;
    }
  }

  String? _parseXml(String xml) {
    final buf = StringBuffer();
    final matches = RegExp(r'<text[^>]*>([\s\S]*?)<\/text>').allMatches(xml);
    for (final m in matches) {
      var t = m.group(1) ?? '';
      t = t
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&#39;', "'")
          .replaceAll('&quot;', '"')
          .replaceAll('\n', ' ')
          .trim();
      if (t.isNotEmpty) buf.write('$t ');
      if (buf.length >= 8000) break;
    }
    final result = buf.toString().trim();
    return result.length > 10 ? result : null;
  }

  // ── ANDROID 클라이언트로 get_transcript (BotGuard 우회) ─────────────
  // youtube-transcript-api 라이브러리와 동일한 방식
  Future<String?> _fetchViaAndroidClient(String videoId) async {
    try {
      debugPrint('[YoutubeHttp] ANDROID client get_transcript 시도 - videoId: $videoId');
      final params = _encodeTranscriptParams(videoId);
      final body = jsonEncode({
        'context': {
          'client': {
            'clientName': 'ANDROID',
            'clientVersion': '17.31.35',
            'androidSdkVersion': 30,
            'hl': 'ko',
            'gl': 'KR',
            'utcOffsetMinutes': 540,
          }
        },
        'params': params,
      });

      final resp = await http.post(
        Uri.parse('https://www.youtube.com/youtubei/v1/get_transcript'),
        headers: {
          'Content-Type': 'application/json',
          'X-YouTube-Client-Name': '3',
          'X-YouTube-Client-Version': '17.31.35',
          'User-Agent': 'com.google.android.youtube/17.31.35 (Linux; U; Android 11) gzip',
          'Accept-Language': 'ko-KR,ko;q=0.9',
        },
        body: body,
      ).timeout(const Duration(seconds: 15));

      debugPrint('[YoutubeHttp] ANDROID status=${resp.statusCode} len=${resp.body.length}');
      if (resp.statusCode != 200) {
        debugPrint('[YoutubeHttp] ANDROID 실패: ${resp.body.substring(0, resp.body.length.clamp(0, 200))}');
        return null;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final segs = <String>[];
      _findSegs(data, segs);
      debugPrint('[YoutubeHttp] ANDROID segs=${segs.length}');
      if (segs.isEmpty) return null;

      final buf = StringBuffer();
      for (final s in segs) {
        buf.write('$s ');
        if (buf.length >= 8000) break;
      }
      final result = buf.toString().trim();
      return result.length > 10 ? result : null;
    } catch (e) {
      debugPrint('[YoutubeHttp] ANDROID 오류: $e');
      return null;
    }
  }

  // protobuf field 1 = videoId 인코딩
  String _encodeTranscriptParams(String videoId) {
    final idBytes = utf8.encode(videoId);
    final bytes = Uint8List(2 + idBytes.length);
    bytes[0] = 0x0A; // field 1, wire type 2
    bytes[1] = idBytes.length;
    bytes.setRange(2, bytes.length, idBytes);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  void _findSegs(dynamic obj, List<String> segs) {
    if (obj == null || segs.length > 1000) return;
    if (obj is List) { for (final item in obj) _findSegs(item, segs); return; }
    if (obj is Map) {
      if (obj.containsKey('transcriptSegmentRenderer')) {
        final seg = obj['transcriptSegmentRenderer'] as Map?;
        final runs = (seg?['snippet'] as Map?)?['runs'] as List?;
        if (runs != null) {
          final text = runs.map((r) => r['text'] ?? '').join('');
          if (text.isNotEmpty) segs.add(text);
        }
        return;
      }
      for (final v in obj.values) _findSegs(v, segs);
    }
  }
}
