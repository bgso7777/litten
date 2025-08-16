import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/subscription_model.dart';
import '../services/preferences_service.dart';

class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final Uuid _uuid = const Uuid();
  
  // 현재 구독 상태
  UserSubscription? _currentSubscription;
  bool _isLoading = false;

  // Getters
  UserSubscription? get currentSubscription => _currentSubscription;
  bool get isLoading => _isLoading;
  
  SubscriptionType get currentType => _currentSubscription?.type ?? SubscriptionType.free;
  bool get isFreePlan => currentType == SubscriptionType.free;
  bool get isStandardPlan => currentType == SubscriptionType.standard;
  bool get isPremiumPlan => currentType == SubscriptionType.premium;
  bool get hasValidSubscription => _currentSubscription?.isValid ?? false;

  // 초기화
  Future<void> initialize() async {
    await _loadSubscription();
  }

  // 저장된 구독 정보 로드
  Future<void> _loadSubscription() async {
    try {
      _isLoading = true;
      notifyListeners();

      final subscriptionJson = PreferencesService.getBool('subscription_data');
      if (subscriptionJson != null) {
        // 실제로는 String으로 저장되어야 하는데, 임시로 기본 무료 계정 생성
        _currentSubscription = _createFreeSubscription();
      } else {
        _currentSubscription = _createFreeSubscription();
      }

      // 구독 만료 확인
      if (_currentSubscription != null && _currentSubscription!.isExpired) {
        await _handleExpiredSubscription();
      }
    } catch (e) {
      debugPrint('구독 정보 로드 실패: $e');
      _currentSubscription = _createFreeSubscription();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 무료 구독 생성
  UserSubscription _createFreeSubscription() {
    return UserSubscription(
      id: _uuid.v4(),
      type: SubscriptionType.free,
      productId: 'litten_free',
      startDate: DateTime.now(),
      endDate: null, // 무료는 만료일 없음
      isActive: true,
      autoRenew: false,
      metadata: {
        'source': 'default',
        'createdAt': DateTime.now().toIso8601String(),
      },
    );
  }

  // 구독 구매 (시뮬레이션)
  Future<bool> purchaseSubscription(SubscriptionPlan plan) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 실제 구현에서는 여기서 플랫폼별 인앱 결제 처리
      // 현재는 시뮬레이션으로 3초 지연 후 성공
      await Future.delayed(const Duration(seconds: 3));

      // 구독 성공 시뮬레이션
      if (plan.type != SubscriptionType.free) {
        final newSubscription = UserSubscription(
          id: _uuid.v4(),
          type: plan.type,
          productId: plan.productId,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)), // 1개월
          isActive: true,
          autoRenew: true,
          metadata: {
            'purchasedAt': DateTime.now().toIso8601String(),
            'price': plan.price,
            'source': 'in_app_purchase',
          },
        );

        _currentSubscription = newSubscription;
        await _saveSubscription();

        debugPrint('구독 구매 성공: ${plan.title}');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('구독 구매 실패: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 구독 취소
  Future<bool> cancelSubscription() async {
    try {
      _isLoading = true;
      notifyListeners();

      if (_currentSubscription == null || _currentSubscription!.type == SubscriptionType.free) {
        return false;
      }

      // 실제 구현에서는 플랫폼별 구독 취소 처리
      await Future.delayed(const Duration(seconds: 2));

      // 구독 취소 - 만료일까지는 유지, autoRenew만 false로 변경
      _currentSubscription = _currentSubscription!.copyWith(
        autoRenew: false,
        metadata: {
          ..._currentSubscription!.metadata,
          'cancelledAt': DateTime.now().toIso8601String(),
        },
      );

      await _saveSubscription();

      debugPrint('구독 취소 성공');
      return true;
    } catch (e) {
      debugPrint('구독 취소 실패: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 구독 복원
  Future<bool> restoreSubscription() async {
    try {
      _isLoading = true;
      notifyListeners();

      // 실제 구현에서는 플랫폼별 구독 복원 처리
      await Future.delayed(const Duration(seconds: 2));

      // 시뮬레이션: 이전 구독이 있었다고 가정
      final hasValidPurchase = await _checkForValidPurchases();
      
      if (hasValidPurchase) {
        // 예시로 스탠다드 플랜 복원
        _currentSubscription = UserSubscription(
          id: _uuid.v4(),
          type: SubscriptionType.standard,
          productId: 'litten_standard_monthly',
          startDate: DateTime.now().subtract(const Duration(days: 15)),
          endDate: DateTime.now().add(const Duration(days: 15)),
          isActive: true,
          autoRenew: true,
          metadata: {
            'restoredAt': DateTime.now().toIso8601String(),
            'source': 'restore',
          },
        );

        await _saveSubscription();
        debugPrint('구독 복원 성공');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('구독 복원 실패: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 구독 정보 저장
  Future<void> _saveSubscription() async {
    if (_currentSubscription != null) {
      final subscriptionJson = jsonEncode(_currentSubscription!.toJson());
      await PreferencesService.setBool('subscription_data', true); // 임시로 bool 저장
      await PreferencesService.setSubscriptionType(_currentSubscription!.type.id);
    }
  }

  // 만료된 구독 처리
  Future<void> _handleExpiredSubscription() async {
    if (_currentSubscription != null) {
      _currentSubscription = _createFreeSubscription();
      await _saveSubscription();
      debugPrint('구독이 만료되어 무료 플랜으로 전환되었습니다');
    }
  }

  // 유효한 구매 내역 확인 (시뮬레이션)
  Future<bool> _checkForValidPurchases() async {
    // 실제로는 플랫폼 스토어에서 구매 내역을 확인
    // 시뮬레이션: 50% 확률로 유효한 구매 내역이 있다고 가정
    return DateTime.now().millisecondsSinceEpoch % 2 == 0;
  }

  // 특정 기능 사용 가능 여부 확인
  bool canUseFeature(String feature) {
    switch (feature) {
      case 'unlimited_notes':
        return !isFreePlan;
      case 'unlimited_files':
        return !isFreePlan;
      case 'no_ads':
        return !isFreePlan;
      case 'cloud_sync':
        return isPremiumPlan;
      case 'web_access':
        return isPremiumPlan;
      case 'team_collaboration':
        return isPremiumPlan;
      case 'api_access':
        return isPremiumPlan;
      default:
        return true; // 기본 기능은 모든 플랜에서 사용 가능
    }
  }

  // 구독 갱신 알림 필요 여부
  bool get needsRenewalNotification {
    if (_currentSubscription == null || isFreePlan) return false;
    
    final daysRemaining = _currentSubscription!.daysRemaining;
    return daysRemaining != null && daysRemaining <= 7 && !_currentSubscription!.autoRenew;
  }

  // 구독 상태 요약 정보
  Map<String, dynamic> getSubscriptionSummary() {
    if (_currentSubscription == null) {
      return {
        'type': 'free',
        'status': 'active',
        'daysRemaining': null,
        'autoRenew': false,
      };
    }

    return {
      'type': _currentSubscription!.type.id,
      'status': _currentSubscription!.isValid ? 'active' : 'expired',
      'daysRemaining': _currentSubscription!.daysRemaining,
      'autoRenew': _currentSubscription!.autoRenew,
      'endDate': _currentSubscription!.endDate?.toIso8601String(),
    };
  }

  // 구독 업그레이드 가능 여부
  bool canUpgradeTo(SubscriptionType targetType) {
    final currentIndex = SubscriptionType.values.indexOf(currentType);
    final targetIndex = SubscriptionType.values.indexOf(targetType);
    return targetIndex > currentIndex;
  }

  // 구독 다운그레이드 가능 여부
  bool canDowngradeTo(SubscriptionType targetType) {
    final currentIndex = SubscriptionType.values.indexOf(currentType);
    final targetIndex = SubscriptionType.values.indexOf(targetType);
    return targetIndex < currentIndex && hasValidSubscription;
  }

  // 리소스 정리
  @override
  void dispose() {
    super.dispose();
  }
}