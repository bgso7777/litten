import 'litten.dart';

/// 저장된 알림 데이터 모델
/// SharedPreferences에 JSON 형태로 저장되어 앱 재시작, 백그라운드, 배터리 절약 모드에서도 유지됩니다.
class StoredNotification {
  /// 알림 고유 ID (리튼 ID + 트리거 시간으로 생성)
  final String id;

  /// 알림이 속한 리튼 ID
  final String littenId;

  /// 알림이 발생할 시간
  final DateTime triggerTime;

  /// 알림 규칙 (빈도, 타이밍 등)
  final NotificationRule rule;

  /// 반복 알림 여부
  final bool isRepeating;

  /// 사용자가 알림을 확인했는지 여부
  final bool isAcknowledged;

  /// 알림 생성 시간
  final DateTime createdAt;

  StoredNotification({
    required this.id,
    required this.littenId,
    required this.triggerTime,
    required this.rule,
    required this.isRepeating,
    this.isAcknowledged = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// JSON으로 직렬화
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'littenId': littenId,
      'triggerTime': triggerTime.toIso8601String(),
      'rule': rule.toJson(),
      'isRepeating': isRepeating,
      'isAcknowledged': isAcknowledged,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// JSON에서 역직렬화
  factory StoredNotification.fromJson(Map<String, dynamic> json) {
    return StoredNotification(
      id: json['id'] as String,
      littenId: json['littenId'] as String,
      triggerTime: DateTime.parse(json['triggerTime'] as String),
      rule: NotificationRule.fromJson(json['rule'] as Map<String, dynamic>),
      isRepeating: json['isRepeating'] as bool,
      isAcknowledged: json['isAcknowledged'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  /// 알림 확인 처리
  StoredNotification markAsAcknowledged() {
    return StoredNotification(
      id: id,
      littenId: littenId,
      triggerTime: triggerTime,
      rule: rule,
      isRepeating: isRepeating,
      isAcknowledged: true,
      createdAt: createdAt,
    );
  }

  /// 알림 ID 생성 헬퍼 메소드
  /// 리튼 ID와 트리거 시간을 조합하여 고유 ID 생성
  static String generateId(String littenId, DateTime triggerTime) {
    return '${littenId}_${triggerTime.millisecondsSinceEpoch}';
  }

  /// 디버깅용 문자열 출력
  @override
  String toString() {
    return 'StoredNotification(id: $id, littenId: $littenId, triggerTime: $triggerTime, '
        'isRepeating: $isRepeating, isAcknowledged: $isAcknowledged, '
        'frequency: ${rule.frequency.label}, timing: ${rule.timing.label})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoredNotification && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
