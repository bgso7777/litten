import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 폰에서 YouTube 자막을 직접 수집하는 서비스.
class YoutubeTranscriptService {
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
  static const _languages = ['ko', 'en', 'ja', 'zh-Hans', 'zh-Hant'];
  static const _maxChars = 8000;

  Future<String?> fetchTranscript(String videoId) async {
    debugPrint('[YoutubeTranscriptService] fetchTranscript 진입 - videoId: $videoId');
    try {
      // Step 1: 영상 페이지 요청
      final pageRes = await http.get(
        Uri.parse('https://www.youtube.com/watch?v=$videoId'),
        headers: {
          'User-Agent': _userAgent,
          'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Cookie': 'CONSENT=YES+cb; SOCS=CAI',
        },
      ).timeout(const Duration(seconds: 20));

      debugPrint('[YoutubeTranscriptService] 영상 페이지 응답 - status: ${pageRes.statusCode}');
      if (pageRes.statusCode != 200) return null;

      final cookieHeader = _extractCookies(pageRes.headers['set-cookie'] ?? '');
      debugPrint('[YoutubeTranscriptService] 추출된 쿠키 길이: ${cookieHeader.length}');

      // visitorData 추출 (ytcfg.set 안에 있음 — InnerTube 요청에 필요)
      final visitorData = _extractVisitorData(pageRes.body);
      debugPrint('[YoutubeTranscriptService] visitorData: ${visitorData ?? "없음"}');

      // Step 2: ytInitialPlayerResponse JSON 추출
      final playerResponse = _extractPlayerResponse(pageRes.body);
      if (playerResponse == null) {
        debugPrint('[YoutubeTranscriptService] ytInitialPlayerResponse 추출 실패 - InnerTube 직접 시도');
        return await _fetchViaInnerTube(videoId, visitorData, cookieHeader);
      }

      // Step 3: 자막 트랙 URL 추출
      final captionUrl = _findCaptionUrl(playerResponse);
      if (captionUrl == null) {
        debugPrint('[YoutubeTranscriptService] 자막 트랙 없음 - InnerTube 시도');
        return await _fetchViaInnerTube(videoId, visitorData, cookieHeader);
      }
      debugPrint('[YoutubeTranscriptService] 자막 URL 길이: ${captionUrl.length}');
      debugPrint('[YoutubeTranscriptService] 자막 URL: ${captionUrl.substring(0, captionUrl.length.clamp(0, 150))}');

      // Step 4-A: 원본 URL (쿠키 포함)
      final result = await _fetchCaptionUrl(captionUrl, videoId, cookieHeader);
      if (result != null) return result;

      // Step 4-B: 간단한 URL (세션 파라미터 없이)
      final lang = _extractLang(captionUrl);
      final simpleUrl = 'https://www.youtube.com/api/timedtext?v=$videoId&lang=$lang&kind=asr&fmt=xml3';
      debugPrint('[YoutubeTranscriptService] 간단한 URL 재시도: $simpleUrl');
      final result2 = await _fetchCaptionUrl(simpleUrl, videoId, cookieHeader);
      if (result2 != null) return result2;

      // Step 4-C: InnerTube fallback (WEB client + visitorData + 쿠키)
      debugPrint('[YoutubeTranscriptService] InnerTube fallback 시도');
      return await _fetchViaInnerTube(videoId, visitorData, cookieHeader);
    } catch (e) {
      debugPrint('[YoutubeTranscriptService] 자막 수집 오류: $e');
      return null;
    }
  }

  Future<String?> _fetchCaptionUrl(String url, String videoId, String cookieHeader) async {
    try {
      final headers = <String, String>{
        'Accept-Language': 'en-US',
        'User-Agent': _userAgent,
        'Referer': 'https://www.youtube.com/watch?v=$videoId',
      };
      if (cookieHeader.isNotEmpty) headers['Cookie'] = 'CONSENT=YES+cb; SOCS=CAI; $cookieHeader';
      final res = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 15));

      debugPrint('[YoutubeTranscriptService] caption 응답 - status: ${res.statusCode}, bytes: ${res.bodyBytes.length}, ct: ${res.headers['content-type']}');
      debugPrint('[YoutubeTranscriptService] caption 응답 헤더: ${res.headers}');

      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;

      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      debugPrint('[YoutubeTranscriptService] body 앞부분: ${body.substring(0, body.length.clamp(0, 200)).replaceAll('\n', ' ')}');
      return _parseTranscript(body);
    } catch (e) {
      debugPrint('[YoutubeTranscriptService] _fetchCaptionUrl 오류: $e');
      return null;
    }
  }

  /// InnerTube get_transcript API — WEB 클라이언트 + visitorData
  Future<String?> _fetchViaInnerTube(String videoId, String? visitorData, String cookieHeader) async {
    debugPrint('[YoutubeTranscriptService] InnerTube 시도 - videoId: $videoId, visitorData: ${visitorData != null ? "있음" : "없음"}');
    try {
      // protobuf: field1(string)=videoId, field2(string)=""
      final videoIdBytes = utf8.encode(videoId);
      final protoBytes = Uint8List.fromList(
        [0x0A, videoIdBytes.length, ...videoIdBytes, 0x12, 0x00],
      );
      final params = base64Url.encode(protoBytes);
      debugPrint('[YoutubeTranscriptService] InnerTube params: $params');

      final clientContext = <String, dynamic>{
        'clientName': 'WEB',
        'clientVersion': '2.20240313.05.00',
        'hl': 'ko',
        'gl': 'KR',
      };
      if (visitorData != null) clientContext['visitorData'] = visitorData;

      final res = await http.post(
        Uri.parse('https://www.youtube.com/youtubei/v1/get_transcript?prettyPrint=false'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': _userAgent,
          'Accept': '*/*',
          'Origin': 'https://www.youtube.com',
          'X-YouTube-Client-Name': '1',
          'X-YouTube-Client-Version': '2.20240313.05.00',
          'Cookie': cookieHeader.isNotEmpty ? 'CONSENT=YES+cb; SOCS=CAI; $cookieHeader' : 'CONSENT=YES+cb; SOCS=CAI',
        },
        body: jsonEncode({
          'context': {'client': clientContext},
          'params': params,
        }),
      ).timeout(const Duration(seconds: 20));

      debugPrint('[YoutubeTranscriptService] InnerTube 응답 - status: ${res.statusCode}, bytes: ${res.bodyBytes.length}');
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      // 한 줄로 로깅 (logcat 잘림 방지)
      debugPrint('[YoutubeTranscriptService] InnerTube body(한줄): ${body.replaceAll('\n', ' ').replaceAll('\r', '').substring(0, body.length.clamp(0, 600))}');
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;

      return _parseInnerTubeTranscript(body);
    } catch (e) {
      debugPrint('[YoutubeTranscriptService] InnerTube 오류: $e');
      return null;
    }
  }

  /// InnerTube get_transcript 응답에서 텍스트 추출.
  String? _parseInnerTubeTranscript(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final actions = data['actions'] as List<dynamic>?;
      if (actions == null) return null;
      final buf = StringBuffer();
      for (final action in actions) {
        final panel = action['updateEngagementPanelAction']?['content']?['transcriptRenderer']?['content']?['transcriptSearchPanelRenderer']?['body']?['transcriptSegmentListRenderer']?['initialSegments'] as List<dynamic>?;
        if (panel == null) continue;
        for (final seg in panel) {
          final text = seg['transcriptSegmentRenderer']?['snippet']?['runs']?[0]?['text'] as String?;
          if (text != null && text.trim().isNotEmpty) {
            buf.write(text.trim());
            buf.write(' ');
          }
          if (buf.length >= _maxChars) break;
        }
        if (buf.length >= _maxChars) break;
      }
      final result = buf.toString().trim();
      if (result.isNotEmpty) return result.length > _maxChars ? result.substring(0, _maxChars) : result;
    } catch (e) {
      debugPrint('[YoutubeTranscriptService] InnerTube 파싱 오류: $e');
    }
    return null;
  }

  String _extractLang(String url) {
    final uri = Uri.tryParse(url);
    return uri?.queryParameters['lang'] ?? 'ko';
  }

  String _extractCookies(String raw) {
    if (raw.isEmpty) return '';
    final cookies = <String>[];
    for (final chunk in raw.split(RegExp(r',\s*(?=[A-Za-z0-9_\-]+=)'))) {
      final nameValue = chunk.trim().split(';').first.trim();
      if (nameValue.contains('=')) cookies.add(nameValue);
    }
    return cookies.join('; ');
  }

  /// ytcfg.set({"VISITOR_DATA": "..."}) 에서 visitorData 추출
  String? _extractVisitorData(String html) {
    final match = RegExp(r'"VISITOR_DATA"\s*:\s*"([^"]+)"').firstMatch(html);
    return match?.group(1);
  }

  Map<String, dynamic>? _extractPlayerResponse(String html) {
    for (final marker in ['ytInitialPlayerResponse = ', 'ytInitialPlayerResponse=']) {
      final markerIdx = html.indexOf(marker);
      if (markerIdx == -1) continue;
      final startIdx = html.indexOf('{', markerIdx + marker.length);
      if (startIdx == -1) continue;
      int depth = 0, endIdx = -1;
      for (int i = startIdx; i < html.length; i++) {
        if (html[i] == '{') depth++;
        else if (html[i] == '}') { depth--; if (depth == 0) { endIdx = i; break; } }
      }
      if (endIdx == -1) continue;
      try { return jsonDecode(html.substring(startIdx, endIdx + 1)) as Map<String, dynamic>; } catch (_) {}
    }
    return null;
  }

  String? _findCaptionUrl(Map<String, dynamic> playerResponse) {
    final tracks = (playerResponse['captions']?['playerCaptionsTracklistRenderer']?['captionTracks'] as List<dynamic>?);
    if (tracks == null || tracks.isEmpty) return null;
    debugPrint('[YoutubeTranscriptService] 트랙 수: ${tracks.length}');
    for (final lang in _languages) {
      for (final track in tracks) {
        final t = track as Map<String, dynamic>;
        if ((t['languageCode'] as String? ?? '').startsWith(lang)) {
          debugPrint('[YoutubeTranscriptService] 선택 트랙: ${t['languageCode']}, kind: ${t['kind']}');
          return t['baseUrl'] as String?;
        }
      }
    }
    final first = tracks.first as Map<String, dynamic>;
    debugPrint('[YoutubeTranscriptService] 첫 번째 트랙: ${first['languageCode']}');
    return first['baseUrl'] as String?;
  }

  String? _parseTranscript(String body) {
    if (body.trimLeft().startsWith('<')) return _parseXmlTranscript(body);
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final events = data['events'] as List<dynamic>? ?? [];
      final buf = StringBuffer();
      for (final event in events) {
        final segs = event['segs'] as List<dynamic>?;
        if (segs == null) continue;
        for (final seg in segs) {
          final text = (seg['utf8'] as String? ?? '').replaceAll('\n', ' ').trim();
          if (text.isNotEmpty) { buf.write(text); buf.write(' '); }
        }
        if (buf.length >= _maxChars) break;
      }
      final result = buf.toString().trim();
      if (result.isNotEmpty) return result.length > _maxChars ? result.substring(0, _maxChars) : result;
    } catch (_) {}
    return _parseXmlTranscript(body);
  }

  String? _parseXmlTranscript(String xml) {
    final pattern = RegExp(r'<text[^>]*>(.*?)</text>', dotAll: true);
    final buf = StringBuffer();
    for (final match in pattern.allMatches(xml)) {
      final text = (match.group(1) ?? '')
          .replaceAll('&amp;', '&').replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>').replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'").replaceAll('\n', ' ').trim();
      if (text.isNotEmpty) { buf.write(text); buf.write(' '); }
      if (buf.length >= _maxChars) break;
    }
    final result = buf.toString().trim();
    return result.isEmpty ? null : (result.length > _maxChars ? result.substring(0, _maxChars) : result);
  }
}
