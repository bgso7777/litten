import 'package:flutter/material.dart';
import '../../config/app_config.dart';

/// 광고 배너 위젯 - 무료 사용자 전용
class AdBanner extends StatefulWidget {
  final VoidCallback? onUpgradePressed;
  final VoidCallback? onAdClicked;

  const AdBanner({
    Key? key,
    this.onUpgradePressed,
    this.onAdClicked,
  }) : super(key: key);

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  AdBannerState _adState = AdBannerState.loading;
  String _adContent = '';

  @override
  void initState() {
    super.initState();
    _loadAd();
    AppConfig.logDebug('AdBanner.initState - 광고 배너 초기화');
  }

  /// 광고 로드 시뮬레이션
  Future<void> _loadAd() async {
    AppConfig.logDebug('AdBanner._loadAd - 광고 로드 시작');
    
    setState(() {
      _adState = AdBannerState.loading;
    });

    try {
      // 광고 로드 시뮬레이션 (2초 대기)
      await Future.delayed(const Duration(seconds: 2));
      
      // 80% 확률로 성공, 20% 확률로 실패
      final success = DateTime.now().millisecond % 5 != 0;
      
      if (success) {
        setState(() {
          _adState = AdBannerState.loaded;
          _adContent = _generateAdContent();
        });
        AppConfig.logInfo('AdBanner._loadAd - 광고 로드 성공');
      } else {
        setState(() {
          _adState = AdBannerState.error;
        });
        AppConfig.logWarning('AdBanner._loadAd - 광고 로드 실패');
      }
    } catch (error) {
      setState(() {
        _adState = AdBannerState.error;
      });
      AppConfig.logError('AdBanner._loadAd - 광고 로드 에러', error);
    }
  }

  /// 광고 콘텐츠 생성 (시뮬레이션)
  String _generateAdContent() {
    final adContents = [
      '🎯 새로운 기능을 먼저 체험해보세요!',
      '📚 학습 효율을 높이는 스마트 노트',
      '🚀 생산성을 극대화하는 도구들',
      '💡 아이디어를 놓치지 마세요!',
      '🎨 창의적인 작업을 위한 도구',
    ];
    
    final index = DateTime.now().millisecond % adContents.length;
    return adContents[index];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: _buildAdContent(context),
    );
  }

  /// 광고 상태별 콘텐츠 빌드
  Widget _buildAdContent(BuildContext context) {
    switch (_adState) {
      case AdBannerState.loading:
        return _buildLoadingContent(context);
      case AdBannerState.loaded:
        return _buildLoadedContent(context);
      case AdBannerState.error:
        return _buildErrorContent(context);
    }
  }

  /// 로딩 중 콘텐츠
  Widget _buildLoadingContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '광고 로딩 중...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// 로드 완료 콘텐츠
  Widget _buildLoadedContent(BuildContext context) {
    return InkWell(
      onTap: _handleAdClick,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // 광고 콘텐츠
            Expanded(
              child: Text(
                _adContent,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            
            // 업그레이드 버튼
            ElevatedButton(
              onPressed: widget.onUpgradePressed,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                '광고 제거',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 에러 콘텐츠
  Widget _buildErrorContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '광고를 불러올 수 없습니다',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // 재시도 버튼
          TextButton(
            onPressed: _loadAd,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              '재시도',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          
          // 업그레이드 버튼
          ElevatedButton(
            onPressed: widget.onUpgradePressed,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              '광고 제거',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 광고 클릭 처리
  void _handleAdClick() {
    AppConfig.logDebug('AdBanner._handleAdClick - 광고 클릭');
    
    // 광고 클릭 콜백 호출
    widget.onAdClicked?.call();
    
    // 실제로는 광고 네트워크의 클릭 처리
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('광고 클릭됨'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

/// 광고 배너 상태
enum AdBannerState {
  loading,  // 로딩 중
  loaded,   // 로드 완료
  error,    // 로드 실패
}