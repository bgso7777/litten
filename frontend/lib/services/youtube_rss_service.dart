import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/youtube_channel.dart';

/// 로그인 없이(로컬 모드) 채널의 최근 영상 목록을 가져온다.
///
/// 백엔드 영상 조회는 로그인 회원 전용이므로, 비로그인 사용자는 YouTube가
/// 공개 제공하는 채널 RSS 피드(최근 ~15개)를 파싱해 영상 제목/ID/게시일을 얻는다.
/// 피드: `https://www.youtube.com/feeds/videos.xml?channel_id=CHANNEL_ID`
class YoutubeRssService {
  /// YouTube가 기본(Dart) User-Agent 요청을 봇으로 보고 차단/빈 응답을 주는 경우가
  /// 있어, 채널 검색과 동일하게 브라우저 User-Agent + Accept-Language 헤더를 붙인다.
  static const Map<String, String> _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8',
  };

  Future<List<YoutubeVideo>> fetchChannelVideos(String channelId) async {
    debugPrint('[YoutubeRssService] fetchChannelVideos 진입 - channelId: $channelId');
    try {
      final url = Uri.parse('https://www.youtube.com/feeds/videos.xml?channel_id=$channelId');
      final res = await http.get(url, headers: _browserHeaders).timeout(const Duration(seconds: 15));
      debugPrint('[YoutubeRssService] status: ${res.statusCode}, bodyLen: ${res.body.length}');
      if (res.statusCode != 200) {
        debugPrint('[YoutubeRssService] 비정상 응답 본문 일부: ${res.body.substring(0, res.body.length < 200 ? res.body.length : 200)}');
        return [];
      }
      final videos = _parse(res.body, channelId);
      debugPrint('[YoutubeRssService] 파싱된 영상 수: ${videos.length}');
      if (videos.isEmpty) {
        debugPrint('[YoutubeRssService] 영상 0개 - entry 포함 여부: ${res.body.contains('<entry>')}');
      }
      return videos;
    } catch (e) {
      debugPrint('[YoutubeRssService] 오류: $e');
      return [];
    }
  }

  List<YoutubeVideo> _parse(String xml, String channelId) {
    final videos = <YoutubeVideo>[];
    final entries = RegExp(r'<entry>([\s\S]*?)</entry>').allMatches(xml);
    for (final m in entries) {
      final e = m.group(1) ?? '';
      final vid = RegExp(r'<yt:videoId>(.*?)</yt:videoId>').firstMatch(e)?.group(1);
      final title = RegExp(r'<title>([\s\S]*?)</title>').firstMatch(e)?.group(1);
      final published = RegExp(r'<published>(.*?)</published>').firstMatch(e)?.group(1);
      if (vid == null || vid.isEmpty || title == null) continue;
      videos.add(YoutubeVideo(
        id: vid.hashCode, // 로컬 합성 ID (서버 PK 없음)
        channelId: channelId,
        videoId: vid,
        title: _unescape(title.trim()),
        publishedAt: published,
        status: 'pending',
      ));
    }
    return videos;
  }

  String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");
}
