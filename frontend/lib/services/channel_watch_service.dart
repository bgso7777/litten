import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel_watch_state.dart';

/// 채널 "확인 상태"의 로컬 저장소 (스탠다드·비로그인 전용).
///
/// SharedPreferences에 단일 키로 { channelId: stateJson } 맵을 저장한다.
/// 프리미엄(로그인) 확장 시 loadAll/markSeen 내부에서 서버 호출만 덧붙이면
/// 동일 인터페이스로 동작하도록 메서드를 설계했다.
class ChannelWatchService {
  static const _key = 'yt_channel_watch_states';

  /// 모든 채널의 확인 상태 로드 (channelId → ChannelWatchState)
  static Future<Map<String, ChannelWatchState>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (k, v) => MapEntry(k, ChannelWatchState.fromJson(v as Map<String, dynamic>)),
      );
    } catch (e) {
      debugPrint('[ChannelWatchService] loadAll 파싱 오류: $e');
      return {};
    }
  }

  static Future<void> _saveAll(Map<String, ChannelWatchState> states) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(states.map((k, v) => MapEntry(k, v.toJson())));
    await prefs.setString(_key, encoded);
  }

  /// 채널을 "확인함"으로 표시 — 현재 최신 영상 시각/ID를 기록한다.
  /// 이후 그보다 더 나중 영상이 올라오면 다시 "새 영상 있음"이 된다.
  static Future<void> markSeen(
    String channelId, {
    DateTime? latestAt,
    String? latestVideoId,
    required DateTime now,
  }) async {
    final states = await loadAll();
    states[channelId] = ChannelWatchState(
      channelId: channelId,
      lastSeenAt: latestAt,
      lastSeenVideoId: latestVideoId,
      updatedAt: now,
    );
    await _saveAll(states);
    debugPrint('[ChannelWatchService] markSeen - $channelId, latestAt: $latestAt');
  }

  /// 구독 해제된 채널의 확인 상태 제거 (저장소 정리용)
  static Future<void> remove(String channelId) async {
    final states = await loadAll();
    if (states.remove(channelId) != null) await _saveAll(states);
  }
}
