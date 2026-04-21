import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

import '../services/app_state_provider.dart';
import '../services/audio_service.dart';
import '../widgets/common/ad_banner.dart';
import 'home_screen.dart';
import 'writing_screen.dart';
// import '../widgets/handwriting_tab.dart';
import 'settings_screen.dart';
import '../config/themes.dart';
import '../utils/responsive_utils.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> with WidgetsBindingObserver {
  late AudioService audioService;
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();
  late PageController _pageController; // ⭐ PageView 컨트롤러

  @override
  void initState() {
    super.initState();
    audioService = AudioService();

    // PageController 초기화
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    _pageController = PageController(initialPage: appState.selectedTabIndex);

    WidgetsBinding.instance.addObserver(this);
    debugPrint('🎵 MainTabScreen: 백그라운드 재생 지원을 위한 생명주기 관리 시작');
  }

  @override
  void dispose() {
    _pageController.dispose(); // ⭐ PageController dispose
    WidgetsBinding.instance.removeObserver(this);
    debugPrint('🎵 MainTabScreen: 백그라운드 재생 지원을 위한 생명주기 관리 종료');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('🎵 MainTabScreen: 앱 생명주기 변경 - $state');

    switch (state) {
      case AppLifecycleState.paused:
        debugPrint('🎵 앱이 백그라운드로 이동 - 오디오 재생 유지');
        break;
      case AppLifecycleState.resumed:
        debugPrint('🎵 앱이 포그라운드로 복귀 - 오디오 재생 상태 확인');
        break;
      case AppLifecycleState.detached:
        debugPrint('🎵 앱 종료 - 오디오 재생 중지');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        final l10n = AppLocalizations.of(context);

        // selectedLitten이 null인 경우 undefined 리튼 자동 선택
        if (appState.selectedLitten == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final undefinedLitten = appState.littens
                .where((l) => l.title == 'undefined')
                .firstOrNull;
            if (undefinedLitten != null) {
              appState.selectLitten(undefinedLitten);
              debugPrint('✅ MainTabScreen: undefined 리튼 자동 선택');
            }
          });
        }

        debugPrint('🔄 [MainTabScreen] build 호출 - 현재 탭: ${appState.selectedTabIndex}');
        debugPrint('📢 [MainTabScreen] isPremiumUser: ${appState.isPremiumUser}, subscriptionType: ${appState.subscriptionType}');

        debugPrint('🚨 [MainTabScreen] 광고 표시 조건: !isPremiumUser=${!appState.isPremiumUser}');

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // 광고 배너 영역 - 최상위 배치
                Builder(
                  builder: (context) {
                    debugPrint('🎯 [MainTabScreen] Builder 진입 - isPremiumUser: ${appState.isPremiumUser}');
                    if (!appState.isPremiumUser) {
                      debugPrint('✅ [MainTabScreen] AdBanner 위젯 생성');
                      return const AdBanner();
                    } else {
                      debugPrint('❌ [MainTabScreen] 흰색 컨테이너 생성 (프리미엄 사용자)');
                      return Container(
                        height: 50,
                        color: Colors.white,
                      );
                    }
                  },
                ),
              // 노트 탭(index 1)일 때만 통계 영역(AppBar 역할) 표시
              if (appState.selectedTabIndex == 1)
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).primaryColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      _buildLittenCountBadge(appState, context),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Center(
                          child: appState.selectedLitten != null
                              ? Text(
                                  appState.selectedLitten!.title == 'undefined' ? '-' : appState.selectedLitten!.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: appState.selectedLitten!.title == 'undefined'
                                        ? Theme.of(context).textTheme.titleLarge?.color?.withValues(alpha: 0.33)
                                        : null,
                                  ),
                                )
                              : Text(
                                  l10n?.emptyLittenTitle ?? '리튼을 생성하거나 선택하세요',
                                  style: const TextStyle(fontSize: 14),
                                ),
                        ),
                      ),
                      _buildFileCountBadgesOnly(appState, context),
                    ],
                  ),
                ),
              Expanded(
                // ⭐ PageView를 사용하여 탭 상태 완벽 보존 (physics 비활성화로 스와이프 제스처 차단)
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // 스와이프로 페이지 변경 방지
                  children: [
                    HomeScreen(key: _homeScreenKey),
                    WritingScreen(),
                    SettingsScreen(),
                  ],
                ),
              ),
            ],
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: appState.selectedTabIndex,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            onTap: (index) {
              debugPrint('🔍 [MainTabScreen] 탭 터치: $index (현재: ${appState.selectedTabIndex})');

              // 탭 변경 시 현재 재생 상태 확인 및 유지
              _logCurrentPlaybackState();

              // 캘린더탭(index 0) 터치 시 처리
              if (index == 0) {
                // ⭐ 캘린더 탭 터치 시 - 항상 초기 상태로 리셋
                debugPrint('📍 [MainTabScreen] 캘린더 탭 터치 - 이번 달로 이동');

                // 날짜 선택 해제
                appState.clearDateSelection();

                // 이번 달로 focusedDate 변경
                appState.changeFocusedDate(DateTime.now());

                // undefined 리튼 선택
                final undefinedLitten = appState.littens.firstWhere(
                  (litten) => litten.title == 'undefined',
                  orElse: () => appState.littens.first,
                );
                appState.selectLitten(undefinedLitten);

                // 스크롤을 맨 위로 (캘린더 표시)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _homeScreenKey.currentState?.scrollToTop();
                  debugPrint('📅 캘린더 탭: 이번 달로 이동 완료');
                });
              }

              // 탭 전환 처리
              if (appState.selectedTabIndex != index) {
                debugPrint('📍 [MainTabScreen] 탭 전환 실행: ${appState.selectedTabIndex} → $index');

                // ⭐ PageView 페이지 전환 (애니메이션 없이)
                _pageController.jumpToPage(index);

                // ⭐ 홈 탭으로 돌아올 때 캘린더가 보이도록 스크롤을 맨 위로
                if (index == 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _homeScreenKey.currentState?.scrollToTop();
                    debugPrint('📜 [MainTabScreen] 홈 탭으로 전환 - 캘린더 표시 (스크롤 맨 위)');
                  });
                }

                appState.changeTabIndex(index);
                appState.setCurrentMainTab(index); // ⭐ 메인 탭 위치 저장
              } else {
                debugPrint('📍 [MainTabScreen] 같은 탭 - 상태 변경 없음 (재빌드 방지)');
              }
            },
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: _buildHomeIconWithBadge(appState),
                label: '캘린더',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.edit_note),
                label: l10n?.writingTitle ?? '쓰기',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings),
                label: l10n?.settingsTitle ?? '설정',
              ),
            ],
          ),
          // 홈 탭(index 0)일 때만 FloatingActionButton 표시
          floatingActionButton: appState.selectedTabIndex == 0
              ? FloatingActionButton(
                  onPressed: () {
                    // HomeScreen의 _showCreateLittenDialog 호출
                    _homeScreenKey.currentState?.showCreateLittenDialog();
                  },
                  tooltip: l10n?.createLitten ?? '리튼 생성',
                  backgroundColor: Theme.of(context).primaryColor,
                  child: const Icon(Icons.alarm_add, color: Colors.white),
                )
              : null,
        );
      },
    );
  }

  /// 현재 재생 상태를 로깅하고 백그라운드 재생 상태를 확인하는 메소드
  void _logCurrentPlaybackState() {
    debugPrint('🎵 탭 변경 시 재생 상태 확인:');
    debugPrint('   - 오디오 재생 중: ${audioService.isPlaying}');
    debugPrint('   - 현재 재생 파일: ${audioService.currentPlayingFile?.fileName ?? "없음"}');
    debugPrint('   - 재생 시간: ${audioService.playbackDuration}');
    debugPrint('   - 전체 시간: ${audioService.totalDuration}');
    debugPrint('🎵 백그라운드 재생 유지: IndexedStack 사용으로 화면 상태 보존됨');
  }

  Widget _buildLittenCountBadge(AppStateProvider appState, BuildContext context) {
    // 전체 리튼 수 배지 (undefined 제외, 알림이 있으면 -1 표시)
    final littenCount = appState.littens.where((l) => l.title != 'undefined').length;
    final hasNotifications = appState.notificationService.firedNotifications.isNotEmpty;
    final displayCount = hasNotifications ? littenCount - 1 : littenCount;

    return Container(
      padding: ResponsiveUtils.getBadgePadding(context),
      decoration: BoxDecoration(
        color: littenCount > 0
            ? (hasNotifications ? Colors.orange : Theme.of(context).primaryColor)
            : Theme.of(context).primaryColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(ResponsiveUtils.getBadgeBorderRadius(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder,
              size: ResponsiveUtils.getBadgeIconSize(context),
              color: littenCount > 0 ? Colors.white : Colors.white70),
          AppSpacing.horizontalSpaceXS,
          Text(
            displayCount.toString(),
            style: TextStyle(
              color: littenCount > 0 ? Colors.white : Colors.white70,
              fontSize: ResponsiveUtils.getBadgeFontSize(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCountBadgesOnly(AppStateProvider appState, BuildContext context) {
    // 실제 파일 카운트 상태 변수 사용
    final audioCount = appState.actualAudioCount;
    final textCount = appState.actualTextCount;
    final handwritingCount = appState.actualHandwritingCount;

    final badges = _buildFileCountBadges(context, audioCount, textCount, handwritingCount);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: badges,
    );
  }

  List<Widget> _buildFileCountBadges(BuildContext context, int audioCount, int textCount, int handwritingCount) {

    final badges = <Widget>[];

    // 텍스트 파일 배지 (0개일 때도 표시) - 첫 번째로 변경
    badges.add(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4.9, vertical: 1.6),
        decoration: BoxDecoration(
          color: textCount > 0 ? Theme.of(context).primaryColor : Theme.of(context).primaryColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(ResponsiveUtils.getBadgeBorderRadius(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.keyboard,
                size: ResponsiveUtils.getBadgeIconSize(context),
                color: textCount > 0 ? Colors.white : Colors.white70),
            AppSpacing.horizontalSpaceXS,
            Text(
              textCount.toString(),
              style: TextStyle(
                color: textCount > 0 ? Colors.white : Colors.white70,
                fontSize: ResponsiveUtils.getBadgeFontSize(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    // 필기 파일 배지 (0개일 때도 표시) - 두 번째로 변경
    badges.add(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4.9, vertical: 1.6),
        decoration: BoxDecoration(
          color: handwritingCount > 0
              ? Theme.of(context).primaryColor
              : Theme.of(context).primaryColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(ResponsiveUtils.getBadgeBorderRadius(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.draw,
                size: ResponsiveUtils.getBadgeIconSize(context),
                color: handwritingCount > 0 ? Colors.white : Colors.white70),
            AppSpacing.horizontalSpaceXS,
            Text(
              handwritingCount.toString(),
              style: TextStyle(
                color: handwritingCount > 0 ? Colors.white : Colors.white70,
                fontSize: ResponsiveUtils.getBadgeFontSize(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    // 녹음 파일 배지 (0개일 때도 표시) - 세 번째로 변경
    badges.add(
      Container(
        padding: ResponsiveUtils.getBadgePadding(context),
        decoration: BoxDecoration(
          color: audioCount > 0 ? Theme.of(context).primaryColor : Theme.of(context).primaryColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(ResponsiveUtils.getBadgeBorderRadius(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic,
                size: ResponsiveUtils.getBadgeIconSize(context),
                color: audioCount > 0 ? Colors.white : Colors.white70),
            AppSpacing.horizontalSpaceXS,
            Text(
              audioCount.toString(),
              style: TextStyle(
                color: audioCount > 0 ? Colors.white : Colors.white70,
                fontSize: ResponsiveUtils.getBadgeFontSize(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    // 배지들 사이에 균일한 간격 추가
    final spacedBadges = <Widget>[];
    for (int i = 0; i < badges.length; i++) {
      spacedBadges.add(badges[i]);
      if (i < badges.length - 1) {
        spacedBadges.add(AppSpacing.horizontalSpaceXS);
      }
    }

    // 마지막에 여백 추가
    if (spacedBadges.isNotEmpty) {
      spacedBadges.add(AppSpacing.horizontalSpaceM);
    }

    return spacedBadges;
  }


  Widget _buildHomeIconWithBadge(AppStateProvider appState) {
    return AnimatedBuilder(
      animation: appState.notificationService,
      builder: (context, child) {
        final notificationCount = appState.notificationService.firedNotifications.length;

        if (notificationCount == 0) {
          return const Icon(Icons.event_available);
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.event_available),
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  notificationCount > 99 ? '99+' : notificationCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

}