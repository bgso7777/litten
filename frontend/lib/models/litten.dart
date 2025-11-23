import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum NotificationTiming {
  twoHoursBefore('2시간전', -120),
  oneHourBefore('1시간전', -60),
  thirtyMinutesBefore('30분전', -30),
  tenMinutesBefore('10분전', -10),
  onTime('정시', 0);

  const NotificationTiming(this.label, this.minutesOffset);
  final String label;
  final int minutesOffset;
}

enum NotificationFrequency {
  onDay('당일', 'on_day'),
  oneDayBefore('1일전', 'one_day_before'),
  daily('매일', 'daily'),
  weekly('매주', 'weekly'),
  monthly('매월', 'monthly'),
  yearly('매년', 'yearly');

  const NotificationFrequency(this.label, this.value);
  final String label;
  final String value;
}

class NotificationRule {
  final NotificationFrequency frequency;
  final NotificationTiming timing;
  final bool isEnabled;
  final List<int>? weekdays; // 주별 알림용 요일 (1=월요일, 7=일요일), null이면 모든 요일

  NotificationRule({
    required this.frequency,
    required this.timing,
    this.isEnabled = false,
    this.weekdays,
  });

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency.value,
      'timing': timing.minutesOffset,
      'isEnabled': isEnabled,
      'weekdays': weekdays,
    };
  }

  factory NotificationRule.fromJson(Map<String, dynamic> json) {
    return NotificationRule(
      frequency: NotificationFrequency.values.firstWhere(
        (f) => f.value == json['frequency'],
        orElse: () => NotificationFrequency.onDay,
      ),
      timing: NotificationTiming.values.firstWhere(
        (t) => t.minutesOffset == json['timing'],
        orElse: () => NotificationTiming.onTime,
      ),
      isEnabled: json['isEnabled'] ?? false,
      weekdays: json['weekdays'] != null
          ? List<int>.from(json['weekdays'])
          : null,
    );
  }

  NotificationRule copyWith({
    NotificationFrequency? frequency,
    NotificationTiming? timing,
    bool? isEnabled,
    List<int>? weekdays,
  }) {
    return NotificationRule(
      frequency: frequency ?? this.frequency,
      timing: timing ?? this.timing,
      isEnabled: isEnabled ?? this.isEnabled,
      weekdays: weekdays ?? this.weekdays,
    );
  }
}

class LittenSchedule {
  final DateTime date; // 시작 날짜
  final DateTime? endDate; // 종료 날짜 (null이면 시작 날짜만 사용)
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String? notes;
  final List<NotificationRule> notificationRules;
  final TimeOfDay? notificationStartTime; // 알림 시작 시간 (from)
  final TimeOfDay? notificationEndTime;   // 알림 종료 시간 (to), null이면 제한 없음

  LittenSchedule({
    required this.date,
    this.endDate,
    required this.startTime,
    required this.endTime,
    this.notes,
    List<NotificationRule>? notificationRules,
    this.notificationStartTime,
    this.notificationEndTime,
  }) : notificationRules = notificationRules ?? [];

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'startTime': '${startTime.hour}:${startTime.minute}',
      'endTime': '${endTime.hour}:${endTime.minute}',
      'notes': notes,
      'notificationRules': notificationRules.map((rule) => rule.toJson()).toList(),
      'notificationStartTime': notificationStartTime != null
          ? '${notificationStartTime!.hour}:${notificationStartTime!.minute}'
          : null,
      'notificationEndTime': notificationEndTime != null
          ? '${notificationEndTime!.hour}:${notificationEndTime!.minute}'
          : null,
    };
  }

  factory LittenSchedule.fromJson(Map<String, dynamic> json) {
    final startTimeParts = json['startTime'].split(':');
    final endTimeParts = json['endTime'].split(':');

    TimeOfDay? notificationStartTime;
    if (json['notificationStartTime'] != null) {
      final parts = json['notificationStartTime'].split(':');
      notificationStartTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    TimeOfDay? notificationEndTime;
    if (json['notificationEndTime'] != null) {
      final parts = json['notificationEndTime'].split(':');
      notificationEndTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    return LittenSchedule(
      date: DateTime.parse(json['date']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      startTime: TimeOfDay(
        hour: int.parse(startTimeParts[0]),
        minute: int.parse(startTimeParts[1]),
      ),
      endTime: TimeOfDay(
        hour: int.parse(endTimeParts[0]),
        minute: int.parse(endTimeParts[1]),
      ),
      notes: json['notes'],
      notificationRules: (json['notificationRules'] as List<dynamic>?)
          ?.map((rule) => NotificationRule.fromJson(rule))
          .toList() ?? [],
      notificationStartTime: notificationStartTime,
      notificationEndTime: notificationEndTime,
    );
  }

  Duration get duration {
    final start = DateTime(2000, 1, 1, startTime.hour, startTime.minute);
    final end = DateTime(2000, 1, 1, endTime.hour, endTime.minute);
    return end.difference(start);
  }

  LittenSchedule copyWith({
    DateTime? date,
    DateTime? endDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? notes,
    List<NotificationRule>? notificationRules,
    TimeOfDay? notificationStartTime,
    TimeOfDay? notificationEndTime,
  }) {
    return LittenSchedule(
      date: date ?? this.date,
      endDate: endDate ?? this.endDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notes: notes ?? this.notes,
      notificationRules: notificationRules ?? this.notificationRules,
      notificationStartTime: notificationStartTime ?? this.notificationStartTime,
      notificationEndTime: notificationEndTime ?? this.notificationEndTime,
    );
  }
}

class Litten {
  final String id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> audioFileIds;
  final List<String> textFileIds;
  final List<String> handwritingFileIds;
  final LittenSchedule? schedule;
  final int notificationCount; // 알림 발생 횟수 카운트

  Litten({
    String? id,
    required this.title,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? audioFileIds,
    List<String>? textFileIds,
    List<String>? handwritingFileIds,
    this.schedule,
    this.notificationCount = 0,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        audioFileIds = audioFileIds ?? [],
        textFileIds = textFileIds ?? [],
        handwritingFileIds = handwritingFileIds ?? [];

  int get totalFileCount => audioFileIds.length + textFileIds.length + handwritingFileIds.length;
  int get audioCount => audioFileIds.length;
  int get textCount => textFileIds.length;
  int get handwritingCount => handwritingFileIds.length;

  Litten copyWith({
    String? title,
    String? description,
    List<String>? audioFileIds,
    List<String>? textFileIds,
    List<String>? handwritingFileIds,
    LittenSchedule? schedule,
    int? notificationCount,
  }) {
    return Litten(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      audioFileIds: audioFileIds ?? this.audioFileIds,
      textFileIds: textFileIds ?? this.textFileIds,
      handwritingFileIds: handwritingFileIds ?? this.handwritingFileIds,
      schedule: schedule ?? this.schedule,
      notificationCount: notificationCount ?? this.notificationCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'audioFileIds': audioFileIds,
      'textFileIds': textFileIds,
      'handwritingFileIds': handwritingFileIds,
      'schedule': schedule?.toJson(),
      'notificationCount': notificationCount,
    };
  }

  factory Litten.fromJson(Map<String, dynamic> json) {
    return Litten(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      audioFileIds: List<String>.from(json['audioFileIds'] ?? []),
      textFileIds: List<String>.from(json['textFileIds'] ?? []),
      handwritingFileIds: List<String>.from(json['handwritingFileIds'] ?? []),
      schedule: json['schedule'] != null ? LittenSchedule.fromJson(json['schedule']) : null,
      notificationCount: json['notificationCount'] ?? 0,
    );
  }
}