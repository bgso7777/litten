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

    // PageController 초기화: 시작 화면 설정 반영 (note=0, calendar=1)
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final initialPage = appState.startScreen == 'calendar' ? 1 : 0;
    _pageController = PageController(initialPage: initialPage);
    // 시작 탭 인덱스를 상태에 동기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appState.changeTabIndex(initialPage);
    });

    // HomeScreen 등 외부에서 changeTabIndex() 호출 시 PageController 동기화
    appState.addListener(_onAppStateTabChanged);

    WidgetsBinding.instance.addObserver(this);
    debugPrint('🎵 MainTabScreen: 백그라운드 재생 지원을 위한 생명주기 관리 시작');
  }

  void _onAppStateTabChanged() {
    if (!mounted) return;
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final targetIndex = appState.selectedTabIndex;
    if (_pageController.hasClients &&
        _pageController.page?.round() != targetIndex) {
      debugPrint('🔄 [MainTabScreen] 외부 탭 전환 감지 → $targetIndex');
      _pageController.jumpToPage(targetIndex);
    }
  }

  @override
  void dispose() {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    appState.removeListener(_onAppStateTabChanged);
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
                    debugPrint('🎯 [MainTabScreen] Builder 진입 - isPremiumUser: ${appState.isPremiumUser}, adsEnabled: ${appState.adsEnabled}');
                    if (appState.adsEnabled && !appState.isPremiumUser) {
                      debugPrint('✅ [MainTabScreen] AdBanner 위젯 생성');
                      return const AdBanner();
                    } else {
                      debugPrint('✅ [MainTabScreen] 광고 숨김 (adsEnabled: ${appState.adsEnabled}, isPremiumUser: ${appState.isPremiumUser})');
                      return const SizedBox.shrink();
                    }
                  },
                ),
              Expanded(
                // ⭐ PageView를 사용하여 탭 상태 완벽 보존 (physics 비활성화로 스와이프 제스처 차단)
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // 스와이프로 페이지 변경 방지
                  children: [
                    WritingScreen(),
                    HomeScreen(key: _homeScreenKey),
                    SettingsScreen(),
                  ],
                ),
              ),
            ],
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.25),
                  width: 1.0,
                ),
              ),
            ),
            child: BottomNavigationBar(
            currentIndex: appState.selectedTabIndex,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            onTap: (index) {
              debugPrint('🔍 [MainTabScreen] 탭 터치: $index (현재: ${appState.selectedTabIndex})');

              // 탭 변경 시 현재 재생 상태 확인 및 유지
              _logCurrentPlaybackState();

              // 캘린더탭(index 1) 터치 시 처리
              if (index == 1) {
                debugPrint('📍 [MainTabScreen] 캘린더 탭 터치 - 이번 달로 이동');

                // 날짜 선택 해제
                appState.clearDateSelection();

                // 이번 달로 focusedDate 변경
                appState.changeFocusedDate(DateTime.now());

                // ⭐ 노트탭(index 0) 또는 설정탭(index 2)에서 선택된 일정이 있으면 유지
                final comingFromNoteOrSettingsWithSelection =
                    (appState.selectedTabIndex == 0 || appState.selectedTabIndex == 2) &&
                    appState.selectedLitten != null;
                if (!comingFromNoteOrSettingsWithSelection) {
                  appState.clearSelectedLitten();
                } else {
                  debugPrint('📍 [MainTabScreen] 선택 일정 유지: ${appState.selectedLitten!.title}');
                }

                // 스크롤을 맨 위로 (캘린더 표시) + undefined 자동 선택(선택 일정 없을 때만)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _homeScreenKey.currentState?.scrollToTop();
                  if (!comingFromNoteOrSettingsWithSelection) {
                    _homeScreenKey.currentState?.autoSelectUndefinedIfNeeded();
                  }
                  debugPrint('📅 캘린더 탭: 이번 달로 이동 완료');
                });
              }

              // 탭 전환 처리
              if (appState.selectedTabIndex != index) {
                debugPrint('📍 [MainTabScreen] 탭 전환 실행: ${appState.selectedTabIndex} → $index');

                // ⭐ PageView 페이지 전환 (애니메이션 없이)
                _pageController.jumpToPage(index);

                // ⭐ 캘린더 탭으로 돌아올 때 캘린더가 보이도록 스크롤을 맨 위로
                if (index == 1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _homeScreenKey.currentState?.scrollToTop();
                    debugPrint('📜 [MainTabScreen] 캘린더 탭으로 전환 - 캘린더 표시 (스크롤 맨 위)');
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
                icon: const Icon(Icons.edit_note),
                label: l10n?.writingTitle ?? '쓰기',
              ),
              BottomNavigationBarItem(
                icon: _buildHomeIconWithBadge(appState),
                label: '캘린더',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings),
                label: l10n?.settingsTitle ?? '설정',
              ),
            ],
            ),
          ),
          // 캘린더 탭(index 1)일 때만 FloatingActionButton 표시
          floatingActionButton: appState.selectedTabIndex == 1
              ? Transform.translate(
                  offset: const Offset(0, -12),
                  child: FloatingActionButton(
                    onPressed: () {
                      // HomeScreen의 _showCreateLittenDialog 호출
                      _homeScreenKey.currentState?.showCreateLittenDialog();
                    },
                    tooltip: l10n?.createLitten ?? '리튼 생성',
                    backgroundColor: Theme.of(context).primaryColor,
                    child: const Icon(Icons.alarm_add, color: Colors.white),
                  ),
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

  Widget _buildHomeIconWithBadge(AppStateProvider appState) {
    return AnimatedBuilder(
      animation: appState.notificationService,
      builder: (context, child) {
        final notificationCount = appState.notificationService.scheduleBadgeCount;

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