import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stored_notification.dart';

/// 알림 영구 저장 서비스
/// SharedPreferences를 사용하여 알림을 저장/로드합니다.
class NotificationStorageService {
  static const String _storageKey = 'stored_notifications';

  /// 모든 저장된 알림 로드
  Future<List<StoredNotification>> loadNotifications() async {
    try {
      debugPrint('📂 NotificationStorageService.loadNotifications() 진입');
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        debugPrint('   ℹ️ 저장된 알림 없음');
        return [];
      }

      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      final notifications = jsonList
          .map((json) => StoredNotification.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('   ✅ ${notifications.length}개 알림 로드 완료');
      return notifications;
    } catch (e) {
      debugPrint('   ❌ 알림 로드 실패: $e');
      return [];
    }
  }

  /// 모든 알림 저장
  Future<bool> saveNotifications(List<StoredNotification> notifications) async {
    try {
      debugPrint('💾 NotificationStorageService.saveNotifications() 진입: ${notifications.length}개');
      final prefs = await SharedPreferences.getInstance();
      final jsonList = notifications.map((n) => n.toJson()).toList();
      final jsonString = json.encode(jsonList);

      final success = await prefs.setString(_storageKey, jsonString);

      if (success) {
        debugPrint('   ✅ 알림 저장 완료');
      } else {
        debugPrint('   ❌ 알림 저장 실패');
      }

      return success;
    } catch (e) {
      debugPrint('   ❌ 알림 저장 에러: $e');
      return false;
    }
  }

  /// 특정 리튼의 알림만 로드
  Future<List<StoredNotification>> loadNotificationsByLittenId(String littenId) async {
    try {
      debugPrint('📂 NotificationStorageService.loadNotificationsByLittenId() 진입: littenId=$littenId');
      final allNotifications = await loadNotifications();
      final filtered = allNotifications
          .where((n) => n.littenId == littenId)
          .toList();

      debugPrint('   ✅ ${filtered.length}개 알림 찾음');
      return filtered;
    } catch (e) {
      debugPrint('   ❌ 리튼별 알림 로드 실패: $e');
      return [];
    }
  }

  /// 특정 리튼의 모든 알림 삭제
  Future<bool> deleteNotificationsByLittenId(String littenId) async {
    try {
      debugPrint('🗑️ NotificationStorageService.deleteNotificationsByLittenId() 진입: littenId=$littenId');
      final allNotifications = await loadNotifications();
      final remainingNotifications = allNotifications
          .where((n) => n.littenId != littenId)
          .toList();

      final deletedCount = allNotifications.length - remainingNotifications.length;
      debugPrint('   ℹ️ ${deletedCount}개 알림 삭제됨');

      return await saveNotifications(remainingNotifications);
    } catch (e) {
      debugPrint('   ❌ 알림 삭제 실패: $e');
      return false;
    }
  }

  /// 특정 알림 삭제 (ID 기준)
  Future<bool> deleteNotification(String notificationId) async {
    try {
      debugPrint('🗑️ NotificationStorageService.deleteNotification() 진입: notificationId=$notificationId');
      final allNotifications = await loadNotifications();
      final remainingNotifications = allNotifications
          .where((n) => n.id != notificationId)
          .toList();

      if (allNotifications.length == remainingNotifications.length) {
        debugPrint('   ⚠️ 삭제할 알림을 찾을 수 없음');
        return false;
      }

      debugPrint('   ✅ 알림 삭제 완료');
      return await saveNotifications(remainingNotifications);
    } catch (e) {
      debugPrint('   ❌ 알림 삭제 실패: $e');
      return false;
    }
  }

  /// 여러 알림 추가
  Future<bool> addNotifications(List<StoredNotification> newNotifications) async {
    try {
      debugPrint('➕ NotificationStorageService.addNotifications() 진입: ${newNotifications.length}개');
      final allNotifications = await loadNotifications();

      // 중복 제거하며 추가
      int addedCount = 0;
      for (final notification in newNotifications) {
        if (!allNotifications.any((n) => n.id == notification.id)) {
          allNotifications.add(notification);
          addedCount++;
        }
      }

      final duplicateCount = newNotifications.length - addedCount;
      debugPrint('   ℹ️ $addedCount개 알림 추가됨 (중복 $duplicateCount개 제외)');
      return await saveNotifications(allNotifications);
    } catch (e) {
      debugPrint('   ❌ 알림 추가 실패: $e');
      return false;
    }
  }

  /// 알림 확인 처리 후 삭제
  Future<bool> acknowledgeAndDeleteNotification(String notificationId) async {
    try {
      debugPrint('✓ NotificationStorageService.acknowledgeAndDeleteNotification() 진입: notificationId=$notificationId');
      return await deleteNotification(notificationId);
    } catch (e) {
      debugPrint('   ❌ 알림 확인/삭제 실패: $e');
      return false;
    }
  }

  /// 지난 알림 조회 (놓친 알림 체크용)
  /// 모든 미확인 알림 조회 (시간 관계없이)
  Future<List<StoredNotification>> getAllUnacknowledgedNotifications() async {
    try {
      debugPrint('📋 NotificationStorageService.getAllUnacknowledgedNotifications() 진입');
      final allNotifications = await loadNotifications();
      final unacknowledged = allNotifications
          .where((n) => !n.isAcknowledged)
          .toList();

      final count = unacknowledged.length;
      debugPrint('   ✅ $count개 미확인 알림');
      return unacknowledged;
    } catch (e) {
      debugPrint('   ❌ 미확인 알림 조회 실패: $e');
      return [];
    }
  }

  Future<List<StoredNotification>> getPastUnacknowledgedNotifications(DateTime now) async {
    try {
      debugPrint('⏰ NotificationStorageService.getPastUnacknowledgedNotifications() 진입: now=$now');
      final allNotifications = await loadNotifications();
      final pastNotifications = allNotifications
          .where((n) =>
              n.triggerTime.isBefore(now) &&
              !n.isAcknowledged
          )
          .toList();

      final count = pastNotifications.length;
      debugPrint('   ✅ $count개 지난 미확인 알림');
      return pastNotifications;
    } catch (e) {
      debugPrint('   ❌ 지난 알림 조회 실패: $e');
      return [];
    }
  }

  /// 미래 알림 조회
  Future<List<StoredNotification>> getFutureNotifications(DateTime now) async {
    try {
      debugPrint('🔮 NotificationStorageService.getFutureNotifications() 진입: now=$now');
      final allNotifications = await loadNotifications();
      final futureNotifications = allNotifications
          .where((n) => n.triggerTime.isAfter(now))
          .toList();

      debugPrint('   ✅ ${futureNotifications.length}개 미래 알림');
      return futureNotifications;
    } catch (e) {
      debugPrint('   ❌ 미래 알림 조회 실패: $e');
      return [];
    }
  }

  /// 모든 알림 삭제
  Future<bool> clearAllNotifications() async {
    try {
      debugPrint('🗑️ NotificationStorageService.clearAllNotifications() 진입');
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.remove(_storageKey);

      if (success) {
        debugPrint('   ✅ 모든 알림 삭제 완료');
      } else {
        debugPrint('   ❌ 알림 삭제 실패');
      }

      return success;
    } catch (e) {
      debugPrint('   ❌ 알림 삭제 에러: $e');
      return false;
    }
  }

  /// 통계 정보 조회
  Future<Map<String, int>> getStatistics() async {
    try {
      debugPrint('📊 NotificationStorageService.getStatistics() 진입');
      final allNotifications = await loadNotifications();
      final now = DateTime.now();

      final stats = {
        'total': allNotifications.length,
        'acknowledged': allNotifications.where((n) => n.isAcknowledged).length,
        'unacknowledged': allNotifications.where((n) => !n.isAcknowledged).length,
        'past': allNotifications.where((n) => n.triggerTime.isBefore(now)).length,
        'future': allNotifications.where((n) => n.triggerTime.isAfter(now)).length,
        'repeating': allNotifications.where((n) => n.isRepeating).length,
        'oneTime': allNotifications.where((n) => !n.isRepeating).length,
      };

      debugPrint('   ✅ 통계: $stats');
      return stats;
    } catch (e) {
      debugPrint('   ❌ 통계 정보 조회 실패: $e');
      return {};
    }
  }
}
