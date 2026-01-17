import 'package:flutter/foundation.dart';
import '../models/litten.dart';
import '../models/stored_notification.dart';
import 'notification_storage_service.dart';
import 'notification_generator_service.dart';

/// 알림 오케스트레이터 서비스
/// 저장소와 생성기를 조율하여 알림 생성, 수정, 삭제, 조회를 관리합니다.
class NotificationOrchestratorService {
  final NotificationStorageService _storage = NotificationStorageService();
  final NotificationGeneratorService _generator = NotificationGeneratorService();

  /// 리튼의 알림 스케줄링
  /// 1. 기존 미확인 알림 확인 및 유지
  /// 2. 확인된 알림만 삭제
  /// 3. 새로운 알림 생성 (1회성: 1개, 반복: 1년치)
  /// 4. 중복 제거 후 저장소에 저장
  Future<bool> scheduleNotificationsForLitten(Litten litten) async {
    try {
      debugPrint('🔔 NotificationOrchestratorService.scheduleNotificationsForLitten() 진입: littenId=${litten.id}');

      // 1. 기존 미확인 알림 확인
      final existingNotifications = await _storage.loadNotificationsByLittenId(litten.id);
      final unacknowledgedNotifications = existingNotifications
          .where((n) => !n.isAcknowledged)
          .toList();

      if (unacknowledgedNotifications.isNotEmpty) {
        debugPrint('   ⚠️ ${unacknowledgedNotifications.length}개 미확인 알림 발견 - 유지');
        for (final n in unacknowledgedNotifications) {
          debugPrint('      - ${n.triggerTime}: ${n.isAcknowledged ? "확인됨" : "미확인"}');
        }
      }

      // 2. 확인된 알림만 삭제 (미확인 알림은 유지)
      final acknowledgedNotifications = existingNotifications
          .where((n) => n.isAcknowledged)
          .toList();

      if (acknowledgedNotifications.isNotEmpty) {
        debugPrint('   🗑️ ${acknowledgedNotifications.length}개 확인된 알림 삭제 중...');
        for (final n in acknowledgedNotifications) {
          await _storage.acknowledgeAndDeleteNotification(n.id);
        }
      }

      // 3. 새로운 알림 생성
      debugPrint('   🔄 새로운 알림 생성 중...');
      final newNotifications = _generator.generateNotificationsForLitten(litten);

      if (newNotifications.isEmpty) {
        debugPrint('   ⚠️ 생성된 알림 없음');
        return true; // 알림 없어도 성공으로 처리
      }

      // 4. 저장소에 저장 (미확인 알림과 중복되지 않도록)
      final notificationsToAdd = <StoredNotification>[];
      for (final newN in newNotifications) {
        // 이미 미확인 알림으로 존재하면 추가하지 않음
        final isDuplicate = unacknowledgedNotifications.any((existing) =>
            existing.triggerTime.isAtSameMomentAs(newN.triggerTime) &&
            existing.rule.frequency == newN.rule.frequency &&
            existing.rule.timing == newN.rule.timing);

        if (!isDuplicate) {
          notificationsToAdd.add(newN);
        }
      }

      if (notificationsToAdd.isNotEmpty) {
        debugPrint('   💾 ${notificationsToAdd.length}개 알림 저장 중...');
        final success = await _storage.addNotifications(notificationsToAdd);

        if (success) {
          debugPrint('   ✅ 알림 스케줄링 완료: ${notificationsToAdd.length}개 추가 (기존 미확인 ${unacknowledgedNotifications.length}개 유지)');
        } else {
          debugPrint('   ❌ 알림 저장 실패');
          return false;
        }
      } else {
        debugPrint('   ℹ️ 추가할 새 알림 없음 (기존 미확인 ${unacknowledgedNotifications.length}개만 유지)');
      }

      return true;
    } catch (e) {
      debugPrint('   ❌ 알림 스케줄링 에러: $e');
      return false;
    }
  }

  /// 여러 리튼의 알림 스케줄링
  Future<bool> scheduleNotificationsForLittens(List<Litten> littens) async {
    try {
      debugPrint('🔔 NotificationOrchestratorService.scheduleNotificationsForLittens() 진입: ${littens.length}개 리튼');

      int successCount = 0;
      int failCount = 0;

      for (final litten in littens) {
        final success = await scheduleNotificationsForLitten(litten);
        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      }

      debugPrint('   📊 스케줄링 결과: 성공 $successCount개, 실패 $failCount개');
      return failCount == 0;
    } catch (e) {
      debugPrint('   ❌ 다중 알림 스케줄링 에러: $e');
      return false;
    }
  }

  /// 타이머 재시작 시 반복 알림 1년치 유지 로직
  /// 현재 저장된 반복 알림을 확인하고, 1년치가 안 되면 추가 생성
  Future<void> maintainYearlyNotifications(List<Litten> littens) async {
    try {
      debugPrint('🔄 NotificationOrchestratorService.maintainYearlyNotifications() 진입');

      final now = DateTime.now();
      final oneYearLater = now.add(const Duration(days: 365));

      for (final litten in littens) {
        if (litten.schedule == null) continue;

        // 현재 저장된 이 리튼의 미래 알림 조회
        final existingNotifications = await _storage.loadNotificationsByLittenId(litten.id);
        final futureNotifications = existingNotifications
            .where((n) => n.triggerTime.isAfter(now))
            .toList();

        // 반복 알림만 필터
        final repeatingNotifications = futureNotifications
            .where((n) => n.isRepeating)
            .toList();

        if (repeatingNotifications.isEmpty) {
          debugPrint('   ℹ️ 리튼 "${litten.title}": 반복 알림 없음, 건너뛰기');
          continue;
        }

        // 가장 마지막 알림 시간 확인
        repeatingNotifications.sort((a, b) => a.triggerTime.compareTo(b.triggerTime));
        final lastNotification = repeatingNotifications.last;

        // 마지막 알림이 1년 이내면 추가 생성 필요 없음
        if (lastNotification.triggerTime.isAfter(oneYearLater) ||
            lastNotification.triggerTime.isAtSameMomentAs(oneYearLater)) {
          debugPrint('   ✅ 리튼 "${litten.title}": 1년치 알림 충분 (마지막: ${lastNotification.triggerTime})');
          continue;
        }

        // 1년치 미만이면 재생성
        debugPrint('   ⚠️ 리튼 "${litten.title}": 1년치 미만 (마지막: ${lastNotification.triggerTime}), 재생성 필요');
        await scheduleNotificationsForLitten(litten);
      }

      debugPrint('   ✅ 1년치 알림 유지 완료');
    } catch (e) {
      debugPrint('   ❌ 1년치 알림 유지 에러: $e');
    }
  }

  /// 놓친 알림 체크 및 반환
  /// 앱 재시작/백그라운드 복귀 시 호출
  /// ⭐ 과거의 미확인 알림만 반환 (이미 발생했지만 확인하지 않은 알림)
  Future<List<StoredNotification>> checkMissedNotifications() async {
    try {
      debugPrint('🔍 NotificationOrchestratorService.checkMissedNotifications() 진입');

      final now = DateTime.now();

      // 모든 미확인 알림 가져오기
      final allUnacknowledged = await _storage.getAllUnacknowledgedNotifications();

      // 과거 알림만 필터링 (triggerTime이 현재보다 이전이거나 같은 경우)
      final missedNotifications = allUnacknowledged
          .where((n) => n.triggerTime.isBefore(now) || n.triggerTime.isAtSameMomentAs(now))
          .toList();

      debugPrint('   📊 전체 미확인 알림: ${allUnacknowledged.length}개, 놓친 알림(과거): ${missedNotifications.length}개');

      // 시간 순으로 정렬
      missedNotifications.sort((a, b) => a.triggerTime.compareTo(b.triggerTime));

      for (final notification in missedNotifications) {
        debugPrint('      - ${notification.triggerTime}: 리튼 ${notification.littenId}');
      }

      return missedNotifications;
    } catch (e) {
      debugPrint('   ❌ 놓친 알림 체크 에러: $e');
      return [];
    }
  }

  /// 알림 확인 (사용자가 배지를 클릭했을 때)
  /// 확인된 알림은 저장소에서 삭제
  Future<bool> acknowledgeNotification(String notificationId) async {
    try {
      debugPrint('✓ NotificationOrchestratorService.acknowledgeNotification() 진입: notificationId=$notificationId');

      final success = await _storage.acknowledgeAndDeleteNotification(notificationId);

      if (success) {
        debugPrint('   ✅ 알림 확인 및 삭제 완료');
      } else {
        debugPrint('   ❌ 알림 확인/삭제 실패');
      }

      return success;
    } catch (e) {
      debugPrint('   ❌ 알림 확인 에러: $e');
      return false;
    }
  }

  /// 리튼 삭제 시 관련 알림 모두 삭제
  Future<bool> deleteNotificationsForLitten(String littenId) async {
    try {
      debugPrint('🗑️ NotificationOrchestratorService.deleteNotificationsForLitten() 진입: littenId=$littenId');

      return await _storage.deleteNotificationsByLittenId(littenId);
    } catch (e) {
      debugPrint('   ❌ 알림 삭제 에러: $e');
      return false;
    }
  }

  /// 모든 알림 삭제
  Future<bool> clearAllNotifications() async {
    try {
      debugPrint('🗑️ NotificationOrchestratorService.clearAllNotifications() 진입');

      return await _storage.clearAllNotifications();
    } catch (e) {
      debugPrint('   ❌ 모든 알림 삭제 에러: $e');
      return false;
    }
  }

  /// 통계 조회
  Future<Map<String, int>> getStatistics() async {
    try {
      return await _storage.getStatistics();
    } catch (e) {
      debugPrint('❌ 통계 조회 에러: $e');
      return {};
    }
  }

  /// 특정 리튼의 알림 조회
  Future<List<StoredNotification>> getNotificationsForLitten(String littenId) async {
    try {
      return await _storage.loadNotificationsByLittenId(littenId);
    } catch (e) {
      debugPrint('❌ 리튼별 알림 조회 에러: $e');
      return [];
    }
  }

  /// 모든 알림 조회
  Future<List<StoredNotification>> getAllNotifications() async {
    try {
      return await _storage.loadNotifications();
    } catch (e) {
      debugPrint('❌ 전체 알림 조회 에러: $e');
      return [];
    }
  }
}
