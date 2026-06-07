import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

import '../services/app_state_provider.dart';
import '../services/audio_service.dart';
import '../widgets/common/ad_banner.dart';
import 'home_dashboard_screen.dart';
import 'home_screen.dart';
import 'writing_screen.dart';
import 'memory_screen.dart';
import 'settings_screen.dart';

/// 메인 5탭: 홈(0) · 캘린더(1) · +(2, 노트) · 기억(3) · 설정(4)
/// 가운데 +는 페이지가 아니라 "파일 생성" 진입점 — 탭하면 바텀시트를 띄우고,
/// 종류 선택 시 노트(index 2)로 진입한다.
class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> with WidgetsBindingObserver {
  late AudioService audioService;
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();
  late PageController _pageController; // ⭐ PageView 컨트롤러

  // 5탭 인덱스 상수: 홈0 · 캘린더1 · +2(노트) · 기억3 · 설정4
  static const int _homeTab = 0;
  static const int _calendarTab = 1;
  static const int _createTab = 2; // 노트(+) — 액션 탭

  @override
  void initState() {
    super.initState();
    audioService = AudioService();

    // PageController 초기화
    // ⭐ 완전 종료 후 재실행(cold start) → 항상 홈 탭으로 시작.
    //    백그라운드 복귀는 프로세스가 살아 있으면 initState가 다시 호출되지 않으므로
    //    PageView가 마지막 탭/작업창 상태를 그대로 보존한다.
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    const initialPage = _homeTab;
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

    final appState = Provider.of<AppStateProvider>(context, listen: false);

    switch (state) {
      case AppLifecycleState.paused:
        debugPrint('🎵 앱이 백그라운드로 이동 - 오디오 재생 유지');
        appState.notificationService.onAppPaused();
        break;
      case AppLifecycleState.resumed:
        debugPrint('🎵 앱이 포그라운드로 복귀 - 오디오 재생 상태 확인 + 알림 뱃지 갱신');
        appState.notificationService.onAppResumed();
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
        debugPrint('🚨 [MainTabScreen] 광고 표시 조건: adsEnabled=${appState.adsEnabled}, !isPremiumUser=${!appState.isPremiumUser}');

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // 광고 배너 영역 - 최상위 배치
                if (appState.adsEnabled) const AdBanner(),
                Expanded(
                  // ⭐ PageView로 탭 상태 완벽 보존 (스와이프 차단)
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      const HomeDashboardScreen(),       // 0: 홈
                      HomeScreen(key: _homeScreenKey),   // 1: 캘린더
                      WritingScreen(),                   // 2: 노트(+)
                      const MemoryScreen(),              // 3: 기억
                      SettingsScreen(),                  // 4: 설정
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
              onTap: (index) => _onTabTapped(context, appState, index),
              type: BottomNavigationBarType.fixed,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined),
                  activeIcon: const Icon(Icons.home),
                  label: l10n?.homeTitle ?? '홈',
                ),
                BottomNavigationBarItem(
                  icon: _buildCalendarIconWithBadge(appState),
                  label: l10n?.calendarTab ?? '캘린더',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle, size: 34, color: Theme.of(context).primaryColor),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.lightbulb_outline),
                  activeIcon: const Icon(Icons.lightbulb),
                  label: '리마인드',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.settings),
                  label: l10n?.settingsTitle ?? '설정',
                ),
              ],
            ),
          ),
          // 캘린더 탭일 때만 일정 추가 FAB 표시
          floatingActionButton: appState.selectedTabIndex == _calendarTab
              ? Container(
                  margin: const EdgeInsets.only(bottom: 48),
                  child: FloatingActionButton(
                    onPressed: () {
                      debugPrint('🎯 [FAB] 일정 추가 버튼 클릭됨');
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

  /// 하단 탭 탭 처리
  void _onTabTapped(BuildContext context, AppStateProvider appState, int index) {
    debugPrint('🔍 [MainTabScreen] 탭 터치: $index (현재: ${appState.selectedTabIndex})');

    // ⭐ 가운데 +(노트) 탭 → 페이지 전환 대신 파일 생성 바텀시트
    if (index == _createTab) {
      _showCreateBottomSheet(context, appState);
      return;
    }

    _logCurrentPlaybackState();

    // 캘린더 탭 진입 처리
    if (index == _calendarTab) {
      debugPrint('📍 [MainTabScreen] 캘린더 탭 터치 - 이번 달로 이동');
      appState.clearDateSelection();
      appState.changeFocusedDate(DateTime.now());

      // 다른 화면에서 선택한 일정이 있으면 유지
      final keepSelection = appState.selectedTabIndex != _calendarTab &&
          appState.selectedLitten != null;
      if (!keepSelection) {
        appState.clearSelectedLitten();
      } else {
        debugPrint('📍 [MainTabScreen] 선택 일정 유지: ${appState.selectedLitten!.title}');
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _homeScreenKey.currentState?.scrollToTop();
        if (!keepSelection) {
          _homeScreenKey.currentState?.autoSelectUndefinedIfNeeded();
        }
        debugPrint('📅 캘린더 탭: 이번 달로 이동 완료');
      });
    }

    // 탭 전환 처리
    if (appState.selectedTabIndex != index) {
      debugPrint('📍 [MainTabScreen] 탭 전환 실행: ${appState.selectedTabIndex} → $index');
      _pageController.jumpToPage(index);
      appState.changeTabIndex(index);
      appState.setCurrentMainTab(index);
    } else {
      debugPrint('📍 [MainTabScreen] 같은 탭 - 상태 변경 없음 (재빌드 방지)');
    }
  }

  /// + 탭 → 파일 종류 선택 바텀시트
  /// 선택 시 전체탭(all)을 기본으로 깔고 노트(index 2)의 해당 생성 탭으로 진입한다.
  void _showCreateBottomSheet(BuildContext context, AppStateProvider appState) {
    debugPrint('➕ [MainTabScreen] 파일 생성 바텀시트 열기');
    final color = Theme.of(context).primaryColor;

    void enterNote(String type) {
      debugPrint('➕ [MainTabScreen] 생성 선택: $type → 노트 전체탭 진입 + 생성화면 자동 오픈');
      Navigator.pop(context);
      // 전체탭(all)을 기본으로 깔고 그 위에 생성화면을 띄운다(빠져나오면 전체탭).
      appState.setCurrentWritingTab('all');
      appState.setTargetWritingTab('all');
      // 전체탭(AllFilesTab)에서 해당 종류 생성화면 자동 진입 요청
      appState.requestCreate(type);
      // 노트 진입 + 클라우드 동기화
      appState.syncNoteTab();
      appState.changeTabIndex(_createTab);
      appState.setCurrentMainTab(_createTab);
      _pageController.jumpToPage(_createTab);
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.add, color: color),
                    const SizedBox(width: 8),
                    const Text('새로 만들기',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              _createTile(ctx, Icons.notes, '메모', color, () => enterNote('text')),
              _createTile(ctx, Icons.mic, '녹음', color, () => enterNote('audio')),
              _createTile(ctx, Icons.record_voice_over, '메모녹음', color, () => enterNote('sttMemo')),
              _createTile(ctx, Icons.draw, '필기', color, () => enterNote('handwriting')),
              _createTile(ctx, Icons.drive_folder_upload, '파일', color, () => enterNote('files')),
              _createTile(ctx, Icons.smart_display_outlined, '영상', color, () => enterNote('youtube')),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _createTile(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      onTap: onTap,
    );
  }

  void _logCurrentPlaybackState() {
    debugPrint('🎵 탭 변경 시 재생 상태 확인:');
    debugPrint('   - 오디오 재생 중: ${audioService.isPlaying}');
    debugPrint('   - 현재 재생 파일: ${audioService.currentPlayingFile?.fileName ?? "없음"}');
  }

  Widget _buildCalendarIconWithBadge(AppStateProvider appState) {
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
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
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
