import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    // 구독 서비스 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionService>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('구독 관리'),
        elevation: 0,
      ),
      body: Consumer<SubscriptionService>(
        builder: (context, subscriptionService, child) {
          if (subscriptionService.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCurrentSubscriptionCard(subscriptionService),
                const SizedBox(height: 24),
                _buildSubscriptionPlans(subscriptionService),
                const SizedBox(height: 24),
                _buildRestoreButton(subscriptionService),
                const SizedBox(height: 16),
                _buildTermsAndConditions(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentSubscriptionCard(SubscriptionService service) {
    final subscription = service.currentSubscription;
    final plan = SubscriptionPlan.getPlanByType(service.currentType);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getSubscriptionIcon(service.currentType),
                  size: 32,
                  color: _getSubscriptionColor(service.currentType),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '현재 구독: ${plan.title}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        plan.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (subscription != null && !service.isFreePlan) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // 구독 상세 정보
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '상태',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        subscription.isValid ? '활성' : '만료됨',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: subscription.isValid ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (subscription.daysRemaining != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          '남은 기간',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '${subscription.daysRemaining}일',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '자동 갱신',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        subscription.autoRenew ? '켜짐' : '꺼짐',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: subscription.autoRenew ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  if (subscription.endDate != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          '만료일',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          '${subscription.endDate!.month}/${subscription.endDate!.day}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              
              // 구독 취소 버튼
              if (subscription.autoRenew) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showCancelDialog(service),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('구독 취소'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionPlans(SubscriptionService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '구독 플랜',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...SubscriptionPlan.availablePlans.map((plan) {
          if (plan.type == SubscriptionType.free) {
            return const SizedBox.shrink(); // 무료 플랜은 숨김
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildPlanCard(plan, service),
          );
        }),
      ],
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan, SubscriptionService service) {
    final isCurrentPlan = service.currentType == plan.type;
    final canUpgrade = service.canUpgradeTo(plan.type);
    
    return Card(
      elevation: plan.isPopular ? 4 : 2,
      child: Container(
        decoration: plan.isPopular
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              plan.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (plan.isPopular) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  '인기',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plan.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        plan.price,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (plan.period.isNotEmpty)
                        Text(
                          '/${plan.period}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // 기능 목록
              ...plan.features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )),
              
              const SizedBox(height: 16),
              
              // 구독 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isCurrentPlan
                      ? null
                      : canUpgrade
                          ? () => _purchaseSubscription(plan, service)
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: plan.isPopular
                        ? Theme.of(context).primaryColor
                        : null,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: Text(
                    isCurrentPlan
                        ? '현재 구독 중'
                        : canUpgrade
                            ? '구독하기'
                            : '다운그레이드 불가',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestoreButton(SubscriptionService service) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(
              Icons.restore,
              size: 32,
              color: Colors.grey,
            ),
            const SizedBox(height: 8),
            const Text(
              '이전 구매 복원',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '다른 기기에서 이미 구독했다면 구매 내역을 복원할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: service.isLoading
                    ? null
                    : () => _restoreSubscription(service),
                child: service.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('구매 복원'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsAndConditions() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 16),
        const Text(
          '• 구독은 앱스토어 계정으로 결제됩니다\n'
          '• 무료 체험 기간이 끝나면 자동으로 결제됩니다\n'
          '• 구독은 언제든지 취소할 수 있습니다\n'
          '• 취소 후에도 현재 구독 기간까지 서비스를 이용할 수 있습니다',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
              onPressed: () {
                // 이용약관 페이지로 이동
              },
              child: const Text('이용약관'),
            ),
            TextButton(
              onPressed: () {
                // 개인정보처리방침 페이지로 이동
              },
              child: const Text('개인정보처리방침'),
            ),
          ],
        ),
      ],
    );
  }

  IconData _getSubscriptionIcon(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.free:
        return Icons.free_breakfast;
      case SubscriptionType.standard:
        return Icons.star;
      case SubscriptionType.premium:
        return Icons.diamond;
    }
  }

  Color _getSubscriptionColor(SubscriptionType type) {
    switch (type) {
      case SubscriptionType.free:
        return Colors.grey;
      case SubscriptionType.standard:
        return Colors.orange;
      case SubscriptionType.premium:
        return Colors.purple;
    }
  }

  Future<void> _purchaseSubscription(SubscriptionPlan plan, SubscriptionService service) async {
    // 구매 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${plan.title} 구독'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${plan.price}${plan.period.isNotEmpty ? '/${plan.period}' : ''}로 구독하시겠습니까?'),
            const SizedBox(height: 16),
            const Text(
              '구독 혜택:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            ...plan.features.take(3).map((feature) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $feature'),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('구독'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await service.purchaseSubscription(plan);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${plan.title} 구독이 완료되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('구독 처리 중 오류가 발생했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _restoreSubscription(SubscriptionService service) async {
    final success = await service.restoreSubscription();
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('구독이 복원되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('복원할 구독 내역이 없습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _showCancelDialog(SubscriptionService service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('구독 취소'),
        content: const Text(
          '구독을 취소하시겠습니까?\n\n'
          '취소 후에도 현재 구독 기간까지는 모든 기능을 계속 사용할 수 있습니다.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 구독'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('취소'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await service.cancelSubscription();
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('구독이 취소되었습니다.'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('구독 취소 중 오류가 발생했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}