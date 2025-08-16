import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';
import '../screens/subscription_screen.dart';

class UpgradeDialog extends StatelessWidget {
  final String featureName;
  final List<String>? specificBenefits;
  final SubscriptionType targetPlan;

  const UpgradeDialog({
    super.key,
    required this.featureName,
    this.specificBenefits,
    this.targetPlan = SubscriptionType.standard,
  });

  @override
  Widget build(BuildContext context) {
    final plan = SubscriptionPlan.getPlanByType(targetPlan);
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            targetPlan == SubscriptionType.standard ? Icons.star : Icons.diamond,
            color: targetPlan == SubscriptionType.standard ? Colors.orange : Colors.purple,
            size: 28,
          ),
          const SizedBox(width: 8),
          Text('${plan.title}로 업그레이드'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$featureName 기능을 사용하려면 ${plan.title}로 업그레이드가 필요합니다.',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          Text(
            '${plan.title}의 혜택:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...(specificBenefits ?? plan.features.take(4)).map(
            (benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      benefit,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_offer,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${plan.price}${plan.period.isNotEmpty ? '/${plan.period}' : ''}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('나중에'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            _navigateToSubscription(context);
          },
          child: const Text('업그레이드'),
        ),
      ],
    );
  }

  void _navigateToSubscription(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SubscriptionScreen(),
      ),
    );
  }

  static void show(
    BuildContext context, {
    required String featureName,
    List<String>? specificBenefits,
    SubscriptionType targetPlan = SubscriptionType.standard,
  }) {
    showDialog(
      context: context,
      builder: (context) => UpgradeDialog(
        featureName: featureName,
        specificBenefits: specificBenefits,
        targetPlan: targetPlan,
      ),
    );
  }
}

// 구독 상태 확인 및 업그레이드 다이얼로그 표시 헬퍼
class SubscriptionGate {
  static bool checkFeatureAccess(
    BuildContext context, 
    String feature, {
    String? featureName,
    List<String>? benefits,
    SubscriptionType targetPlan = SubscriptionType.standard,
    bool showDialog = true,
  }) {
    final subscriptionService = context.read<SubscriptionService>();
    
    if (subscriptionService.canUseFeature(feature)) {
      return true;
    }
    
    if (showDialog) {
      UpgradeDialog.show(
        context,
        featureName: featureName ?? feature,
        specificBenefits: benefits,
        targetPlan: targetPlan,
      );
    }
    
    return false;
  }
}

// 구독 상태를 표시하는 뱃지 위젯
class SubscriptionBadge extends StatelessWidget {
  final SubscriptionType type;
  final double? size;

  const SubscriptionBadge({
    super.key,
    required this.type,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (type == SubscriptionType.free) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getColor(),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIcon(),
            size: size,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            type.displayName,
            style: TextStyle(
              fontSize: size! * 0.75,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor() {
    switch (type) {
      case SubscriptionType.standard:
        return Colors.orange;
      case SubscriptionType.premium:
        return Colors.purple;
      case SubscriptionType.free:
        return Colors.grey;
    }
  }

  IconData _getIcon() {
    switch (type) {
      case SubscriptionType.standard:
        return Icons.star;
      case SubscriptionType.premium:
        return Icons.diamond;
      case SubscriptionType.free:
        return Icons.free_breakfast;
    }
  }
}

// 기능 제한 상태를 표시하는 위젯
class FeatureLockWidget extends StatelessWidget {
  final String featureName;
  final SubscriptionType requiredPlan;
  final VoidCallback? onUpgrade;

  const FeatureLockWidget({
    super.key,
    required this.featureName,
    required this.requiredPlan,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            '$featureName',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${requiredPlan.displayName} 플랜에서\n사용할 수 있습니다',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onUpgrade ?? () {
                UpgradeDialog.show(
                  context,
                  featureName: featureName,
                  targetPlan: requiredPlan,
                );
              },
              icon: const Icon(Icons.upgrade, size: 18),
              label: const Text('업그레이드'),
            ),
          ),
        ],
      ),
    );
  }
}