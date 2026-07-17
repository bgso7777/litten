import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

import '../services/app_state_provider.dart';
import '../services/audio_service.dart';
import '../widgets/common/ad_banner.dart';
import 'home_tab_screen.dart';
import 'home_dashboard_screen.dart';
import 'home_screen.dart';
import 'calendar_tab_screen.dart';
import 'writing_screen.dart';
import 'remind_screen.dart';
import 'settings_tab_screen.dart';
import 'login_screen.dart';

/// 메인 5탭: 홈(0) · 캘린더(1) · +(2, 노트) · 리마인드(3) · 설정(4)
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

  // 5탭 인덱스 상수: 홈0 · 캘린더1 · +2(노트) · 리마인드3 · 설정4
  static const int _homeTab = 0;
  static const int _calendarTab = 1;
  static const int _createTab = 2; // 노트(+) — 액션 탭
  static const int _remindTab = 3; // 리마인드

  // 우측 하단 FAB(+)에서 각 탭 본문의 추가 액션을 호출하기 위한 키
  final GlobalKey<HomeDashboardScreenState> _homeDashKey =
      GlobalKey<HomeDashboardScreenState>();
  final GlobalKey<RemindScreenState> _remindKey =
      GlobalKey<RemindScreenState>();

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
      // 홈 일정에서 캘린더로 이동한 경우, 캘린더 탭을 누른 것처럼 전체 일정 리스트를 펼쳐서 보여준다.
      if (targetIndex == _calendarTab && appState.pendingExpandScheduleList) {
        appState.consumeExpandScheduleListRequest();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _homeScreenKey.currentState?.expandScheduleList();
        });
      }
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
        debugPrint('🎵 앱이 포그라운드로 복귀 - 오디오 재생 상태 확인 + 알림 뱃지 갱신 + 대화/셀프챗 재동기화');
        appState.notificationService.onAppResumed();
        // 다른 기기에서 바뀐 대화 이름·공유·나와의 대화를 포그라운드 복귀 시 다시 반영한다.
        appState.loadShares();
        appState.loadSelfChats();
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
                      HomeTabScreen(dashboardKey: _homeDashKey),          // 0: 홈(탭 레이아웃)
                      CalendarTabScreen(homeScreenKey: _homeScreenKey),   // 1: 캘린더(탭 레이아웃)
                      WritingScreen(),                   // 2: 노트(+)
                      RemindScreen(key: _remindKey),     // 3: 리마인드
                      const SettingsTabScreen(),         // 4: 설정(탭 레이아웃)
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
              // 라벨(한글)을 모두 비웠으므로 라벨 공간(폰트 높이)을 0으로 없애
              // 아이콘이 세로 중앙에 오게 한다 → 가운데 + 와 같은 수평선에 정렬.
              selectedFontSize: 0,
              unselectedFontSize: 0,
              iconSize: 26,
              onTap: (index) => _onTabTapped(context, appState, index),
              type: BottomNavigationBarType.fixed,
              items: [
                BottomNavigationBarItem(
                  // 홈 탭 = 스터디룸(여럿이 대화 + 자료 공유) 화면. 겹친 말풍선(forum) 아이콘 사용.
                  //   비활성: 외곽선 / 활성: 채움. 활성 시 아이콘 하단 언더라인 표시.
                  icon: _withUnderline(
                      context, const Icon(Icons.forum_outlined), false),
                  activeIcon:
                      _withUnderline(context, const Icon(Icons.forum), true),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: _withUnderline(
                      context, _buildCalendarIconWithBadge(appState), false),
                  activeIcon: _withUnderline(
                      context, _buildCalendarIconWithBadge(appState), true),
                  label: '',
                ),
                BottomNavigationBarItem(
                  // ⭐ 비활성: 연한 바탕 원 + 진한 테마색 +(테두리 없음).
                  //    활성: 진한 테마색 원 + 흰 +. (+는 activeIcon이 따로 없어 선택여부를 직접 계산)
                  icon: _withUnderline(
                      context,
                      _buildAddIcon(
                          context, appState.selectedTabIndex == _createTab),
                      appState.selectedTabIndex == _createTab),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: _withUnderline(context, _buildRemindIcon(false), false),
                  activeIcon:
                      _withUnderline(context, _buildRemindIcon(true), true),
                  label: '',
                ),
                BottomNavigationBarItem(
                  // 설정 탭 = '...'(더보기) 아이콘 + 라벨 없음
                  icon: _withUnderline(
                      context, const Icon(Icons.more_horiz), false),
                  activeIcon: _withUnderline(
                      context, const Icon(Icons.more_horiz), true),
                  label: '',
                ),
              ],
            ),
          ),
          // 홈·캘린더·리마인드 탭에서 우측 하단 추가 FAB 표시(크기·위치 동일)
          floatingActionButton: _buildAddFab(context, appState, l10n),
        );
      },
    );
  }

  /// 우측 하단 추가(+) FAB — 홈·캘린더·리마인드 탭에서만 표시한다.
  /// 세 탭 모두 캘린더와 동일한 크기(기본 FAB)·위치(margin bottom 48)를 공유하고,
  /// 탭별로 동작(새 채팅 / 일정 추가 / 메모 추가)만 다르게 연결한다.
  Widget? _buildAddFab(
      BuildContext context, AppStateProvider appState, AppLocalizations? l10n) {
    final tab = appState.selectedTabIndex;
    VoidCallback onPressed;
    IconData icon;
    String tooltip;
    switch (tab) {
      case _homeTab:
        // 새 스터디룸 FAB는 '채팅' 모드이고 대화방이 안 열렸을 때만 표시(칩 바와 동일 규칙).
        // 대화방 안 / 공유받음 / 공유한 모드에서는 숨긴다.
        if (appState.homeChatOpen || appState.homeChatView != 'chat') return null;
        onPressed = () {
          debugPrint('🎯 [FAB] 홈 새 채팅 버튼 클릭됨');
          _homeDashKey.currentState?.startNewChat();
        };
        icon = Icons.add;
        tooltip = '새 스터디룸';
        break;
      case _calendarTab:
        onPressed = () {
          debugPrint('🎯 [FAB] 일정 추가 버튼 클릭됨');
          _homeScreenKey.currentState?.showCreateLittenDialog();
        };
        icon = Icons.alarm_add;
        tooltip = l10n?.createLitten ?? '리튼 생성';
        break;
      case _remindTab:
        onPressed = () {
          debugPrint('🎯 [FAB] 리마인드 메모 추가 버튼 클릭됨');
          _remindKey.currentState?.showAddMemo();
        };
        icon = Icons.add;
        tooltip = '메모 추가';
        break;
      default:
        return null;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 48),
      child: FloatingActionButton(
        onPressed: onPressed,
        tooltip: tooltip,
        backgroundColor: Theme.of(context).primaryColor,
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  /// 하단 탭 탭 처리
  /// 메인 메뉴 탭 시 ①토큰 만료 검사(로컬) → ②서버 계정 존재 검사(다른 기기 탈퇴 감지).
  /// 만료/삭제면 자동 로그아웃(+삭제 시 로컬 데이터 정리) 후 재로그인 안내.
  void _checkTokenExpiryOnTap(BuildContext context, AppStateProvider appState) {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    void showRelogin(String message) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: '로그인',
            onPressed: () {
              navigator.push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ),
      );
    }

    appState.authService.enforceTokenValidity().then((expired) {
      if (!mounted) return;
      if (expired) {
        showRelogin('세션이 만료되어 로그아웃되었습니다. 다시 로그인해 주세요.');
        return;
      }
      // 토큰은 유효 → 서버에 계정이 아직 존재하는지 확인(다른 기기에서 탈퇴됐는지).
      // 계정이 삭제됐으면 이 기기도 로그아웃 + 로컬 데이터 삭제된다.
      appState.authService.enforceAccountValidity().then((deleted) {
        if (!mounted || !deleted) return;
        appState.resetAllDataAfterAccountDeletion(); // 화면의 메모리 데이터도 즉시 비움
        showRelogin('계정이 삭제되어 로그아웃되었습니다. (다른 기기에서 회원탈퇴)');
      });
    });
  }

  void _onTabTapped(BuildContext context, AppStateProvider appState, int index) {
    debugPrint('🔍 [MainTabScreen] 탭 터치: $index (현재: ${appState.selectedTabIndex})');

    // 메인 메뉴를 누를 때마다 토큰 만료 여부를 검사한다.
    // 로그인 상태인데 토큰이 만료됐으면 자동 로그아웃 + 재로그인 안내(스낵바).
    _checkTokenExpiryOnTap(context, appState);

    _logCurrentPlaybackState();

    // 캘린더·노트(+) 탭을 누르면 칩 바 가로 스크롤을 처음으로 되돌린다(스크롤 위치 유지로 정리 안 되는 문제 해결).
    if (index == _createTab || index == _calendarTab) {
      appState.requestChipScrollReset();
    }

    // 홈(채팅) 탭 진입 시 — 제목 카운트/칩·본문을 서버에서 새로고침(다른 탭 갔다 오면 최신 반영).
    if (index == _homeTab && appState.selectedTabIndex != _homeTab) {
      appState.loadShares(); // 내부에서 loadHiddenConvs 포함
      appState.loadSelfChats();
    }
    // 이미 홈(채팅) 탭인데 다시 누르면 열린 대화방을 닫고 채팅 목록 초기화면으로 돌아간다.
    // (다른 탭에서 올 때는 대화방 유지, 재탭할 때만 초기화)
    if (index == _homeTab && appState.selectedTabIndex == _homeTab) {
      appState.setHomeOpenConvKey(null);
    }

    // ⭐ 가운데 +(노트) 탭 → 노트로 전환만. 파일 생성은 노트 안의 + 버튼으로.
    if (index == _createTab) {
      appState.syncNoteTab(); // 노트 진입 시 클라우드 동기화
      // 다른 탭에서 노트로 진입할 때만 전체탭을 기본 활성화(노트 안에서 재탭 시엔 유지 — 녹음 등 중단 방지)
      if (appState.selectedTabIndex != _createTab) {
        appState.setCurrentWritingTab('all');
        appState.setTargetWritingTab('all');
      }
    }

    // 캘린더 탭 진입 처리
    if (index == _calendarTab) {
      debugPrint('📍 [MainTabScreen] 캘린더 탭 터치 - 이번 달로 이동');
      appState.clearDateSelection();
      appState.changeFocusedDate(DateTime.now());

      // 캘린더 탭 진입 시 서버 일정 새로고침(로그인 시) — 다른 기기에서 추가/수정한 일정 반영.
      // pull은 비동기라, 완료 후 캘린더 본문을 강제 리빌드해 새 일정이 즉시 보이게 한다.
      appState.refreshSchedulesFromServer().then((_) {
        _homeScreenKey.currentState?.forceRefresh();
      });

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


  void _logCurrentPlaybackState() {
    debugPrint('🎵 탭 변경 시 재생 상태 확인:');
    debugPrint('   - 오디오 재생 중: ${audioService.isPlaying}');
    debugPrint('   - 현재 재생 파일: ${audioService.currentPlayingFile?.fileName ?? "없음"}');
  }

  /// 선택된 탭 아이콘 하단에 언더라인을 표시한다.
  /// 비활성일 때도 동일 크기의 투명 언더라인으로 공간을 예약해 아이콘 세로 정렬이 흔들리지 않게 한다.
  Widget _withUnderline(BuildContext context, Widget icon, bool active) {
    final color = Theme.of(context).primaryColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 3),
        Container(
          width: 18,
          height: 2.5,
          decoration: BoxDecoration(
            color: active ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  /// 가운데 +(노트) 버튼 아이콘.
  /// 비활성: 연한 바탕 원 + 진한 테마색 +(테두리 없음).
  /// 활성: 진한 테마색 원 + 흰 +.
  Widget _buildAddIcon(BuildContext context, bool isActive) {
    final primary = Theme.of(context).primaryColor;
    // 라벨 공간을 0으로 없애 모든 아이콘이 세로 중앙 정렬되므로 별도 보정 패딩이 불필요.
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? primary : primary.withValues(alpha: 0.15),
      ),
      child: Icon(
        Icons.add,
        size: 26,
        color: isActive ? Colors.white : primary,
      ),
    );
  }

  // 리마인드(요약+퀴즈 통합) 탭 — 별표(반짝임) 요약 아이콘을 메인으로,
  // 우상단에 작은 전구(아이디어/퀴즈) 배지를 겹쳐 표현한다.
  // 색은 지정하지 않아 메인·배지 모두 BottomNavigationBar 상태색
  // (비선택 회색 / 선택 시 테마색)을 따른다.
  Widget _buildRemindIcon(bool isActive) {
    return SizedBox(
      width: 28,
      height: 26,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 요약(별) — 메인이지만 조금 작게, 좌하단
          Positioned(
            left: 0,
            bottom: 0,
            child: Icon(
              isActive ? Icons.auto_awesome : Icons.auto_awesome_outlined,
              size: 17,
            ),
          ),
          // 전구 안에 소문자 q(퀴즈) — 파일 리스트 퀴즈 아이콘과 동일, 우상단
          Positioned(
            top: 0,
            right: 0,
            child: SizedBox(
              width: 15,
              height: 15,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 채운 전구(색은 네비 선택/비선택 색 상속) + 흰 q
                  const Icon(Icons.lightbulb, size: 15),
                  Positioned(
                    top: 15 * 0.05,
                    child: const Text(
                      'q',
                      style: TextStyle(
                        fontSize: 15 * 0.52,
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

// 하단 네비 스터디룸 탭은 Icons.forum(겹친 말풍선)을 사용한다.
// (원형 말풍선 RoundChatBubbleIcon은 home_dashboard의 목록 제목에서 계속 사용)
