import 'package:flutter/foundation.dart';

enum SubscriptionType {
  free('free', '무료', '기본 기능만 사용 가능'),
  standard('standard', '스탠다드', '광고 제거 + 무제한 파일'),
  premium('premium', '프리미엄', '모든 기능 + 클라우드 동기화');

  const SubscriptionType(this.id, this.displayName, this.description);
  
  final String id;
  final String displayName;
  final String description;
}

class SubscriptionPlan {
  final SubscriptionType type;
  final String productId;
  final String title;
  final String description;
  final List<String> features;
  final String price;
  final String period;
  final bool isPopular;
  
  const SubscriptionPlan({
    required this.type,
    required this.productId,
    required this.title,
    required this.description,
    required this.features,
    required this.price,
    required this.period,
    this.isPopular = false,
  });

  static const List<SubscriptionPlan> availablePlans = [
    SubscriptionPlan(
      type: SubscriptionType.free,
      productId: 'litten_free',
      title: '무료 플랜',
      description: '기본 기능을 체험해보세요',
      features: [
        '리튼 생성 최대 5개',
        '각 리튼 내 오디오 파일 최대 2개',
        '각 리튼 내 텍스트 파일 최대 1개',
        '각 리튼 내 필기 파일 최대 1개',
        '로컬 저장만 가능',
        '광고 표시',
      ],
      price: '무료',
      period: '',
    ),
    SubscriptionPlan(
      type: SubscriptionType.standard,
      productId: 'litten_standard_monthly',
      title: '스탠다드 플랜',
      description: '더 많은 파일과 광고 없는 환경',
      features: [
        '무제한 리튼 생성',
        '무제한 오디오/텍스트/필기 파일',
        '광고 완전 제거',
        '로컬 저장',
        '우선 고객 지원',
      ],
      price: '₩4,900',
      period: '월',
      isPopular: true,
    ),
    SubscriptionPlan(
      type: SubscriptionType.premium,
      productId: 'litten_premium_monthly',
      title: '프리미엄 플랜',
      description: '모든 기능과 클라우드 동기화',
      features: [
        '스탠다드 플랜의 모든 기능',
        '클라우드 동기화',
        '웹에서 편집 가능',
        '다중 기기 접근',
        '고급 내보내기 옵션',
        '팀 협업 기능',
        'API 접근',
      ],
      price: '₩9,900',
      period: '월',
    ),
  ];

  static SubscriptionPlan getPlanByType(SubscriptionType type) {
    return availablePlans.firstWhere(
      (plan) => plan.type == type,
      orElse: () => availablePlans.first,
    );
  }
}

class UserSubscription {
  final String id;
  final SubscriptionType type;
  final String productId;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final bool autoRenew;
  final Map<String, dynamic> metadata;

  const UserSubscription({
    required this.id,
    required this.type,
    required this.productId,
    required this.startDate,
    this.endDate,
    required this.isActive,
    required this.autoRenew,
    this.metadata = const {},
  });

  // JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.id,
      'productId': productId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive,
      'autoRenew': autoRenew,
      'metadata': metadata,
    };
  }

  // JSON 역직렬화
  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: json['id'],
      type: SubscriptionType.values.firstWhere(
        (type) => type.id == json['type'],
        orElse: () => SubscriptionType.free,
      ),
      productId: json['productId'],
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      isActive: json['isActive'] ?? false,
      autoRenew: json['autoRenew'] ?? false,
      metadata: json['metadata'] ?? {},
    );
  }

  // 구독이 만료되었는지 확인
  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  // 구독이 유효한지 확인
  bool get isValid {
    return isActive && !isExpired;
  }

  // 남은 일수 계산
  int? get daysRemaining {
    if (endDate == null) return null;
    final remaining = endDate!.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  UserSubscription copyWith({
    String? id,
    SubscriptionType? type,
    String? productId,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    bool? autoRenew,
    Map<String, dynamic>? metadata,
  }) {
    return UserSubscription(
      id: id ?? this.id,
      type: type ?? this.type,
      productId: productId ?? this.productId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      autoRenew: autoRenew ?? this.autoRenew,
      metadata: metadata ?? this.metadata,
    );
  }
}