import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/youtube_channel.dart';

/// 로그인 없이(로컬 모드) 채널의 최근 영상 목록을 가져온다.
///
/// 백엔드 영상 조회는 로그인 회원 전용이므로, 비로그인 사용자는 YouTube가
/// 공개 제공하는 채널 RSS 피드(최근 ~15개)를 파싱해 영상 제목/ID/게시일을 얻는다.
/// 피드: `https://www.youtube.com/feeds/videos.xml?channel_id=CHANNEL_ID`
class YoutubeRssService {
  Future<List<YoutubeVideo>> fetchChannelVideos(String channelId) async {
    debugPrint('[YoutubeRssService] fetchChannelVideos 진입 - channelId: $channelId');
    try {
      final url = Uri.parse('https://www.youtube.com/feeds/videos.xml?channel_id=$channelId');
      final res = await http.get(url).timeout(const Duration(seconds: 15));
      debugPrint('[YoutubeRssService] status: ${res.statusCode}');
      if (res.statusCode != 200) return [];
      final videos = _parse(res.body, channelId);
      debugPrint('[YoutubeRssService] 파싱된 영상 수: ${videos.length}');
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
