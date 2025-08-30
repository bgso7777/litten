import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';

import '../../services/app_state_provider.dart';
import '../../config/themes.dart';

class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  AdState _adState = AdState.loading;
  int _currentAdIndex = 0;

  List<String> get _adMessages {
    final l10n = AppLocalizations.of(context);
    return [
      l10n?.removeAds ?? '✨ 프리미엄으로 업그레이드하고 광고를 제거하세요!',
      l10n?.standardVersion ?? '🎯 스탠다드 플랜으로 무제한 파일을 저장하세요!', 
      l10n?.premiumVersion ?? '☁️ 프리미엄 플랜으로 클라우드 동기화를 즐기세요!',
      l10n?.upgrade ?? '🔥 지금 업그레이드하고 모든 기능을 사용하세요!',
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    // 광고 로딩 시뮬레이션
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _adState = AdState.loaded;
      });
    }

    // 광고 순환을 위한 타이머
    Future.delayed(const Duration(seconds: 5), _rotateAd);
  }

  void _rotateAd() {
    if (mounted) {
      setState(() {
        _currentAdIndex = (_currentAdIndex + 1) % _adMessages.length;
      });
      Future.delayed(const Duration(seconds: 5), _rotateAd);
    }
  }

  void _showUpgradeDialog() {
    final l10n = AppLocalizations.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.upgrade ?? '업그레이드'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '스탠다드 플랜 - \$4.99/월',
              style: AppTextStyles.headline3,
            ),
            AppSpacing.verticalSpaceS,
            _buildBenefit('✓ 광고 제거'),
            _buildBenefit('✓ 무제한 리튼 생성'),
            _buildBenefit('✓ 무제한 파일 저장'),
            AppSpacing.verticalSpaceL,
            Text(
              '프리미엄 플랜 - \$9.99/월',
              style: AppTextStyles.headline3,
            ),
            AppSpacing.verticalSpaceS,
            _buildBenefit('✓ 스탠다드 플랜 모든 기능'),
            _buildBenefit('✓ 클라우드 동기화'),
            _buildBenefit('✓ 대용량 파일 지원'),
            _buildBenefit('✓ 우선 고객 지원'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.delete ?? '취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 업그레이드 로직 구현 필요
              _simulateUpgrade();
            },
            child: Text(l10n?.upgrade ?? '업그레이드'),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.check, color: Colors.green, size: 16),
          AppSpacing.horizontalSpaceS,
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  void _simulateUpgrade() {
    // 업그레이드 시뮬레이션
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);
    appState.updateSubscriptionType(SubscriptionType.standard);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n?.standardVersion ?? '스탠다드 플랜으로 업그레이드되었습니다! (시뮬레이션)'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Container(
      height: 50,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: _buildAdContent(),
            ),
            AppSpacing.horizontalSpaceS,
            ElevatedButton(
              onPressed: _showUpgradeDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                minimumSize: const Size(60, 28),
                textStyle: const TextStyle(fontSize: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: Text(l10n?.removeAds ?? '광고 제거'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdContent() {
    final l10n = AppLocalizations.of(context);
    switch (_adState) {
      case AdState.loading:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n?.freeVersion ?? '광고 로딩 중...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        );
        
      case AdState.loaded:
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Text(
            _adMessages[_currentAdIndex],
            key: ValueKey(_currentAdIndex),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
        
      case AdState.error:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text(
              l10n?.freeVersion ?? '광고를 로드할 수 없습니다',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        );
    }
  }
}

enum AdState {
  loading,
  loaded,
  error,
}