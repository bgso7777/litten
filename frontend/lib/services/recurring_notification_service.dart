import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/litten.dart';
import 'dart:convert';

class RecurringNotificationService {
  static final RecurringNotificationService _instance = RecurringNotificationService._internal();
  factory RecurringNotificationService() => _instance;
  RecurringNotificationService._internal();

  // Child 리튼 생성 및 관리
  Future<List<Litten>> generateChildLittensForRecurring({
    required List<Litten> parentLittens,
    required DateTime targetDate,
  }) async {
    debugPrint('🔄 반복 알림용 Child 리튼 생성 시작');
    List<Litten> childLittens = [];

    for (final parent in parentLittens) {
      // Parent 리튼이 아니거나 스케줄이 없으면 스킵
      if (parent.isChildLitten || parent.schedule == null) continue;

      // 반복 알림 규칙 확인
      final recurringRules = parent.schedule!.notificationRules.where((rule) =>
        rule.isEnabled && _isRecurringFrequency(rule.frequency)
      ).toList();

      if (recurringRules.isEmpty) continue;

      // 각 반복 규칙에 대해 해당 날짜에 child 리튼 생성이 필요한지 확인
      for (final rule in recurringRules) {
        if (_shouldCreateChildForDate(parent, rule, targetDate)) {
          final childLitten = await _createChildLitten(parent, targetDate, rule);
          if (childLitten != null) {
            childLittens.add(childLitten);
            debugPrint('✅ Child 리튼 생성: ${childLitten.title} (${rule.frequency.label})');
          }
        }
      }
    }

    // 생성된 child 리튼들을 저장
    if (childLittens.isNotEmpty) {
      await _saveChildLittens(childLittens);
      debugPrint('💾 ${childLittens.length}개의 Child 리튼 저장 완료');
    }

    return childLittens;
  }

  // 반복 빈도인지 확인
  bool _isRecurringFrequency(NotificationFrequency frequency) {
    return frequency == NotificationFrequency.daily ||
           frequency == NotificationFrequency.weekly ||
           frequency == NotificationFrequency.monthly ||
           frequency == NotificationFrequency.yearly;
  }

  // 특정 날짜에 child 리튼 생성이 필요한지 확인
  bool _shouldCreateChildForDate(Litten parent, NotificationRule rule, DateTime targetDate) {
    if (parent.schedule == null) return false;

    final scheduleDate = parent.schedule!.date;
    final today = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final scheduleDay = DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day);

    // 오늘이 스케줄 날짜 이후인지 확인
    if (today.isBefore(scheduleDay)) return false;

    switch (rule.frequency) {
      case NotificationFrequency.daily:
        // 매일: 항상 생성
        return true;

      case NotificationFrequency.weekly:
        // 매주: 같은 요일인지 확인
        return today.weekday == scheduleDay.weekday;

      case NotificationFrequency.monthly:
        // 매월: 같은 날짜인지 확인 (월말 처리 포함)
        final targetDay = scheduleDate.day;
        final lastDayOfMonth = DateTime(today.year, today.month + 1, 0).day;
        final adjustedDay = targetDay > lastDayOfMonth ? lastDayOfMonth : targetDay;
        return today.day == adjustedDay;

      case NotificationFrequency.yearly:
        // 매년: 같은 월/일인지 확인
        return today.month == scheduleDate.month && today.day == scheduleDate.day;

      default:
        return false;
    }
  }

  // Child 리튼 생성
  Future<Litten?> _createChildLitten(Litten parent, DateTime targetDate, NotificationRule rule) async {
    try {
      // 이미 같은 날짜에 생성된 child가 있는지 확인
      final existingChild = await _findExistingChild(parent.id, targetDate);
      if (existingChild != null) {
        debugPrint('⚠️ 이미 존재하는 Child 리튼: ${existingChild.title}');
        return null;
      }

      // Child 리튼용 스케줄 생성 (당일 알림만)
      final childSchedule = LittenSchedule(
        date: targetDate,
        startTime: parent.schedule!.startTime,
        endTime: parent.schedule!.endTime,
        notes: parent.schedule!.notes,
        notificationRules: [
          // 당일 알림만 추가 (부모와 같은 시간)
          NotificationRule(
            frequency: NotificationFrequency.onDay,
            timing: rule.timing,
            isEnabled: true,
          ),
        ],
      );

      // Child 리튼 생성
      final childLitten = Litten(
        title: '${parent.title} (${_getDateLabel(targetDate)})',
        description: '${parent.description ?? ""}\n[${rule.frequency.label} 반복 일정]',
        schedule: childSchedule,
        parentId: parent.id,
        isChildLitten: true,
      );

      return childLitten;
    } catch (e) {
      debugPrint('❌ Child 리튼 생성 실패: $e');
      return null;
    }
  }

  // 날짜 레이블 생성
  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(date.year, date.month, date.day);

    if (targetDay.isAtSameMomentAs(today)) {
      return '오늘';
    } else if (targetDay.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
      return '내일';
    } else {
      return '${date.month}/${date.day}';
    }
  }

  // 기존 Child 리튼 찾기
  Future<Litten?> _findExistingChild(String parentId, DateTime targetDate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final littensJson = prefs.getString('littens');
      if (littensJson == null) return null;

      final List<dynamic> littensData = jsonDecode(littensJson);
      final littens = littensData.map((data) => Litten.fromJson(data)).toList();

      // 같은 부모, 같은 날짜의 child 리튼 찾기
      return littens.firstWhere(
        (litten) {
          if (litten.parentId != parentId || !litten.isChildLitten) return false;
          if (litten.schedule == null) return false;

          final scheduleDate = litten.schedule!.date;
          return scheduleDate.year == targetDate.year &&
                 scheduleDate.month == targetDate.month &&
                 scheduleDate.day == targetDate.day;
        },
        orElse: () => Litten(id: '', title: '', isChildLitten: false),
      ).id.isEmpty ? null : littens.firstWhere(
        (litten) {
          if (litten.parentId != parentId || !litten.isChildLitten) return false;
          if (litten.schedule == null) return false;

          final scheduleDate = litten.schedule!.date;
          return scheduleDate.year == targetDate.year &&
                 scheduleDate.month == targetDate.month &&
                 scheduleDate.day == targetDate.day;
        },
      );
    } catch (e) {
      debugPrint('❌ 기존 Child 리튼 검색 실패: $e');
      return null;
    }
  }

  // Child 리튼들 저장
  Future<void> _saveChildLittens(List<Litten> childLittens) async {
    if (childLittens.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // 현재 선택된 리튼 ID 보존
      final currentSelectedLittenId = prefs.getString('selected_litten_id');

      // 기존 리튼들 로드
      final existingJson = prefs.getString('littens');
      List<Litten> allLittens = [];

      if (existingJson != null) {
        final List<dynamic> existingData = jsonDecode(existingJson);
        allLittens = existingData.map((data) => Litten.fromJson(data)).toList();
      }

      // 새로운 child 리튼들 추가
      allLittens.addAll(childLittens);

      // 저장
      final jsonData = jsonEncode(allLittens.map((l) => l.toJson()).toList());
      await prefs.setString('littens', jsonData);

      // 선택된 리튼 ID가 변경되지 않도록 보호
      if (currentSelectedLittenId != null) {
        await prefs.setString('selected_litten_id', currentSelectedLittenId);
      }

      debugPrint('💾 전체 리튼 ${allLittens.length}개 저장 완료 (선택된 리튼 유지)');
    } catch (e) {
      debugPrint('❌ Child 리튼 저장 실패: $e');
    }
  }

  // 오래된 Child 리튼 정리 (30일 이상 지난 것들)
  Future<void> cleanupOldChildLittens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final littensJson = prefs.getString('littens');
      if (littensJson == null) return;

      final List<dynamic> littensData = jsonDecode(littensJson);
      final littens = littensData.map((data) => Litten.fromJson(data)).toList();

      final now = DateTime.now();
      final cutoffDate = now.subtract(const Duration(days: 30));

      // Child 리튼 중 30일 이상 지난 것들 제거
      final filteredLittens = littens.where((litten) {
        if (!litten.isChildLitten) return true; // Parent는 유지
        if (litten.schedule == null) return true;

        return litten.schedule!.date.isAfter(cutoffDate);
      }).toList();

      if (filteredLittens.length < littens.length) {
        final removedCount = littens.length - filteredLittens.length;
        final jsonData = jsonEncode(filteredLittens.map((l) => l.toJson()).toList());
        await prefs.setString('littens', jsonData);
        debugPrint('🗑️ ${removedCount}개의 오래된 Child 리튼 정리 완료');
      }
    } catch (e) {
      debugPrint('❌ Child 리튼 정리 실패: $e');
    }
  }

  // Parent 리튼만 가져오기
  Future<List<Litten>> getParentLittens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final littensJson = prefs.getString('littens');
      if (littensJson == null) return [];

      final List<dynamic> littensData = jsonDecode(littensJson);
      final littens = littensData.map((data) => Litten.fromJson(data)).toList();

      // Parent 리튼만 필터링
      return littens.where((litten) => !litten.isChildLitten).toList();
    } catch (e) {
      debugPrint('❌ Parent 리튼 로드 실패: $e');
      return [];
    }
  }
}