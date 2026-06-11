import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'litten_service.dart';
import '../models/litten.dart';

/// 캘린더 일정(LittenSchedule) 서버 동기화 서비스.
///
/// 파일/리튼 동기화(SyncService, 프리미엄 전용)와 분리된 **로그인 기준** 일정 동기화.
///   - 비로그인: 로컬에만 저장 (이 서비스의 모든 메서드는 _canSync 게이트로 no-op)
///   - 로그인: note_schedule 테이블에 회원 단위 저장/동기화 (프리미엄 무관)
///
/// 충돌 해결은 리튼 updatedAt 기준 LWW. 일정은 리튼에 종속되므로,
/// 서버 일정 수신 시 로컬에 해당 리튼이 없으면 표시용 title로 최소 리튼을 생성한다.
class ScheduleSyncService {
  static ScheduleSyncService? _instance;
  static ScheduleSyncService get instance => _instance ??= ScheduleSyncService._();
  ScheduleSyncService._();

  final ApiService _api = ApiService();
  final LittenService _littenService = LittenService();
  AuthServiceImpl? _authService;
  VoidCallback? _onChanged; // 로컬 일정이 바뀌면(서버→로컬 반영) UI 리로드 트리거

  void init(AuthServiceImpl authService, {VoidCallback? onChanged}) {
    _authService = authService;
    _onChanged = onChanged;
    debugPrint('[ScheduleSyncService] init 완료');
  }

  /// 일정 동기화 활성 조건 = 로그인(프리미엄 무관). 파일 동기화와 달리 isPremium을 요구하지 않는다.
  bool get _canSync {
    final auth = _authService;
    if (auth == null) return false;
    return auth.authStatus == AuthStatus.authenticated && auth.currentUser != null;
  }

  Future<String?> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // a가 b보다 "더 최신"인지 2초 여유로 판정 (서버 초 단위 절단/시계 오차 흡수).
  bool _isNewer(DateTime a, DateTime b) => a.isAfter(b.add(const Duration(seconds: 2)));

  /// 일정 생성/수정 시 서버 업서트 (로그인 시). schedule이 없으면 no-op.
  Future<void> pushSchedule(Litten litten) async {
    if (!_canSync) return;
    if (litten.schedule == null) return;
    // undefined(미분류) 리튼은 캘린더/동기화 대상이 아니므로 서버에 올리지 않는다.
    if (litten.title == 'undefined') return;
    final token = await _loadToken();
    if (token == null) return;
    debugPrint('[ScheduleSyncService] pushSchedule - littenId: ${litten.id}');
    await _api.upsertSchedule(token: token, scheduleJson: {
      'littenId': litten.id,
      'title': litten.title,
      'updatedAt': litten.updatedAt.toIso8601String(),
      'notificationCount': litten.notificationCount,
      'schedule': litten.schedule!.toJson(),
    });
  }

  /// 일정 삭제 시 서버에 전파 (로그인 시). 다음 동기화에서 부활 방지.
  Future<void> deleteScheduleRemote(String littenId) async {
    if (!_canSync) return;
    final token = await _loadToken();
    if (token == null) return;
    debugPrint('[ScheduleSyncService] deleteScheduleRemote - littenId: $littenId');
    await _api.deleteSchedule(token: token, littenId: littenId);
  }

  /// 로컬의 모든 일정(schedule을 가진 리튼)을 일괄 업로드 (로그인 시 이관용).
  Future<void> uploadAllSchedules() async {
    if (!_canSync) return;
    final locals = await _littenService.getAllLittens();
    // undefined(미분류) 리튼은 일정 동기화 대상에서 제외
    final scheduled = locals.where((l) => l.schedule != null && l.title != 'undefined').toList();
    debugPrint('[ScheduleSyncService] uploadAllSchedules - ${scheduled.length}개');
    for (final l in scheduled) {
      await pushSchedule(l);
    }
  }

  /// 서버 일정 목록을 내려받아 로컬과 LWW 병합.
  /// - 서버가 최신: 로컬 일정 갱신(없으면 최소 리튼 생성)
  /// - 로컬이 최신: 서버로 재업로드
  /// - tombstone: 로컬 일정 제거(로컬이 더 최신이면 삭제 취소 후 재업로드)
  Future<void> pullSchedules() async {
    if (!_canSync) {
      debugPrint('[ScheduleSyncService] pullSchedules - 미로그인, 스킵');
      return;
    }
    final token = await _loadToken();
    if (token == null) return;
    debugPrint('[ScheduleSyncService] pullSchedules 진입');

    try {
      final serverList = await _api.getSchedules(token: token);
      final localList = await _littenService.getAllLittens();
      final localById = {for (final l in localList) l.id: l};
      var changed = false;

      for (final s in serverList) {
        final littenId = s['littenId'] as String?;
        if (littenId == null) continue;
        final local = localById[littenId];

        // undefined(미분류) 리튼은 일정 동기화 대상 아님 — 로컬이 undefined면 건드리지 않는다
        if (local != null && local.title == 'undefined') continue;

        // ── 삭제 tombstone ──
        if (s['_deleted'] == true) {
          if (local?.schedule == null) continue; // 이미 일정 없음
          final deletedAt = DateTime.tryParse(s['deletedAt']?.toString() ?? '');
          if (deletedAt != null && _isNewer(local!.updatedAt, deletedAt)) {
            // 로컬이 더 최신 → 삭제 취소(재업로드)
            debugPrint('[ScheduleSyncService] 일정 삭제 취소(수정 우선) - littenId: $littenId');
            await pushSchedule(local);
          } else {
            // 삭제 전파 → 로컬 일정 제거(리튼은 보존)
            debugPrint('[ScheduleSyncService] 일정 삭제 전파 - littenId: $littenId');
            await _littenService.saveLitten(
                _rebuild(local!, schedule: null, updatedAt: deletedAt ?? DateTime.now()));
            changed = true;
          }
          continue;
        }

        // ── 정상 일정 ──
        final serverUpdatedAt = DateTime.tryParse(s['updatedAt']?.toString() ?? '');
        final scheduleJson = s['schedule'];
        if (serverUpdatedAt == null || scheduleJson is! Map) continue;

        final schedule = LittenSchedule.fromJson(Map<String, dynamic>.from(scheduleJson));
        final title = s['title'] as String? ?? '일정';
        if (title == 'undefined') continue; // 서버에 undefined 일정이 있어도 로컬 생성/반영 안 함
        final notificationCount = (s['notificationCount'] as num?)?.toInt() ?? 0;

        if (local == null) {
          // 로컬에 리튼 없음 → 표시용 title로 최소 리튼 생성
          debugPrint('[ScheduleSyncService] 일정용 리튼 신규 생성 - littenId: $littenId, title: $title');
          await _littenService.saveLitten(Litten(
            id: littenId,
            title: title,
            schedule: schedule,
            createdAt: serverUpdatedAt,
            updatedAt: serverUpdatedAt, // 서버 시각 보존(재업로드 핑퐁 방지)
            notificationCount: notificationCount,
          ));
          changed = true;
        } else if (_isNewer(serverUpdatedAt, local.updatedAt)) {
          // 서버가 더 최신 → 로컬 일정 갱신 (updatedAt을 서버에 맞춰 핑퐁 방지)
          debugPrint('[ScheduleSyncService] 서버 일정으로 갱신 - littenId: $littenId');
          await _littenService.saveLitten(_rebuild(local,
              schedule: schedule, title: title,
              notificationCount: notificationCount, updatedAt: serverUpdatedAt));
          changed = true;
        } else if (_isNewer(local.updatedAt, serverUpdatedAt)) {
          // 로컬이 더 최신 → 서버로 업로드
          await pushSchedule(local);
        }
      }

      if (changed) _onChanged?.call();
      debugPrint('[ScheduleSyncService] pullSchedules 완료 - 서버 ${serverList.length}개, changed=$changed');
    } catch (e) {
      debugPrint('[ScheduleSyncService] pullSchedules 오류: $e');
    }
  }

  /// 리튼의 일정/제목/알림수만 바꾼 새 Litten 생성.
  /// copyWith는 updatedAt을 now()로 강제하고 schedule=null을 지정할 수 없어,
  /// 서버 동기화(updatedAt 보존 + 일정 제거)에는 직접 재구성한다.
  Litten _rebuild(Litten l,
      {required LittenSchedule? schedule,
      String? title,
      int? notificationCount,
      required DateTime updatedAt}) {
    return Litten(
      id: l.id,
      title: title ?? l.title,
      description: l.description,
      createdAt: l.createdAt,
      updatedAt: updatedAt,
      audioFileIds: l.audioFileIds,
      textFileIds: l.textFileIds,
      handwritingFileIds: l.handwritingFileIds,
      attachmentFileIds: l.attachmentFileIds,
      schedule: schedule,
      notificationCount: notificationCount ?? l.notificationCount,
    );
  }
}
