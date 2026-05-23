import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 폰에서 YouTube 자막을 직접 수집하는 서비스.
/// 폰은 가정용 IP라 서버(클라우드 IP)와 달리 YouTube IP 차단 없음.
class YoutubeTranscriptService {
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
  static const _languages = ['ko', 'en', 'ja', 'zh-Hans', 'zh-Hant'];
  static const _maxChars = 8000;

  Future<String?> fetchTranscript(String videoId) async {
    debugPrint('[YoutubeTranscriptService] fetchTranscript 진입 - videoId: $videoId');
    try {
      // Step 1: 영상 페이지 요청
      final pageUrl = Uri.parse('https://www.youtube.com/watch?v=$videoId');
      final pageRes = await http.get(pageUrl, headers: {
        'User-Agent': _userAgent,
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
        'Accept': 'text/html,application/xhtml+xml',
      }).timeout(const Duration(seconds: 20));

      debugPrint('[YoutubeTranscriptService] 영상 페이지 응답 - status: ${pageRes.statusCode}');
      if (pageRes.statusCode != 200) return null;

      // Step 2: ytInitialPlayerResponse JSON 추출
      final playerResponse = _extractPlayerResponse(pageRes.body);
      if (playerResponse == null) {
        debugPrint('[YoutubeTranscriptService] ytInitialPlayerResponse 추출 실패 - videoId: $videoId');
        return null;
      }

      // Step 3: 자막 트랙 URL 추출
      final captionUrl = _findCaptionUrl(playerResponse);
      if (captionUrl == null) {
        debugPrint('[YoutubeTranscriptService] 자막 트랙 없음 - videoId: $videoId');
        return null;
      }
      debugPrint('[YoutubeTranscriptService] 자막 URL 발견 - videoId: $videoId');

      // Step 4: 자막 데이터 요청
      final captionRes = await http.get(
        Uri.parse(captionUrl),
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 15));

      debugPrint('[YoutubeTranscriptService] 자막 응답 - status: ${captionRes.statusCode}');
      if (captionRes.statusCode != 200) return null;

      // Step 5: 텍스트 추출
      final text = _parseTranscript(captionRes.body);
      debugPrint('[YoutubeTranscriptService] 자막 추출 완료 - videoId: $videoId, length: ${text?.length ?? 0}');
      return text;
    } catch (e) {
      debugPrint('[YoutubeTranscriptService] 자막 수집 오류 - videoId: $videoId, error: $e');
      return null;
    }
  }

  /// HTML에서 ytInitialPlayerResponse JSON 추출 (브라켓 카운팅 방식).
  Map<String, dynamic>? _extractPlayerResponse(String html) {
    for (final marker in ['ytInitialPlayerResponse = ', 'ytInitialPlayerResponse=']) {
      final markerIdx = html.indexOf(marker);
      if (markerIdx == -1) continue;

      final startIdx = html.indexOf('{', markerIdx + marker.length);
      if (startIdx == -1) continue;

      int depth = 0;
      int endIdx = -1;
      for (int i = startIdx; i < html.length; i++) {
        if (html[i] == '{') {
          depth++;
        } else if (html[i] == '}') {
          depth--;
          if (depth == 0) {
            endIdx = i;
            break;
          }
        }
      }
      if (endIdx == -1) continue;

      try {
        return jsonDecode(html.substring(startIdx, endIdx + 1)) as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }

  /// captionTracks에서 선호 언어 순서로 baseUrl 반환.
  String? _findCaptionUrl(Map<String, dynamic> playerResponse) {
    final captions = playerResponse['captions'] as Map<String, dynamic>?;
    final tracklist = captions?['playerCaptionsTracklistRenderer'] as Map<String, dynamic>?;
    final tracks = tracklist?['captionTracks'] as List<dynamic>?;
    if (tracks == null || tracks.isEmpty) return null;

    for (final lang in _languages) {
      for (final track in tracks) {
        final t = track as Map<String, dynamic>;
        final code = (t['languageCode'] as String? ?? '');
        if (code.startsWith(lang)) {
          final url = t['baseUrl'] as String?;
          if (url != null) return '$url&fmt=json3';
        }
      }
    }

    // 선호 언어 없으면 첫 번째 트랙
    final first = tracks.first as Map<String, dynamic>;
    final url = first['baseUrl'] as String?;
    return url != null ? '$url&fmt=json3' : null;
  }

  /// JSON3 또는 XML 형식 자막 파싱.
  String? _parseTranscript(String body) {
    // JSON3 형식 시도
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final events = data['events'] as List<dynamic>? ?? [];
      final buf = StringBuffer();
      for (final event in events) {
        final segs = event['segs'] as List<dynamic>?;
        if (segs == null) continue;
        for (final seg in segs) {
          final text = (seg['utf8'] as String? ?? '').replaceAll('\n', ' ').trim();
          if (text.isNotEmpty) {
            buf.write(text);
            buf.write(' ');
          }
        }
        if (buf.length >= _maxChars) break;
      }
      final result = buf.toString().trim();
      if (result.isNotEmpty) {
        return result.length > _maxChars ? result.substring(0, _maxChars) : result;
      }
    } catch (_) {}

    // XML 형식 폴백
    return _parseXmlTranscript(body);
  }

  String? _parseXmlTranscript(String xml) {
    final pattern = RegExp(r'<text[^>]*>(.*?)</text>', dotAll: true);
    final buf = StringBuffer();
    for (final match in pattern.allMatches(xml)) {
      final text = (match.group(1) ?? '')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAll('\n', ' ')
          .trim();
      if (text.isNotEmpty) {
        buf.write(text);
        buf.write(' ');
      }
      if (buf.length >= _maxChars) break;
    }
    final result = buf.toString().trim();
    return result.isEmpty ? null : (result.length > _maxChars ? result.substring(0, _maxChars) : result);
  }
}
