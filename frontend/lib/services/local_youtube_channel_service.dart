import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/youtube_channel.dart';

/// 로그인 없이(무료/스탠다드 플랜) 등록한 영상 구독 채널을 단말 로컬에 저장한다.
///
/// 백엔드 영상 구독은 로그인 회원 전용이므로, 비로그인 사용자는 이 로컬 저장소를
/// 통해 채널을 등록/조회/삭제한다. 서버측 자동 요약·퀴즈·영상 자동수집은
/// 로컬 채널에는 적용되지 않는다(로그인 후 사용 가능).
class LocalYoutubeChannelService {
  static const String _key = 'local_youtube_channels';

  /// 로컬에 저장된 채널 목록 로드
  static Future<List<YoutubeChannel>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      debugPrint('[LocalYoutubeChannelService] load - 저장된 채널 없음');
      return [];
    }
    try {
      final list = jsonDecode(raw) as List;
      final channels = list
          .map((e) => YoutubeChannel.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('[LocalYoutubeChannelService] load - ${channels.length}개');
      return channels;
    } catch (e) {
      debugPrint('[LocalYoutubeChannelService] load - 파싱 실패: $e');
      return [];
    }
  }

  /// 채널 목록 저장(덮어쓰기)
  static Future<void> save(List<YoutubeChannel> channels) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(channels.map((c) => c.toJson()).toList());
    await prefs.setString(_key, raw);
    debugPrint('[LocalYoutubeChannelService] save - ${channels.length}개');
  }

  /// 채널 1개 추가 (호출 측에서 플랜별 개수 제한을 검사한다)
  static Future<List<YoutubeChannel>> add(YoutubeChannel channel) async {
    final channels = await load();
    // 동일 channelId 중복 방지
    if (channels.any((c) => c.channelId == channel.channelId)) {
      debugPrint('[LocalYoutubeChannelService] add - 이미 존재: ${channel.channelId}');
      return channels;
    }
    channels.add(channel);
    await save(channels);
    return channels;
  }

  /// channelId로 채널 제거
  static Future<List<YoutubeChannel>> removeByChannelId(String channelId) async {
    final channels = await load();
    channels.removeWhere((c) => c.channelId == channelId);
    await save(channels);
    debugPrint('[LocalYoutubeChannelService] removeByChannelId - $channelId, 남은 ${channels.length}개');
    return channels;
  }
}
