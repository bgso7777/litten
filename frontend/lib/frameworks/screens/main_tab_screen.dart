import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../config/app_config.dart';
import '../../services/models/user_settings.dart';
import '../providers/litten_provider.dart';
import '../widgets/ad_banner.dart';
import '../widgets/file_count_badge.dart';
import 'home/home_screen.dart';
import 'recorder/recorder_screen.dart';
import 'writing/writing_screen.dart';
import 'settings/settings_screen.dart';

/// 메인 탭 화면 - 4개 탭으로 구성
class MainTabScreen extends StatefulWidget {
  const MainTabScreen({Key? key}) : super(key: key);

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  // 임시 구독 상태 (실제로는 UserSettingsProvider에서 관리)
  SubscriptionTier _subscriptionTier = SubscriptionTier.free;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    
    AppConfig.logDebug('MainTabScreen.initState - 메인 탭 화면 초기화');
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    
    final newIndex = _tabController.index;
    if (newIndex != _currentIndex) {
      setState(() {
        _currentIndex = newIndex;
      });
      
      AppConfig.logDebug('MainTabScreen._handleTabChange - 탭 변경: $_currentIndex -> $newIndex');
    }
  }

  void _onTabTapped(int index) {
    AppConfig.logDebug('MainTabScreen._onTabTapped - 탭 터치: $index');
    
    if (index == _currentIndex) return;
    
    setState(() {
      _currentIndex = index;
    });
    
    _tabController.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    AppConfig.logDebug('MainTabScreen.build - 메인 탭 화면 빌드: 현재 탭=$_currentIndex');
    
    return Consumer<LittenProvider>(
      builder: (context, littenProvider, child) {
        return Scaffold(
          // AppBar
          appBar: AppBar(
            leading: _buildAppBarLeading(),
            title: _buildAppBarTitle(context, l10n, littenProvider),
            actions: _buildAppBarActions(littenProvider),
            elevation: 2,
          ),
          
          // Body with AdBanner
          body: Column(
            children: [
              // 광고 배너 (무료 사용자만)
              if (_subscriptionTier == SubscriptionTier.free)
                AdBanner(
                  onUpgradePressed: () => _showUpgradeDialog(context, l10n),
                ),
              
              // 탭 내용
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    HomeScreen(),
                    RecorderScreen(),
                    WritingScreen(),
                    SettingsScreen(),
                  ],
                ),
              ),
            ],
          ),
          
          // Bottom Navigation Bar
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home),
                label: l10n.homeTitle,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.mic),
                label: l10n.recorderTitle,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.edit),
                label: l10n.writingTitle,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings),
                label: l10n.settingsTitle,
              ),
            ],
          ),
        );
      },
    );
  }

  /// AppBar Leading 위젯 - 리튼 로고
  Widget _buildAppBarLeading() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 듣기 아이콘
          Icon(
            Icons.hearing,
            size: 16,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 2),
          // 쓰기 아이콘들
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.keyboard,
                size: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 1),
              Icon(
                Icons.draw,
                size: 12,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// AppBar Title 위젯
  Widget _buildAppBarTitle(
    BuildContext context,
    AppLocalizations l10n,
    LittenProvider littenProvider,
  ) {
    if (littenProvider.selectedLitten != null) {
      final litten = littenProvider.selectedLitten!;
      return Column(
        children: [
          Text(
            litten.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (litten.description.isNotEmpty)
            Text(
              litten.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      );
    } else {
      return Text(
        l10n.selectLitten,
        style: Theme.of(context).textTheme.titleMedium,
      );
    }
  }

  /// AppBar Actions 위젯 - 파일 수 배지들
  List<Widget> _buildAppBarActions(LittenProvider littenProvider) {
    if (littenProvider.selectedLitten == null) {
      return [];
    }

    final litten = littenProvider.selectedLitten!;
    
    return [
      // 오디오 파일 수 배지
      FileCountBadge(
        icon: Icons.mic,
        count: litten.audioFileCount,
        color: Colors.red,
      ),
      const SizedBox(width: 4),
      
      // 텍스트 + 드로잉 파일 수 배지 (쓰기로 통합)
      FileCountBadge(
        icon: Icons.edit,
        count: litten.textFileCount + litten.drawingFileCount,
        color: Colors.green,
      ),
      const SizedBox(width: 16),
    ];
  }

  /// 프리미엄 업그레이드 다이얼로그
  void _showUpgradeDialog(BuildContext context, AppLocalizations l10n) {
    AppConfig.logDebug('MainTabScreen._showUpgradeDialog - 업그레이드 다이얼로그 표시');
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.star, color: Colors.amber),
              const SizedBox(width: 8),
              Text(l10n.upgradeToPremium),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.subscriptionBenefits,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildBenefitRow(Icons.block, l10n.removeAds),
              _buildBenefitRow(Icons.all_inclusive, l10n.unlimitedFiles),
              _buildBenefitRow(Icons.cloud, l10n.cloudSync),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).primaryColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      l10n.monthlyPrice,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      l10n.cancelAnytime,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.maybeLater),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleUpgrade();
              },
              child: Text(l10n.upgradeNow),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.check,
            color: Colors.green,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  /// 업그레이드 처리
  void _handleUpgrade() {
    AppConfig.logDebug('MainTabScreen._handleUpgrade - 업그레이드 처리');
    // TODO: 실제 결제 처리 구현
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('업그레이드 기능은 곧 제공됩니다!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}