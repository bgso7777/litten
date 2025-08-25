import 'package:uuid/uuid.dart';

/// 사용자 설정 모델
class UserSettings {
  final String userId;
  final String language;
  final String theme;
  final int maxRecordingDuration; // 초 단위
  final int autoSaveInterval; // 초 단위
  final SubscriptionTier subscriptionTier;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> preferences;
  
  UserSettings({
    String? userId,
    this.language = 'en',
    this.theme = 'classicBlue',
    this.maxRecordingDuration = 3600, // 1시간
    this.autoSaveInterval = 60, // 1분
    this.subscriptionTier = SubscriptionTier.free,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? preferences,
  })  : userId = userId ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        preferences = preferences ?? {};
  
  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'language': language,
      'theme': theme,
      'maxRecordingDuration': maxRecordingDuration,
      'autoSaveInterval': autoSaveInterval,
      'subscriptionTier': subscriptionTier.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'preferences': preferences,
    };
  }
  
  /// JSON에서 생성
  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      userId: json['userId'],
      language: json['language'] ?? 'en',
      theme: json['theme'] ?? 'classicBlue',
      maxRecordingDuration: json['maxRecordingDuration'] ?? 3600,
      autoSaveInterval: json['autoSaveInterval'] ?? 60,
      subscriptionTier: SubscriptionTier.values.firstWhere(
        (tier) => tier.name == json['subscriptionTier'],
        orElse: () => SubscriptionTier.free,
      ),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
      preferences: Map<String, dynamic>.from(json['preferences'] ?? {}),
    );
  }
  
  /// 복사본 생성
  UserSettings copyWith({
    String? language,
    String? theme,
    int? maxRecordingDuration,
    int? autoSaveInterval,
    SubscriptionTier? subscriptionTier,
    DateTime? updatedAt,
    Map<String, dynamic>? preferences,
  }) {
    return UserSettings(
      userId: userId,
      language: language ?? this.language,
      theme: theme ?? this.theme,
      maxRecordingDuration: maxRecordingDuration ?? this.maxRecordingDuration,
      autoSaveInterval: autoSaveInterval ?? this.autoSaveInterval,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      preferences: preferences ?? this.preferences,
    );
  }
  
  /// 설정값 추가/업데이트
  UserSettings setPreference(String key, dynamic value) {
    final newPreferences = Map<String, dynamic>.from(preferences);
    newPreferences[key] = value;
    
    return copyWith(preferences: newPreferences);
  }
  
  /// 설정값 가져오기
  T? getPreference<T>(String key, [T? defaultValue]) {
    return preferences[key] as T? ?? defaultValue;
  }
  
  /// 포맷된 녹음 시간 제한
  String get formattedMaxRecordingDuration {
    final hours = maxRecordingDuration ~/ 3600;
    final minutes = (maxRecordingDuration % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}시간 ${minutes}분';
    } else {
      return '${minutes}분';
    }
  }
  
  /// 포맷된 자동저장 간격
  String get formattedAutoSaveInterval {
    if (autoSaveInterval >= 60) {
      final minutes = autoSaveInterval ~/ 60;
      return '${minutes}분';
    } else {
      return '${autoSaveInterval}초';
    }
  }
  
  /// 프리미엄 여부
  bool get isPremium => subscriptionTier != SubscriptionTier.free;
  
  /// 스탠다드 이상 여부
  bool get isStandardOrHigher => subscriptionTier.index >= SubscriptionTier.standard.index;
  
  /// 광고 표시 여부
  bool get shouldShowAds => subscriptionTier == SubscriptionTier.free;
  
  /// 클라우드 동기화 가능 여부
  bool get hasCloudSync => subscriptionTier == SubscriptionTier.premium;
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserSettings && other.userId == userId;
  }
  
  @override
  int get hashCode => userId.hashCode;
  
  @override
  String toString() {
    return 'UserSettings(userId: $userId, language: $language, theme: $theme, tier: ${subscriptionTier.name})';
  }
}

/// 구독 등급
enum SubscriptionTier {
  free,     // 무료
  standard, // 스탠다드
  premium,  // 프리미엄
}

/// 구독 등급 확장 메서드
extension SubscriptionTierExtension on SubscriptionTier {
  /// 한국어 이름
  String get koreanName {
    switch (this) {
      case SubscriptionTier.free:
        return '무료';
      case SubscriptionTier.standard:
        return '스탠다드';
      case SubscriptionTier.premium:
        return '프리미엄';
    }
  }
  
  /// 리튼 생성 제한
  int get maxLittens {
    switch (this) {
      case SubscriptionTier.free:
        return 5;
      case SubscriptionTier.standard:
      case SubscriptionTier.premium:
        return -1; // 무제한
    }
  }
  
  /// 오디오 파일 제한
  int get maxAudioFiles {
    switch (this) {
      case SubscriptionTier.free:
        return 10;
      case SubscriptionTier.standard:
      case SubscriptionTier.premium:
        return -1; // 무제한
    }
  }
  
  /// 텍스트 파일 제한
  int get maxTextFiles {
    switch (this) {
      case SubscriptionTier.free:
        return 5;
      case SubscriptionTier.standard:
      case SubscriptionTier.premium:
        return -1; // 무제한
    }
  }
  
  /// 드로잉 파일 제한
  int get maxDrawingFiles {
    switch (this) {
      case SubscriptionTier.free:
        return 5;
      case SubscriptionTier.standard:
      case SubscriptionTier.premium:
        return -1; // 무제한
    }
  }
  
  /// 월 가격 (달러)
  double? get monthlyPrice {
    switch (this) {
      case SubscriptionTier.free:
        return null;
      case SubscriptionTier.standard:
        return 4.99;
      case SubscriptionTier.premium:
        return 9.99;
    }
  }
}