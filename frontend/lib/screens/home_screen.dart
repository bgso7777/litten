import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../l10n/app_localizations.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_state_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_storage_service.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/ad_banner.dart';
import '../widgets/home/schedule_picker.dart';
import '../widgets/home/notification_settings.dart';
import '../config/themes.dart';
import '../utils/responsive_utils.dart';
import '../utils/timezone_utils.dart';
import '../models/litten.dart';
import '../models/audio_file.dart';
import '../models/text_file.dart';
import '../models/handwriting_file.dart';
import '../widgets/dialogs/create_litten_dialog.dart';
import '../widgets/dialogs/edit_litten_dialog.dart';
import '../widgets/common/litten_unified_list_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  // ⭐ 정적 변수로 스크롤 위치 저장 (인스턴스가 재생성되어도 유지됨)
  static double? _globalScrollOffset;
  static bool _isFirstInit = true; // 첫 초기화 여부

  late final ScrollController _scrollController;
  int _currentTabIndex = 0; // 현재 활성화된 탭 인덱스 (0: 일정추가, 1: 알림설정)
  bool _userInteractedWithSchedule = false; // 사용자가 일정과 상호작용했는지 추적
  Map<String, Set<String>> _notificationDateCache = {}; // 날짜별 알림이 있는 리튼 ID Set (YYYY-MM-DD -> Set<littenId>)
  Set<String> _collapsedLittenIds = {}; // 숨겨진 리튼 ID Set
  late ValueNotifier<DateTime> _calendarFocusedDate; // 캘린더 focusedDate (스크롤 위치 유지용)
  bool _scheduleListVisible = false; // 일정 리스트 표시 여부 (false: 캘린더 전체화면, true: 50/50 분할)
  double? _pointerDownY;           // 터치 시작 Y 좌표 (글로벌 - 이동 거리 계산용)
  double? _pointerDownX;           // 터치 시작 X 좌표 (글로벌 - 이동 거리 계산용)
  double? _pointerDownLocalY;      // 터치 시작 Y 좌표 (로컬 - 캘린더/리스트 영역 판단용)
  double? _pointerDownListOffset;  // 터치 시작 시 리스트 스크롤 오프셋
  DateTime? _pointerDownTime;      // 터치 시작 시각 (속도 계산용)
  Timer? _chipRefreshTimer;        // 힌트 칩 1분 단위 갱신 타이머

  @override
  bool get wantKeepAlive => true; // 화면 회전 및 탭 전환 시에도 상태 유지

  @override
  void dispose() {
    _chipRefreshTimer?.cancel();

    // listener 제거
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    appState.removeListener(_syncCalendarFocusedDate);
    appState.notificationService.removeListener(_onNotificationChanged);

    // WidgetsBindingObserver 제거
    WidgetsBinding.instance.removeObserver(this);

    // 스크롤 위치 저장 (마지막 위치)
    if (_scrollController.hasClients) {
      _globalScrollOffset = _scrollController.offset;
      debugPrint('📜 HomeScreen dispose - 스크롤 위치 저장: $_globalScrollOffset');
    }

    _scrollController.dispose();
    _calendarFocusedDate.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    debugPrint('🔄 [HomeScreen] initState 호출 - 저장된 스크롤 위치: $_globalScrollOffset, 첫 초기화: $_isFirstInit');

    // 스크롤 컨트롤러 초기화 (저장된 위치가 있으면 그 위치로 시작)
    _scrollController = ScrollController(
      initialScrollOffset: _globalScrollOffset ?? 0.0,
    );

    // WidgetsBindingObserver 추가 (화면 회전 감지)
    WidgetsBinding.instance.addObserver(this);

    // 캘린더 focusedDate 초기화
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    _calendarFocusedDate = ValueNotifier<DateTime>(appState.focusedDate);

    // appState.focusedDate 변경 시 _calendarFocusedDate 동기화
    appState.addListener(_syncCalendarFocusedDate);

    // 알림 상태 변화(발생·해제) 시 캘린더 뱃지 갱신
    appState.notificationService.addListener(_onNotificationChanged);

    // 스크롤 컨트롤러 리스너 추가 (스크롤 위치 자동 저장)
    _scrollController.addListener(_onScroll);

    // 화면 로드 후 필요한 데이터 로드 (첫 실행 시에만)
    if (_isFirstInit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('📜 [HomeScreen] 첫 실행 - 데이터 로드');
        _callInstallApiIfNeeded();
        _loadNotificationDates();
        _loadCollapsedLittenIds();
      });
      _isFirstInit = false;
    } else {
      debugPrint('🔄 [HomeScreen] 재초기화 - 스크롤 위치 유지 ($_globalScrollOffset)');
    }

    // 힌트 칩 갱신 타이머 시작 (0분이면 10초, 그 외엔 1분 간격)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleChipRefresh();
    });
  }

  /// 힌트 칩 갱신 타이머 - 60초 미만이면 10초, 그 외엔 1분 간격으로 자기 재귀
  void _scheduleChipRefresh() {
    if (!mounted) return;
    _chipRefreshTimer?.cancel();
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final hint = _getScheduleHint(appState.littens, appState.locale.languageCode);
    final isUnder1Min = hint.secondsUntilToday != null && hint.secondsUntilToday! < 60;
    final interval = isUnder1Min ? const Duration(seconds: 10) : const Duration(minutes: 1);
    debugPrint('⏱️ [HomeScreen] 힌트 칩 타이머 설정: ${isUnder1Min ? "10초" : "1분"} (secondsUntilToday: ${hint.secondsUntilToday})');
    _chipRefreshTimer = Timer(interval, () {
      if (!mounted) return;
      setState(() {});
      debugPrint('⏱️ [HomeScreen] 힌트 칩 갱신 완료 (${isUnder1Min ? "10초" : "1분"} 모드)');
      _scheduleChipRefresh();
    });
  }

  /// 스크롤 리스너 - 스크롤 위치 자동 저장
  void _onScroll() {
    if (_scrollController.hasClients) {
      final oldOffset = _globalScrollOffset;
      _globalScrollOffset = _scrollController.offset;

      // PageStorage에도 저장
      PageStorage.of(context)?.writeState(context, _scrollController.offset, identifier: 'home_screen_scroll');

      // 100픽셀마다 로그 출력 (너무 많은 로그 방지)
      if (oldOffset == null || (oldOffset - _globalScrollOffset!).abs() > 100) {
        debugPrint('📜 [HomeScreen] 스크롤 위치 저장: $_globalScrollOffset');
      }
    }
  }

  /// 화면 회전 감지 (WidgetsBindingObserver)
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // 화면 회전 시 캘린더가 보이도록 스크롤을 맨 위로
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToTop();
      debugPrint('📱 화면 회전 감지 - 캘린더 표시 (스크롤 맨 위)');
    });
  }

  /// 앱 라이프사이클 변화 감지 (WidgetsBindingObserver)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('🔄 [HomeScreen] 앱 라이프사이클 변화: $state');

    if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드로 돌아올 때 알림 날짜 캐시 갱신
      debugPrint('▶️ [HomeScreen] 앱 재개 - 알림 뱃지 갱신');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadNotificationDates();
        }
      });
    }
  }

  /// 알림 상태 변화 시 캘린더 뱃지 캐시 갱신
  void _onNotificationChanged() {
    if (mounted) _loadNotificationDates();
  }

  /// appState.focusedDate가 변경되면 _calendarFocusedDate 동기화
  void _syncCalendarFocusedDate() {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    if (_calendarFocusedDate.value != appState.focusedDate) {
      _calendarFocusedDate.value = appState.focusedDate;
    }
  }

  /// 외부(홈 일정)에서 캘린더로 이동했을 때, 선택된 날짜가 보이도록 포커스 월을 맞추고
  /// 캘린더를 다시 그려 해당 날짜의 칩(일정)이 펼쳐지게 한다.
  /// 외부(홈 일정)에서 캘린더로 이동했을 때, 캘린더 탭을 누른 것처럼
  /// 하단 일정 리스트를 위로 펼쳐서(전체 일정) 보여준다.
  void expandScheduleList() {
    if (!mounted) return;
    if (!_scheduleListVisible) {
      setState(() => _scheduleListVisible = true);
    }
    debugPrint('📅 [HomeScreen] 외부 진입 → 일정 리스트 펼침');
  }

  /// 외부에서 캘린더 날짜를 오늘로 변경하고 스크롤을 맨 위로
  void goToToday() {
    final now = DateTime.now();
    _calendarFocusedDate.value = DateTime(now.year, now.month, now.day);
    scrollToTop(); // 캘린더가 보이도록 맨 위로 스크롤
    debugPrint('📅 오늘 날짜로 이동 + 캘린더 표시: ${now.year}년 ${now.month}월 ${now.day}일');
  }

  /// 스크롤을 맨 위로 이동 (캘린더 표시)
  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      debugPrint('📜 스크롤을 맨 위로 이동 - 캘린더 표시');
    }
  }

  /// 일정 기간 시작일 반환 (선택된 리튼 또는 모든 리튼)
  /// 숨겨진 리튼 ID 목록 로드
  Future<void> _loadCollapsedLittenIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final collapsedIds = prefs.getStringList('collapsed_litten_ids');

      if (!mounted) return;

      // ⭐ 저장된 값이 없으면 모든 리튼을 기본적으로 숨김 상태로 설정
      if (collapsedIds == null) {
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        final allLittenIds = appState.littens.map((litten) => litten.id).toSet();

        setState(() {
          _collapsedLittenIds = allLittenIds;
        });

        // SharedPreferences에 저장
        await prefs.setStringList('collapsed_litten_ids', _collapsedLittenIds.toList());
        debugPrint('📂 모든 리튼을 기본 숨김 상태로 설정: ${_collapsedLittenIds.length}개');
      } else {
        setState(() {
          _collapsedLittenIds = collapsedIds.toSet();
        });
        debugPrint('📂 숨겨진 리튼 ID 로드: ${_collapsedLittenIds.length}개');
      }
    } catch (e) {
      debugPrint('❌ 숨겨진 리튼 ID 로드 실패: $e');
    }
  }

  /// 캘린더 탭에서 일정이 선택되지 않았으면 undefined 자동 선택
  void autoSelectUndefinedIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      if (appState.selectedLitten == null) {
        final undefinedLitten = appState.littens.where((l) => l.title == 'undefined').firstOrNull;
        if (undefinedLitten != null) {
          debugPrint('✅ [HomeScreen] undefined 리튼 자동 선택');
          appState.selectLitten(undefinedLitten);
        }
      }
    });
  }

  /// 리튼 숨김/보이기 토글
  Future<void> _toggleLittenCollapse(String littenId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        if (_collapsedLittenIds.contains(littenId)) {
          _collapsedLittenIds.remove(littenId);
        } else {
          _collapsedLittenIds.add(littenId);
        }
      });

      // SharedPreferences에 저장
      await prefs.setStringList('collapsed_litten_ids', _collapsedLittenIds.toList());

      debugPrint('📂 리튼 숨김 토글: $littenId (숨김: ${_collapsedLittenIds.contains(littenId)})');
    } catch (e) {
      debugPrint('❌ 리튼 숨김 토글 실패: $e');
    }
  }

  /// 알림 날짜 캐시 로드
  /// 리튼 스케줄을 직접 기반으로 뱃지 계산 (StoredNotification 미생성 문제 우회)
  Future<void> _loadNotificationDates() async {
    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      final storage = NotificationStorageService();

      // 저장된 알림에서 리튼별 확인 상태 계산
      final allNotifications = await storage.loadNotifications();
      final Map<String, bool> storageAcknowledged = {};
      for (final litten in appState.littens) {
        final littenNotifs = allNotifications.where((n) => n.littenId == litten.id).toList();
        if (littenNotifs.isNotEmpty) {
          storageAcknowledged[litten.id] = littenNotifs.every((n) => n.isAcknowledged);
        }
      }

      // SharedPreferences에서 수동으로 닫은 리튼 ID 읽기
      final prefs = await SharedPreferences.getInstance();
      final manuallyDismissed = prefs.getStringList('badge_dismissed_litten_ids')?.toSet() ?? {};

      if (!mounted) return;

      // ⭐ 발생한 알림(firedNotifications)만 뱃지로 표시
      // 저장소의 미리 생성된 알림은 무시 (실제 발생 시점까지 뱃지 표시 안 함)
      final dateMap = <String, Set<String>>{};

      // NotificationService에서 발생한 알림 가져오기
      final firedNotifications = appState.notificationService.firedNotifications;

      debugPrint('📅 뱃지 계산: 발생한 알림 ${firedNotifications.length}개');

      for (final notification in firedNotifications) {
        final litten = appState.littens.where((l) => l.id == notification.littenId).firstOrNull;
        if (litten == null) continue;

        // 수동으로 닫힌 리튼은 건너뜀
        if (manuallyDismissed.contains(litten.id)) {
          debugPrint('   ⏭️ 수동으로 닫힌 리튼 건너뜀: ${litten.title}');
          continue;
        }

        // 발생 시간 기준으로 날짜 키 생성
        final dateKey = DateFormat('yyyy-MM-dd').format(notification.triggerTime);
        dateMap.putIfAbsent(dateKey, () => {}).add(litten.id);
        debugPrint('   ✅ 뱃지 추가: ${litten.title} - $dateKey');
      }

      setState(() {
        _notificationDateCache = dateMap;
      });

      // 오늘 날짜의 스케줄 뱃지 수를 NotificationService에 반영 → 하단 탭 뱃지 업데이트
      final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayBadgeCount = (dateMap[todayKey] ?? {}).length;
      appState.notificationService.updateScheduleBadgeCount(todayBadgeCount);

      debugPrint('📅 알림 날짜 캐시 로드 완료: ${_notificationDateCache.length}개 날짜, 오늘 뱃지: $todayBadgeCount');
    } catch (e) {
      debugPrint('❌ 알림 날짜 캐시 로드 실패: $e');
    }
  }

  /// 선택된 날짜의 일정 목록 로드 (알림 설정 여부와 관계없이 모든 일정)
  Future<void> _loadNotificationsForSelectedDate(DateTime date, AppStateProvider appState) async {
    try {
      debugPrint('📅 _loadNotificationsForSelectedDate 시작: ${DateFormat('yyyy-MM-dd').format(date)}');

      final targetDate = DateTime(date.year, date.month, date.day);
      final schedulesWithLitten = <Map<String, dynamic>>[];

      // 모든 리튼을 순회하며 선택된 날짜에 해당하는 일정이 있는지 확인
      for (final litten in appState.littens) {
        if (litten.schedule == null) {
          continue;
        }

        final schedule = litten.schedule!;
        final scheduleDate = DateTime(
          schedule.date.year,
          schedule.date.month,
          schedule.date.day,
        );

        // 시작일이 선택된 날짜와 일치하는지 확인
        if (scheduleDate.isAtSameMomentAs(targetDate)) {
          // 일정의 시작 시간을 DateTime으로 변환
          final scheduleStartDateTime = DateTime(
            schedule.date.year,
            schedule.date.month,
            schedule.date.day,
            schedule.startTime.hour,
            schedule.startTime.minute,
          );

          schedulesWithLitten.add({
            'litten': litten,
            'schedule': schedule,
            'startDateTime': scheduleStartDateTime,
          });

          debugPrint('   ✅ 일정 발견: "${litten.title}" - ${DateFormat('HH:mm').format(scheduleStartDateTime)}');
        }
      }

      // 시작 시간순으로 정렬
      schedulesWithLitten.sort((a, b) {
        final aTime = a['startDateTime'] as DateTime;
        final bTime = b['startDateTime'] as DateTime;
        return aTime.compareTo(bTime);
      });

      // AppStateProvider에 일정 설정 (notifyListeners 자동 호출)
      appState.setSelectedDateNotifications(schedulesWithLitten);
      debugPrint('📋 선택된 날짜(${DateFormat('yyyy-MM-dd').format(date)})의 일정: ${schedulesWithLitten.length}개');
      debugPrint('🔍 AppState 업데이트 완료: selectedDateNotifications.length = ${appState.selectedDateNotifications.length}');
    } catch (e) {
      debugPrint('❌ 선택된 날짜 일정 로드 실패: $e');
      appState.setSelectedDateNotifications([]);
    }
  }

  /// 앱 설치 후 처음 홈탭 진입 시 install API 호출
  Future<void> _callInstallApiIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCalledInstallApi = prefs.getBool('has_called_install_api') ?? false;

      if (!hasCalledInstallApi) {
        debugPrint('[HomeScreen] 🚀 처음 홈탭 진입 - install API 호출 시작');

        // UUID 가져오기
        final authService = AuthServiceImpl();
        final uuid = await authService.getDeviceUuid();
        debugPrint('[HomeScreen] UUID: $uuid');

        // install API 호출
        final response = await ApiService().registerUuid(uuid: uuid);
        debugPrint('[HomeScreen] install API 응답: $response');

        // 성공 시 플래그 저장
        if (response['result'] == 1) {
          await prefs.setBool('has_called_install_api', true);
          debugPrint('[HomeScreen] ✅ install API 호출 성공 - 플래그 저장 완료');
        } else {
          debugPrint('[HomeScreen] ⚠️ install API 호출 실패 - result: ${response['result']}');
        }
      } else {
        debugPrint('[HomeScreen] ℹ️ install API 이미 호출됨 - 스킵');
      }
    } catch (e) {
      debugPrint('[HomeScreen] ❌ install API 호출 중 오류: $e');
    }
  }

  void showCreateLittenDialog() {
    final l10n = AppLocalizations.of(context);
    final appState = Provider.of<AppStateProvider>(context, listen: false);

    if (!appState.canCreateMoreLittens) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.freeUserLimitMessage ?? '무료 사용자는 최대 5개의 리튼만 생성할 수 있습니다. 업그레이드하여 무제한으로 생성하세요!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 캘린더의 일정 추가(+) 버튼 — 다이얼로그를 열기 전에 일정 개수 제한을 먼저 체크
    final scheduleBlock = appState.scheduleBlockReason();
    if (scheduleBlock != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(scheduleBlock),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => CreateLittenDialog(
        appState: appState,
        onScheduleIndexChanged: (index) {
          _currentTabIndex = index;
        },
      ),
    ).then((_) {
      // 다이얼로그가 닫힐 때 알림 날짜 캐시 갱신
      _loadNotificationDates();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수 호출
    debugPrint('🔄 [HomeScreen] build 호출 - 저장된 스크롤 위치: $_globalScrollOffset, 컨트롤러 연결: ${_scrollController.hasClients}');
    final l10n = AppLocalizations.of(context);

    // ⭐ appState는 구독 상태 확인을 위해 listen: true로 변경
    final appState = Provider.of<AppStateProvider>(context);

    // ⭐ build가 호출될 때마다 스크롤 위치 복원 시도
    if (_globalScrollOffset != null && _globalScrollOffset! > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final currentOffset = _scrollController.offset;
          if (currentOffset != _globalScrollOffset && currentOffset < 1.0) {
            // 현재 위치가 맨 위(0 근처)이고 저장된 위치와 다르면 복원
            final maxScrollExtent = _scrollController.position.maxScrollExtent;
            final targetOffset = _globalScrollOffset! > maxScrollExtent
                ? maxScrollExtent
                : _globalScrollOffset!;

            _scrollController.jumpTo(targetOffset);
            debugPrint('✅ [HomeScreen] build 후 스크롤 위치 복원: $targetOffset (저장: $_globalScrollOffset)');
          }
        }
      });
    }

    return RefreshIndicator(
      onRefresh: () async {
        await appState.refreshLittens();
        setState(() {});
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 칩 위젯 높이를 제외한 영역 (캘린더 + 일정 목록)
          // 칩 높이는 약 38px (vertical padding 6 + text 약 26)
          const double chipHeight = 38.0;
          final totalHeight = constraints.maxHeight - chipHeight;
          final halfHeight = totalHeight / 2;

          return Column(
            children: [
              Expanded(
                child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) {
              _pointerDownY = event.position.dy;
              _pointerDownX = event.position.dx;
              _pointerDownLocalY = event.localPosition.dy;
              _pointerDownTime = DateTime.now();
              _pointerDownListOffset = _scrollController.hasClients ? _scrollController.offset : 0;
            },
            onPointerUp: (event) {
              if (_pointerDownY == null || _pointerDownX == null || _pointerDownTime == null) return;
              if (!mounted) return;

              final dy = event.position.dy - _pointerDownY!;
              final dx = event.position.dx - _pointerDownX!;
              final dt = DateTime.now().difference(_pointerDownTime!).inMilliseconds.clamp(16, 1000);
              final velocityY = (dy / dt) * 1000; // px/s (양수=아래, 음수=위)

              debugPrint('📅 [Listener] dx=$dx dy=$dy velocityY=${velocityY.toStringAsFixed(0)} visible=$_scheduleListVisible offset=$_pointerDownListOffset');

              // 로컬 좌표 기준으로 캘린더/리스트 영역 판단 (광고 유무와 무관하게 정확)
              final startedInCalendar = (_pointerDownLocalY ?? _pointerDownY!) < halfHeight;
              final isHorizontalSwipe = dx.abs() > dy.abs() && dx.abs() > 40;

              // 좌로 스와이프 → 노트(쓰기) 탭으로 이동 (리스트 영역에서만)
              if (_scheduleListVisible && isHorizontalSwipe && dx < -40 && !startedInCalendar) {
                debugPrint('📅 [HomeScreen] 좌 스와이프 → 노트 탭 이동');
                final currentAppState = Provider.of<AppStateProvider>(context, listen: false);
                currentAppState.changeTabIndex(1);
                currentAppState.setCurrentMainTab(1);
              }
              // 위로 스와이프 → 리스트 표시 (캘린더 전체화면일 때)
              else if (!_scheduleListVisible && velocityY < -300 && dy < -30) {
                debugPrint('📅 [HomeScreen] 리스트 표시');
                setState(() { _scheduleListVisible = true; });
                // ⭐ 자동 일정 선택 제거됨
              }
              // 아래로 스와이프 → 리스트 숨김
              else if (_scheduleListVisible && velocityY > 300 && dy > 30 && !isHorizontalSwipe) {
                final startedInListAtTop = !startedInCalendar && (_pointerDownListOffset ?? 0) <= 5;
                debugPrint('📅 [HomeScreen] 다운 스와이프 - calendar=$startedInCalendar listTop=$startedInListAtTop');
                if (startedInCalendar || startedInListAtTop) {
                  setState(() { _scheduleListVisible = false; });
                }
              }

              _pointerDownY = null;
              _pointerDownX = null;
              _pointerDownLocalY = null;
              _pointerDownTime = null;
              _pointerDownListOffset = null;
            },
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                // 캘린더: 초기 전체화면 → 위로 스와이프 시 상단 50%
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _scheduleListVisible ? halfHeight : totalHeight,
                  child: _buildCalendarContent(appState, l10n),
                ),
                // 일정 리스트: 초기 화면 밖 → 위로 스와이프 시 하단 50%로 슬라이드 업
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  top: _scheduleListVisible ? halfHeight : totalHeight + 20,
                  left: 0,
                  right: 0,
                  height: halfHeight,
                  child: Column(
                    children: [
                      // 드래그 핸들 (영역 30% 축소, 가운데 바는 유지)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragEnd: (d) {
                          final velocityY = d.velocity.pixelsPerSecond.dy;
                          if (velocityY > 300) {
                            setState(() { _scheduleListVisible = false; });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              topRight: Radius.circular(10),
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // 일정 목록
                      Expanded(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (!_scheduleListVisible) return false;
                            // BouncingScrollPhysics 바운스 감지 (보조 수단)
                            if (notification is ScrollUpdateNotification &&
                                notification.metrics.pixels < 0) {
                              setState(() { _scheduleListVisible = false; });
                              return true;
                            }
                            if (notification is OverscrollNotification &&
                                notification.overscroll < -5) {
                              setState(() { _scheduleListVisible = false; });
                              return true;
                            }
                            return false;
                          },
                          child: LittenUnifiedListView(
                            key: const PageStorageKey<String>('home_screen_scroll'),
                            scrollController: _scrollController,
                            padding: const EdgeInsets.only(left: 0, right: 0, top: 0, bottom: 80),
                            onListExpand: null, // ⭐ 자동 일정 선택 제거됨
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
                ),
              ),
              ),
              // 화면 하단에 항상 고정되는 칩 위젯 (리마인더 칩처럼)
              _buildScheduleHintChip(appState),
            ],
          );
        },
      ),
    );
  }

  void _showRenameLittenDialog(String littenId, String currentTitle) {
    _showEditLittenDialog(littenId);
  }

  void _showEditLittenDialog(String littenId) {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final currentLitten = appState.littens.firstWhere((litten) => litten.id == littenId);

    showDialog(
      context: context,
      builder: (context) => EditLittenDialog(
        litten: currentLitten,
        onScheduleIndexChanged: (index) {
          _currentTabIndex = index;
        },
      ),
    ).then((_) {
      // 다이얼로그가 닫힐 때 알림 날짜 캐시 갱신
      _loadNotificationDates();
    });
  }

  Widget _buildScheduleTabView({
    required Litten currentLitten,
    required LittenSchedule? selectedSchedule,
    required Function(LittenSchedule?) onScheduleChanged,
  }) {
    return DefaultTabController(
      length: 2,
      initialIndex: _currentTabIndex,
      child: StatefulBuilder(
        builder: (context, setState) {
          // 실제로 의미 있는 일정이 설정되어 있는지 확인 (기존 리튼에 일정이 있었던 경우만)
          final bool hasSchedule = selectedSchedule != null && currentLitten.schedule != null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 탭바
              TabBar(
                labelColor: hasSchedule ? Theme.of(context).primaryColor : Colors.grey,
                unselectedLabelColor: Colors.grey,
                indicator: hasSchedule
                    ? UnderlineTabIndicator(
                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                      )
                    : null,
                onTap: (index) {
                  _currentTabIndex = index;
                },
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          hasSchedule ? Icons.check_box : Icons.check_box_outline_blank,
                          size: 16,
                          color: hasSchedule ? Theme.of(context).primaryColor : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.alarm, size: 16),
                        const SizedBox(width: 4),
                        Text('일정추가'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          (hasSchedule && selectedSchedule?.notificationRules.isNotEmpty == true)
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                          size: 16,
                          color: (hasSchedule && selectedSchedule?.notificationRules.isNotEmpty == true)
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.notifications,
                          size: 16,
                          color: hasSchedule ? null : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '알림설정',
                          style: TextStyle(
                            color: hasSchedule ? null : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 탭 내용
              Expanded(
                child: TabBarView(
                  physics: hasSchedule ? null : const NeverScrollableScrollPhysics(),
                  children: [
                    // 일정추가 탭
                    _buildScheduleTab(
                      currentLitten: currentLitten,
                      selectedSchedule: selectedSchedule,
                      onScheduleChanged: onScheduleChanged,
                    ),
                    // 알림설정 탭
                    hasSchedule
                        ? _buildNotificationTab(
                            selectedSchedule: selectedSchedule!,
                            onScheduleChanged: onScheduleChanged,
                          )
                        : _buildDisabledNotificationTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScheduleTab({
    required Litten currentLitten,
    required LittenSchedule? selectedSchedule,
    required Function(LittenSchedule?) onScheduleChanged,
  }) {
    return SingleChildScrollView(
      child: SchedulePicker(
        defaultDate: currentLitten.createdAt,
        initialSchedule: selectedSchedule,
        onScheduleChanged: onScheduleChanged,
        showNotificationSettings: false, // 알림 설정은 별도 탭에서
      ),
    );
  }

  Widget _buildNotificationTab({
    required LittenSchedule selectedSchedule,
    required Function(LittenSchedule?) onScheduleChanged,
  }) {
    return SingleChildScrollView(
      child: NotificationSettings(
        initialRules: selectedSchedule.notificationRules,
        scheduleDate: selectedSchedule.date, // 일정 시작일자 전달
        onRulesChanged: (rules) {
          final updatedSchedule = LittenSchedule(
            date: selectedSchedule.date,
            endDate: selectedSchedule.endDate,
            startTime: selectedSchedule.startTime,
            endTime: selectedSchedule.endTime,
            notes: selectedSchedule.notes,
            notificationRules: rules,
          );
          onScheduleChanged(updatedSchedule);
        },
      ),
    );
  }

  Widget _buildDisabledNotificationTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '일정을 먼저 설정해주세요',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '일정추가 탭에서 일정을 설정하면\n알림 설정을 할 수 있습니다',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCreateScheduleTabView({
    required AppStateProvider appState,
    required LittenSchedule? selectedSchedule,
    required Function(LittenSchedule?) onScheduleChanged,
  }) {
    return DefaultTabController(
      length: 2,
      initialIndex: _currentTabIndex,
      child: StatefulBuilder(
        builder: (context, setState) {
          // 새로 생성하는 리튼의 경우 사용자가 명시적으로 일정을 설정했는지 확인
          final bool hasSchedule = _userInteractedWithSchedule && selectedSchedule != null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 탭바
              TabBar(
                labelColor: hasSchedule ? Theme.of(context).primaryColor : Colors.grey,
                unselectedLabelColor: Colors.grey,
                indicator: hasSchedule
                    ? UnderlineTabIndicator(
                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                      )
                    : null,
                onTap: (index) {
                  _currentTabIndex = index;
                },
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          hasSchedule ? Icons.check_box : Icons.check_box_outline_blank,
                          size: 16,
                          color: hasSchedule ? Theme.of(context).primaryColor : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.alarm, size: 16),
                        const SizedBox(width: 4),
                        Text('일정추가'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          (hasSchedule && selectedSchedule?.notificationRules.isNotEmpty == true)
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                          size: 16,
                          color: (hasSchedule && selectedSchedule?.notificationRules.isNotEmpty == true)
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.notifications,
                          size: 16,
                          color: hasSchedule ? null : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '알림설정',
                          style: TextStyle(
                            color: hasSchedule ? null : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 탭 내용
              Expanded(
                child: TabBarView(
                  physics: hasSchedule ? null : const NeverScrollableScrollPhysics(),
                  children: [
                    // 일정추가 탭
                    _buildCreateScheduleTab(
                      appState: appState,
                      selectedSchedule: selectedSchedule,
                      onScheduleChanged: onScheduleChanged,
                    ),
                    // 알림설정 탭
                    hasSchedule
                        ? _buildCreateNotificationTab(
                            selectedSchedule: selectedSchedule!,
                            onScheduleChanged: onScheduleChanged,
                          )
                        : _buildDisabledNotificationTab(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCreateScheduleTab({
    required AppStateProvider appState,
    required LittenSchedule? selectedSchedule,
    required Function(LittenSchedule?) onScheduleChanged,
  }) {
    return SingleChildScrollView(
      child: SchedulePicker(
        defaultDate: appState.selectedDate,
        initialSchedule: selectedSchedule,
        onScheduleChanged: onScheduleChanged,
        showNotificationSettings: false, // 알림 설정은 별도 탭에서
        isCreatingNew: true, // 새로 생성하는 리튼임을 표시
      ),
    );
  }

  Widget _buildCreateNotificationTab({
    required LittenSchedule selectedSchedule,
    required Function(LittenSchedule?) onScheduleChanged,
  }) {
    return SingleChildScrollView(
      child: NotificationSettings(
        initialRules: selectedSchedule.notificationRules,
        scheduleDate: selectedSchedule.date, // 일정 시작일자 전달
        onRulesChanged: (rules) {
          final updatedSchedule = LittenSchedule(
            date: selectedSchedule.date,
            endDate: selectedSchedule.endDate,
            startTime: selectedSchedule.startTime,
            endTime: selectedSchedule.endTime,
            notes: selectedSchedule.notes,
            notificationRules: rules,
          );
          onScheduleChanged(updatedSchedule);
        },
      ),
    );
  }

  Future<bool> _performEditLitten(
    String littenId,
    String newTitle,
    LittenSchedule? newSchedule,
    BuildContext dialogContext,
    TextEditingController titleController,
  ) async {
    final l10n = AppLocalizations.of(context);

    // 입력 유효성 검사
    if (newTitle.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.pleaseEnterTitle ?? '제목을 입력해주세요.')),
        );
      }
      return false; // 유효성 검사 실패 시 다이얼로그를 닫지 않음
    }

    // 스케줄 유효성 검사
    if (newSchedule != null) {
      final startTime = newSchedule.startTime;
      final endTime = newSchedule.endTime;
      if (startTime.hour == endTime.hour && startTime.minute >= endTime.minute) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('시작 시간이 종료 시간보다 늦을 수 없습니다.')),
          );
        }
        return false; // 유효성 검사 실패 시 다이얼로그를 닫지 않음
      }
    }

    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      debugPrint('🔄 리튼 수정 시작: $littenId - ${newTitle.trim()}');

      // 기존 리튼 찾기
      final currentLitten = appState.littens.firstWhere((litten) => litten.id == littenId);

      // 수정된 리튼 생성
      final updatedLitten = Litten(
        id: currentLitten.id,
        title: newTitle.trim(),
        description: currentLitten.description, // 기존 설명 유지
        createdAt: currentLitten.createdAt,
        updatedAt: DateTime.now(),
        audioFileIds: currentLitten.audioFileIds,
        textFileIds: currentLitten.textFileIds,
        handwritingFileIds: currentLitten.handwritingFileIds,
        schedule: newSchedule,
      );

      // 리튼 업데이트
      await appState.updateLitten(updatedLitten);

      if (mounted) {
        debugPrint('✅ 리튼 수정 완료: ${updatedLitten.id}');
      }
      return true; // 성공 시 다이얼로그를 닫음
    } catch (e) {
      debugPrint('❌ 리튼 수정 에러: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('${l10n?.error ?? '오류'}: $e')),
        );
      }
      return false; // 실패 시 다이얼로그를 닫지 않음
    }
  }

  void _performRename(String littenId, String newTitle, TextEditingController controller, BuildContext dialogContext) async {
    final l10n = AppLocalizations.of(context);
    if (newTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.pleaseEnterTitle ?? '제목을 입력해주세요.')),
      );
      return;
    }
    
    // 현재 제목과 동일한 경우 변경하지 않음
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final currentLitten = appState.littens.firstWhere((litten) => litten.id == littenId);
    if (newTitle == currentLitten.title) {
      Navigator.of(dialogContext).pop();
      return;
    }
    final navigator = Navigator.of(dialogContext);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      await appState.renameLitten(littenId, newTitle);
      navigator.pop();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('${l10n?.error ?? '오류'}: $e')),
      );
    }
  }

  // 캘린더 섹션 빌드
  Widget _buildCalendarSection(AppStateProvider appState, AppLocalizations? l10n) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.paddingM.left,
        right: AppSpacing.paddingM.left,
        top: 0,
        bottom: 16, // 하단 패딩 추가하여 캘린더 영역 확보
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 월 네비게이션 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  final previousMonth = DateTime(
                    appState.focusedDate.year,
                    appState.focusedDate.month - 1,
                  );
                  appState.changeFocusedDate(previousMonth);
                },
                icon: const Icon(Icons.chevron_left),
                tooltip: '이전 달',
              ),
              Text(
                DateFormat.yMMMM(appState.locale.languageCode).format(appState.focusedDate),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: (Theme.of(context).textTheme.headlineSmall?.fontSize ?? 24) - 2,
                ),
              ),
              IconButton(
                onPressed: () {
                  final nextMonth = DateTime(
                    appState.focusedDate.year,
                    appState.focusedDate.month + 1,
                  );
                  appState.changeFocusedDate(nextMonth);
                },
                icon: const Icon(Icons.chevron_right),
                tooltip: '다음 달',
              ),
            ],
          ),
          // 캘린더
          Stack(
            children: [
              Transform.scale(
                scale: 0.95, // 캘린더를 95% 크기로 축소 (간격 최소화)
                child: TableCalendar<dynamic>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: appState.focusedDate,
                daysOfWeekHeight: ResponsiveUtils.getCalendarDaysOfWeekHeight(context),
                rowHeight: ResponsiveUtils.getCalendarRowHeight(context),

                selectedDayPredicate: (day) {
                  // 날짜가 선택된 경우에만 선택 표시
                  if (!appState.isDateSelected) return false;
                  return isSameDay(appState.selectedDate, day);
                },
                onDaySelected: (selectedDay, focusedDay) async {
                  appState.selectDate(selectedDay);
                  appState.changeFocusedDate(focusedDay);
                  // 선택된 날짜의 알림 로드 (자동으로 notifyListeners 호출됨)
                  await _loadNotificationsForSelectedDate(selectedDay, appState);
                },
                onPageChanged: (focusedDay) {
                  appState.changeFocusedDate(focusedDay);
                },
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                },
                headerVisible: false, // 커스텀 헤더를 사용하므로 기본 헤더 숨김
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(fontWeight: FontWeight.bold),
                  weekendStyle: TextStyle(fontWeight: FontWeight.bold),
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: const TextStyle(color: Colors.black),
                  holidayTextStyle: TextStyle(color: Colors.red[400]),
                  // selectedDecoration과 todayDecoration 제거 - builder 사용
                  selectedDecoration: const BoxDecoration(),
                  todayDecoration: const BoxDecoration(),
                  // 전체 화면에서는 마커(점) 숨김
                  markerDecoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  markersMaxCount: 0,
                ),
                eventLoader: (day) {
                  // 전체 화면에서는 마커(점)를 표시하지 않음
                  return [];
                },
                locale: appState.locale.languageCode,
                calendarBuilders: CalendarBuilders(
                  // 요일 헤더 빌더 - 토요일은 검은색, 일요일은 빨간색
                  dowBuilder: (context, day) {
                    final text = DateFormat.E(appState.locale.languageCode).format(day);
                    return Center(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: day.weekday == DateTime.sunday ? Colors.red : Colors.black,
                        ),
                      ),
                    );
                  },
                  // 기본 셀 빌더 - 날짜 아래에 리튼 제목 표시
                  defaultBuilder: (context, day, focusedDay) {
                    return Container(
                      margin: const EdgeInsets.all(4.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            '${day.day}',
                            style: const TextStyle().copyWith(
                              fontWeight: FontWeight.bold,
                              color: day.weekday == DateTime.sunday ? Colors.red : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    // 해당 날짜의 리튼 찾기
                    final targetDate = DateTime(day.year, day.month, day.day);
                    final littensOnDate =
                        _littensOccurringOn(appState.littens, targetDate);

                    // 리튼 제목 (최대 1개만 표시) — 같은 날짜에 2개 이상이면
                    // 앞으로 도래할 가장 가까운 일정을 우선 표시
                    final littenTitle = _pickUpcomingChipTitle(littensOnDate);

                    return Container(
                      margin: const EdgeInsets.all(4.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // 원형 배경의 날짜
                          Container(
                            width: 21,
                            height: 21,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: const TextStyle().copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          if (littenTitle != null) ...[
                            const SizedBox(height: 2),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                littenTitle,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                  todayBuilder: (context, day, focusedDay) {
                    // 해당 날짜의 리튼 찾기
                    final targetDate = DateTime(day.year, day.month, day.day);
                    final littensOnDate =
                        _littensOccurringOn(appState.littens, targetDate);

                    // 리튼 제목 (최대 1개만 표시) — 같은 날짜에 2개 이상이면
                    // 앞으로 도래할 가장 가까운 일정을 우선 표시
                    final littenTitle = _pickUpcomingChipTitle(littensOnDate);

                    return Container(
                      margin: const EdgeInsets.all(4.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // 원형 배경의 날짜
                          Container(
                            width: 21,
                            height: 21,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: const TextStyle().copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          if (littenTitle != null) ...[
                            const SizedBox(height: 2),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                littenTitle,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            // 일정 바 오버레이
            Positioned.fill(
              child: _buildScheduleBars(appState),
            ),
          ],
        ),
        ],
      ),
    );
  }

  /// 특정 날짜(셀)에 표시할 일정(리튼) 목록.
  /// - 생성(기준) 날짜가 해당 날짜와 같으면 포함
  /// - 매주 반복(요일 지정) 일정은 기준 날짜 이후의 해당 요일마다 발생하므로 포함
  /// ('undefined' 리튼 제외)
  List<Litten> _littensOccurringOn(List<Litten> littens, DateTime day) {
    final target = DateTime(day.year, day.month, day.day);
    return littens.where((l) {
      if (l.title == 'undefined') return false;
      final created =
          DateTime(l.createdAt.year, l.createdAt.month, l.createdAt.day);
      if (created.isAtSameMomentAs(target)) return true;
      final s = l.schedule;
      if (s == null) return false;
      final weekdays = <int>{};
      for (final r in s.notificationRules) {
        if (r.isEnabled &&
            r.frequency == NotificationFrequency.weekly &&
            r.weekdays != null) {
          weekdays.addAll(r.weekdays!);
        }
      }
      if (weekdays.isEmpty || !weekdays.contains(target.weekday)) return false;
      final base = DateTime(s.date.year, s.date.month, s.date.day);
      return !target.isBefore(base);
    }).toList();
  }

  /// 특정 날짜(셀) 칩에 표시할 제목 목록 — 시작 시각이 이른 일정부터 최대 2개.
  /// (예: 일요일 셀 → '주일 유년부 예배'(09:05) → '주일 대예배'(11:10))
  List<String> _chipTitlesForDay(List<Litten> littens, DateTime day) {
    final occurring = _littensOccurringOn(littens, day);
    int mins(Litten l) => l.schedule == null
        ? 24 * 60
        : l.schedule!.startTime.hour * 60 + l.schedule!.startTime.minute;
    occurring.sort((a, b) => mins(a).compareTo(mins(b)));
    return occurring.take(2).map((l) => l.title).toList();
  }

  /// 날짜 셀 아래 일정 표시. 캘린더가 축소(일정 리스트 표시)되어 영역이 작으면
  /// 테마색 점으로, 전체 화면이면 제목(좌측 정렬)으로 표시.
  Widget _chipForDay(List<Litten> littens, DateTime day) {
    if (_scheduleListVisible) {
      final count = _littensOccurringOn(littens, day).length;
      if (count == 0) return const SizedBox.shrink();
      // 일정 개수와 무관하게 점 1개로 표시
      final color = Theme.of(context).primaryColor;
      return Padding(
        padding: const EdgeInsets.only(top: 2.0),
        child: Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
    }
    return _chipTitlesColumn(_chipTitlesForDay(littens, day));
  }

  /// 칩 제목들을 날짜 셀 아래에 그리는 위젯(공통). 셀 폭을 채워 좌측 정렬.
  Widget _chipTitlesColumn(List<String> titles) {
    if (titles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2.0, left: 2.0, right: 2.0),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: titles
              .map((title) => Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: TextStyle(fontSize: 8, color: Colors.grey[600], height: 1.1),
                  ))
              .toList(),
        ),
      ),
    );
  }

  /// 칩에 표시할 제목 선택.
  /// 같은 날짜 셀에 2개 이상의 일정이 있으면 시작 시각이 가장 이른(시간순 첫) 일정을 표시한다.
  /// (예: 일요일 셀에 '주일 유년부 예배'(09:05)와 '주일 대예배'(11:10)가 함께면 유년부 예배)
  /// 일정(schedule)이 없는 리튼만 있으면 첫 번째 제목.
  String? _pickUpcomingChipTitle(List<Litten> littens) {
    if (littens.isEmpty) return null;
    final scheduled = littens.where((l) => l.schedule != null).toList();
    if (scheduled.isNotEmpty) {
      int mins(Litten l) =>
          l.schedule!.startTime.hour * 60 + l.schedule!.startTime.minute;
      scheduled.sort((a, b) => mins(a).compareTo(mins(b)));
      return scheduled.first.title;
    }
    return littens.first.title;
  }

  // 일정 바 오버레이 빌드
  Widget _buildScheduleBars(AppStateProvider appState) {
    debugPrint('📅 _buildScheduleBars 호출 - _scheduleListVisible: $_scheduleListVisible');

    // 캘린더가 축소된 상태(일정 리스트 표시)면 일정 바를 숨김
    if (_scheduleListVisible) {
      return const SizedBox.shrink();
    }

    // 현재 포커스된 날짜의 월과 연도
    final focusedMonth = _calendarFocusedDate.value.month;
    final focusedYear = _calendarFocusedDate.value.year;

    // 해당 월의 일정들 수집 (모든 일정)
    final schedules = <Map<String, dynamic>>[];

    for (final litten in appState.littens) {
      debugPrint('   리튼: "${litten.title}", schedule: ${litten.schedule != null ? "있음" : "없음"}');

      if (litten.title == 'undefined' || litten.schedule == null) {
        continue;
      }

      final schedule = litten.schedule!;

      final startDate = DateTime(schedule.date.year, schedule.date.month, schedule.date.day);
      // endDate가 null이면 startDate와 같은 날로 처리 (단일 날짜 일정)
      final endDate = schedule.endDate != null
        ? DateTime(schedule.endDate!.year, schedule.endDate!.month, schedule.endDate!.day)
        : startDate;

      // 현재 월과 겹치는 일정만 포함
      final firstDayOfMonth = DateTime(focusedYear, focusedMonth, 1);
      final lastDayOfMonth = DateTime(focusedYear, focusedMonth + 1, 0);

      if (endDate.isBefore(firstDayOfMonth) || startDate.isAfter(lastDayOfMonth)) {
        continue;
      }

      schedules.add({
        'title': litten.title,
        'startDate': startDate,
        'endDate': endDate,
      });

      debugPrint('📅 일정 추가: ${litten.title}, $startDate ~ $endDate');
    }

    debugPrint('📅 총 ${schedules.length}개 일정 표시');

    if (schedules.isEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth / 7;

          // daysOfWeekHeight 계산 (전체 높이의 12%)
          final daysOfWeekHeight = constraints.maxHeight * 0.12;
          // 실제 캘린더 셀 영역 높이
          final calendarCellsHeight = constraints.maxHeight - daysOfWeekHeight;
          final cellHeight = calendarCellsHeight / 6; // 6주 표시

          // 월의 첫 날이 무슨 요일인지 계산 (일요일=0)
          final firstDayOfMonth = DateTime(focusedYear, focusedMonth, 1);
          final startDayOfWeek = firstDayOfMonth.weekday % 7;

          // 일정별로 처리 (각 일정의 레이어를 먼저 결정)
          // scheduleId -> layer 매핑
          final scheduleLayers = <String, int>{};

          // 각 행별로 어떤 레이어가 사용 중인지 추적
          final rowLayerOccupancy = <int, Map<int, Set<int>>>{}; // row -> layer -> Set<column>

          for (final schedule in schedules) {
            final startDate = schedule['startDate'] as DateTime;
            final endDate = schedule['endDate'] as DateTime;
            final title = schedule['title'] as String;

            // 시작일이 현재 월에 있는지만 확인
            if (startDate.month != focusedMonth) {
              debugPrint('📅 일정 "$title": 시작일($startDate)이 다른 월이어서 건너뜀');
              continue;
            }

            final scheduleId = '${title}_${startDate}_${endDate}';

            // 시작일의 행과 열 계산
            final startPosition = startDayOfWeek + startDate.day - 1;
            final startRow = startPosition ~/ 7;
            final startCol = startPosition % 7;

            // 종료일의 행과 열 계산
            final endPosition = startDayOfWeek + endDate.day - 1;
            final endRow = endPosition ~/ 7;
            final endCol = endPosition % 7;

            // 이 일정이 차지하는 모든 행과 열 범위 수집
            final occupiedSpaces = <Map<String, dynamic>>[];

            if (startRow != endRow) {
              debugPrint('📅 일정 "$title": 여러 행에 걸쳐있음 ($startRow ~ $endRow)');
              for (int row = startRow; row <= endRow; row++) {
                int colStart, colEnd;
                if (row == startRow) {
                  colStart = startCol;
                  colEnd = 6;
                } else if (row == endRow) {
                  colStart = 0;
                  colEnd = endCol;
                } else {
                  colStart = 0;
                  colEnd = 6;
                }
                occupiedSpaces.add({'row': row, 'colStart': colStart, 'colEnd': colEnd});
                debugPrint('   행 $row: $colStart ~ $colEnd');
              }
            } else {
              occupiedSpaces.add({'row': startRow, 'colStart': startCol, 'colEnd': endCol});
            }

            // 이 일정에 사용 가능한 레이어 찾기
            final usedLayers = <int>{};
            for (final space in occupiedSpaces) {
              final row = space['row'] as int;
              final colStart = space['colStart'] as int;
              final colEnd = space['colEnd'] as int;

              rowLayerOccupancy.putIfAbsent(row, () => {});

              // 이 행의 모든 레이어를 확인
              rowLayerOccupancy[row]!.forEach((layer, occupiedCols) {
                // 열이 겹치는지 확인
                for (int col = colStart; col <= colEnd; col++) {
                  if (occupiedCols.contains(col)) {
                    usedLayers.add(layer);
                    break;
                  }
                }
              });
            }

            // 사용 가능한 가장 낮은 레이어 찾기
            int layer = 0;
            while (usedLayers.contains(layer)) {
              layer++;
            }
            scheduleLayers[scheduleId] = layer;

            // 이 일정이 차지하는 공간을 레이어에 등록
            for (final space in occupiedSpaces) {
              final row = space['row'] as int;
              final colStart = space['colStart'] as int;
              final colEnd = space['colEnd'] as int;

              rowLayerOccupancy[row]!.putIfAbsent(layer, () => {});
              for (int col = colStart; col <= colEnd; col++) {
                rowLayerOccupancy[row]![layer]!.add(col);
              }
            }
          }

          // 이제 세그먼트 생성
          final scheduleSegments = <Map<String, dynamic>>[];

          for (final schedule in schedules) {
            final startDate = schedule['startDate'] as DateTime;
            final endDate = schedule['endDate'] as DateTime;
            final title = schedule['title'] as String;

            if (startDate.month != focusedMonth) continue;

            final scheduleId = '${title}_${startDate}_${endDate}';
            final layer = scheduleLayers[scheduleId]!;

            final startPosition = startDayOfWeek + startDate.day - 1;
            final startRow = startPosition ~/ 7;
            final startCol = startPosition % 7;

            final endPosition = startDayOfWeek + endDate.day - 1;
            final endRow = endPosition ~/ 7;
            final endCol = endPosition % 7;

            if (startRow != endRow) {
              for (int row = startRow; row <= endRow; row++) {
                int colStart, colEnd;
                if (row == startRow) {
                  colStart = startCol;
                  colEnd = 6;
                } else if (row == endRow) {
                  colStart = 0;
                  colEnd = endCol;
                } else {
                  colStart = 0;
                  colEnd = 6;
                }
                scheduleSegments.add({
                  'title': title,
                  'row': row,
                  'colStart': colStart,
                  'colEnd': colEnd,
                  'layer': layer,
                });
              }
            } else {
              scheduleSegments.add({
                'title': title,
                'row': startRow,
                'colStart': startCol,
                'colEnd': endCol,
                'layer': layer,
              });
            }
          }

          final bars = <Widget>[];

          // 각 세그먼트를 레이어에 맞춰 배치
          for (int i = 0; i < scheduleSegments.length; i++) {
            final segment = scheduleSegments[i];
            final title = segment['title'] as String;
            final row = segment['row'] as int;
            final colStart = segment['colStart'] as int;
            final colEnd = segment['colEnd'] as int;
            final layer = segment['layer'] as int;

            final left = colStart * cellWidth;
            // daysOfWeekHeight를 더하고, 날짜 숫자(21px) 아래에 배치
            // 각 레이어는 18픽셀씩 아래로 배치
            final top = daysOfWeekHeight + (row * cellHeight) + 26 + (layer * 18);
            final width = (colEnd - colStart + 1) * cellWidth;

            debugPrint('📅 일정 "$title": row=$row, cols=$colStart~$colEnd, layer=$layer, left=$left, top=$top, width=$width');

            bars.add(
              Positioned(
                left: left,
                top: top,
                width: width,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          }

          return Stack(children: bars);
        },
      ),
    );
  }

  // 캘린더 콘텐츠 (50% 고정 레이아웃용)
  Widget _buildCalendarContent(AppStateProvider appState, AppLocalizations? l10n) {
    final currentAppState = Provider.of<AppStateProvider>(context, listen: false);

    return Container(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.paddingM.left,
          right: AppSpacing.paddingM.right,
          top: 8,
          bottom: 0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // 월 네비게이션 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    final previousMonth = DateTime(
                      _calendarFocusedDate.value.year,
                      _calendarFocusedDate.value.month - 1,
                    );
                    _calendarFocusedDate.value = previousMonth;
                  },
                  icon: const Icon(Icons.chevron_left),
                  tooltip: '이전 달',
                ),
                ValueListenableBuilder<DateTime>(
                  valueListenable: _calendarFocusedDate,
                  builder: (context, focusedDate, child) {
                    return Text(
                      DateFormat.yMMMM(currentAppState.locale.languageCode).format(focusedDate),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: (Theme.of(context).textTheme.headlineSmall?.fontSize ?? 24) - 2,
                      ),
                    );
                  },
                ),
                IconButton(
                  onPressed: () {
                    final nextMonth = DateTime(
                      _calendarFocusedDate.value.year,
                      _calendarFocusedDate.value.month + 1,
                    );
                    _calendarFocusedDate.value = nextMonth;
                  },
                  icon: const Icon(Icons.chevron_right),
                  tooltip: '다음 달',
                ),
              ],
            ),
            // 캘린더 (Expanded로 전체 공간 차지)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableHeight = constraints.maxHeight;
                  final daysOfWeekHeight = availableHeight * 0.12;
                  final rowHeight = (availableHeight - daysOfWeekHeight) / 6;

                  return ValueListenableBuilder<DateTime>(
                    valueListenable: _calendarFocusedDate,
                    builder: (context, focusedDate, child) {
                      return Stack(
                        children: [
                          TableCalendar<dynamic>(
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: focusedDate,
                            daysOfWeekHeight: daysOfWeekHeight,
                            rowHeight: rowHeight,
                            selectedDayPredicate: (day) {
                              if (!currentAppState.isDateSelected) return false;
                              return isSameDay(currentAppState.selectedDate, day);
                            },
                            onDaySelected: (selectedDay, focusedDay) async {
                              final currentScrollPosition = _scrollController.hasClients ? _scrollController.offset : 0.0;
                              debugPrint('📅 날짜 선택 전 스크롤 위치: $currentScrollPosition');

                              _calendarFocusedDate.value = focusedDay;
                              currentAppState.selectDate(selectedDay);
                              await _loadNotificationsForSelectedDate(selectedDay, currentAppState);

                              if (_scrollController.hasClients && mounted) {
                                _scrollController.jumpTo(currentScrollPosition);
                                debugPrint('📅 스크롤 위치 즉시 복원 (1차): $currentScrollPosition');

                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (_scrollController.hasClients && mounted) {
                                    _scrollController.jumpTo(currentScrollPosition);
                                    debugPrint('📅 스크롤 위치 복원 (2차): $currentScrollPosition');
                                  }
                                });

                                Future.delayed(const Duration(milliseconds: 50), () {
                                  if (_scrollController.hasClients && mounted) {
                                    _scrollController.jumpTo(currentScrollPosition);
                                    debugPrint('📅 스크롤 위치 복원 (3차): $currentScrollPosition');
                                  }
                                });
                              }
                            },
                            onPageChanged: (focusedDay) {
                              _calendarFocusedDate.value = focusedDay;
                            },
                            calendarFormat: CalendarFormat.month,
                            availableCalendarFormats: const {
                              CalendarFormat.month: 'Month',
                            },
                            headerVisible: false,
                            daysOfWeekStyle: const DaysOfWeekStyle(
                              weekdayStyle: TextStyle(fontWeight: FontWeight.bold),
                              weekendStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                            calendarStyle: CalendarStyle(
                              outsideDaysVisible: false,
                              weekendTextStyle: const TextStyle(color: Colors.black),
                              holidayTextStyle: TextStyle(color: Colors.red[400]),
                              selectedDecoration: const BoxDecoration(),
                              todayDecoration: const BoxDecoration(),
                              markerDecoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              markerSize: 5.0,
                              markersMaxCount: 3,
                              markersAlignment: Alignment.bottomCenter,
                            ),
                            eventLoader: (day) {
                              // 축소 모드일 때만 점 표시, 전체 화면일 때는 점 숨김
                              if (!_scheduleListVisible) {
                                return [];
                              }

                              // 해당 날짜에 일정이 있는지 확인 (시작일자 ~ 종료일자 범위 포함)
                              final targetDate = DateTime(day.year, day.month, day.day);
                              int scheduleCount = 0;

                              for (final litten in currentAppState.littens) {
                                if (litten.schedule != null) {
                                  final startDate = DateTime(
                                    litten.schedule!.date.year,
                                    litten.schedule!.date.month,
                                    litten.schedule!.date.day,
                                  );

                                  // 종료일자가 있으면 종료일자까지, 없으면 시작일자만
                                  final endDate = litten.schedule!.endDate != null
                                      ? DateTime(
                                          litten.schedule!.endDate!.year,
                                          litten.schedule!.endDate!.month,
                                          litten.schedule!.endDate!.day,
                                        )
                                      : startDate;

                                  // targetDate가 startDate와 endDate 사이에 있는지 확인
                                  if ((targetDate.isAtSameMomentAs(startDate) || targetDate.isAfter(startDate)) &&
                                      (targetDate.isAtSameMomentAs(endDate) || targetDate.isBefore(endDate))) {
                                    scheduleCount++;
                                  }
                                }
                              }

                              // 최대 3개까지만 점 표시
                              final markerCount = scheduleCount > 3 ? 3 : scheduleCount;
                              return List.generate(markerCount, (index) => 'schedule_$index');
                            },
                            locale: appState.locale.languageCode,
                            calendarBuilders: CalendarBuilders(
                              // 요일 헤더 빌더 - 토요일은 검은색, 일요일은 빨간색
                              dowBuilder: (context, day) {
                                final text = DateFormat.E(appState.locale.languageCode).format(day);
                                return Center(
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: day.weekday == DateTime.sunday ? Colors.red : Colors.black,
                                    ),
                                  ),
                                );
                              },
                              defaultBuilder: (context, day, focusedDay) {
                                return DragTarget<String>(
                                  onAcceptWithDetails: (details) async {
                                    try {
                                      await appState.moveLittenToDate(details.data, day);
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(e.toString().replaceAll('Exception: ', '')),
                                            backgroundColor: Colors.orange,
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  onWillAcceptWithDetails: (details) => true,
                                  builder: (context, candidateData, rejectedData) {
                                    final isHovered = candidateData.isNotEmpty;
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: isHovered
                                            ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                                            : null,
                                        border: isHovered
                                            ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                                            : null,
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              '${day.day}',
                                              style: const TextStyle().copyWith(
                                                color: isHovered
                                                    ? Theme.of(context).primaryColor
                                                    : (day.weekday == DateTime.sunday ? Colors.red : Colors.black),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          _chipForDay(appState.littens, day),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                              selectedBuilder: (context, day, focusedDay) {
                                // 선택된 날짜: 원형 강조 + 해당 날짜의 칩(일정) 펼쳐서 표시
                                return Container(
                                  margin: const EdgeInsets.all(4.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 21,
                                        height: 21,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${day.day}',
                                            style: const TextStyle().copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _chipForDay(appState.littens, day),
                                    ],
                                  ),
                                );
                              },
                              todayBuilder: (context, day, focusedDay) {
                                // 오늘 날짜: 원형 강조 + 해당 날짜의 칩(일정) 펼쳐서 표시
                                return Container(
                                  margin: const EdgeInsets.all(4.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 21,
                                        height: 21,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${day.day}',
                                            style: const TextStyle().copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _chipForDay(appState.littens, day),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          // 일정 바 오버레이
                          Positioned.fill(
                            child: _buildScheduleBars(currentAppState),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 일정 힌트 데이터 계산
  // secondsUntilToday: 오늘 다음 일정까지 남은 초 (null = 오늘 예정 일정 없음)
  // daysUntilNext: 미래 가장 가까운 일정까지 남은 일수 (-1 = 없음)
  // secondsUntilFutureEvent: 미래 가장 가까운 일정까지 남은 초 (daysUntilNext==1일 때 시간 표시용)
  // nearestTitle: 가장 임박한 일정의 제목
  ({int? secondsUntilToday, int daysUntilNext, int? secondsUntilFutureEvent, String? nearestTitle}) _getScheduleHint(List<Litten> littens, String languageCode) {
    // 선택된 언어의 타임존 기준 현재 시각
    final now = nowForLanguage(languageCode);
    final todayOnly = DateTime(now.year, now.month, now.day);
    int? nearestTodaySeconds;
    int nearestDays = -1;
    int? nearestFutureSeconds;
    String? nearestTitle;

    for (final litten in littens) {
      if (litten.schedule == null || litten.title == 'undefined') continue;
      DateTime start = DateTime(
        litten.schedule!.date.year,
        litten.schedule!.date.month,
        litten.schedule!.date.day,
      );
      DateTime end = litten.schedule!.endDate != null
          ? DateTime(
              litten.schedule!.endDate!.year,
              litten.schedule!.endDate!.month,
              litten.schedule!.endDate!.day,
            )
          : start;

      // ⭐ 반복 알림 고려: 일정 시작 시각이 지났으면 다음 발생일로 보정
      // (시작일이 과거이거나, 오늘이지만 startTime이 이미 지난 경우)
      final scheduleStartDateTime = DateTime(
        start.year, start.month, start.day,
        litten.schedule!.startTime.hour, litten.schedule!.startTime.minute,
      );
      if (scheduleStartDateTime.isBefore(now)) {
        final nextOccurrence = _calculateNextOccurrenceFromRules(
          start, todayOnly, litten.schedule!, now,
        );
        if (nextOccurrence != null) {
          start = nextOccurrence;
          end = nextOccurrence;
        }
      }

      final isToday = (todayOnly.isAtSameMomentAs(start) || todayOnly.isAfter(start)) &&
          (todayOnly.isAtSameMomentAs(end) || todayOnly.isBefore(end));

      if (isToday) {
        // 오늘 일정의 시작 시각을 선택된 언어의 타임존으로 생성
        final scheduleStart = tz.TZDateTime(
          getTimezoneForLanguage(languageCode),
          now.year, now.month, now.day,
          litten.schedule!.startTime.hour,
          litten.schedule!.startTime.minute,
        );
        if (scheduleStart.isAfter(now)) {
          final diffSec = scheduleStart.difference(now).inSeconds;
          if (nearestTodaySeconds == null || diffSec < nearestTodaySeconds) {
            nearestTodaySeconds = diffSec;
            nearestTitle = litten.title;
          }
        }
      } else if (start.isAfter(todayOnly)) {
        // 실제 일정 시작 시각까지 남은 초로 비교 → 같은 날이면 시작 시각이 이른 일정 우선
        final futureScheduleStart = tz.TZDateTime(
          getTimezoneForLanguage(languageCode),
          start.year, start.month, start.day,
          litten.schedule!.startTime.hour,
          litten.schedule!.startTime.minute,
        );
        final diffSec = futureScheduleStart.difference(now).inSeconds;
        if (nearestFutureSeconds == null || diffSec < nearestFutureSeconds) {
          nearestDays = start.difference(todayOnly).inDays;
          nearestFutureSeconds = diffSec;
          if (nearestTodaySeconds == null) nearestTitle = litten.title;
        }
      }
    }
    return (secondsUntilToday: nearestTodaySeconds, daysUntilNext: nearestDays, secondsUntilFutureEvent: nearestFutureSeconds, nearestTitle: nearestTitle);
  }

  /// 반복 알림 규칙을 기반으로 now 이후의 다음 발생일 계산 (시각 포함 비교)
  DateTime? _calculateNextOccurrenceFromRules(
    DateTime originalStart,
    DateTime todayOnly,
    LittenSchedule schedule,
    DateTime now,
  ) {
    DateTime makeStartDateTime(DateTime d) => DateTime(
      d.year, d.month, d.day,
      schedule.startTime.hour, schedule.startTime.minute,
    );

    DateTime? best;
    for (final rule in schedule.notificationRules) {
      if (!rule.isEnabled) continue;
      DateTime? next;
      switch (rule.frequency) {
        case NotificationFrequency.daily:
          // 오늘 시작 시각이 미래면 오늘, 아니면 내일
          DateTime candidate = todayOnly;
          if (!makeStartDateTime(candidate).isAfter(now)) {
            candidate = candidate.add(const Duration(days: 1));
          }
          next = candidate;
          break;
        case NotificationFrequency.weekly:
          if (rule.weekdays == null || rule.weekdays!.isEmpty) break;
          // 오늘부터 14일 이내 허용 요일 + 시각 미래 조건
          DateTime candidate = todayOnly;
          for (int i = 0; i < 14; i++) {
            if (rule.weekdays!.contains(candidate.weekday) &&
                makeStartDateTime(candidate).isAfter(now)) {
              next = candidate;
              break;
            }
            candidate = candidate.add(const Duration(days: 1));
          }
          break;
        case NotificationFrequency.monthly:
          // 매월 같은 날
          DateTime candidate = DateTime(todayOnly.year, todayOnly.month, originalStart.day);
          if (!makeStartDateTime(candidate).isAfter(now)) {
            candidate = DateTime(
              candidate.month == 12 ? candidate.year + 1 : candidate.year,
              candidate.month == 12 ? 1 : candidate.month + 1,
              originalStart.day,
            );
          }
          next = candidate;
          break;
        case NotificationFrequency.yearly:
          // 매년 같은 월/일
          DateTime candidate = DateTime(todayOnly.year, originalStart.month, originalStart.day);
          if (!makeStartDateTime(candidate).isAfter(now)) {
            candidate = DateTime(todayOnly.year + 1, originalStart.month, originalStart.day);
          }
          next = candidate;
          break;
        case NotificationFrequency.onDay:
        case NotificationFrequency.oneDayBefore:
          // 일회성 알림 → 무시
          break;
      }
      if (next != null && (best == null || next.isBefore(best))) {
        best = next;
      }
    }
    return best;
  }

  // 일정 목록 스크롤 유도 힌트 칩 위젯
  Widget _buildScheduleHintChip(AppStateProvider appState) {
    final l10n = AppLocalizations.of(context);
    final hint = _getScheduleHint(appState.littens, appState.locale.languageCode);

    final String timeLabel;
    // ⭐ 1일(24시간) 이내면 시간/분, 그 외에는 일로 표시
    const int oneDayInSec = 86400; // 24*60*60
    final int? secsToNext = hint.secondsUntilToday ?? hint.secondsUntilFutureEvent;

    if (secsToNext != null && secsToNext < oneDayInSec) {
      // 1일 이내 → 시간/분/초로 표시
      final minutes = secsToNext ~/ 60;
      final seconds = secsToNext % 60;
      if (minutes == 0) {
        timeLabel = '0분 ${seconds}초 후 일정 있음';
      } else if (minutes < 60) {
        timeLabel = '$minutes분 후 일정 있음';
      } else {
        final hours = minutes ~/ 60;
        final remaining = minutes % 60;
        timeLabel = remaining > 0 ? '$hours시간 $remaining분 후 일정 있음' : '$hours시간 후 일정 있음';
      }
    } else if (hint.daysUntilNext > 0) {
      // 1일 이상 → 일 단위로 표시
      timeLabel = '${hint.daysUntilNext}일 후 일정 있음';
    } else if (secsToNext != null) {
      // 24시간 이상이지만 daysUntilNext가 0인 경우 (예: 23시간 59분 후 → 표시 안 됨 방지)
      final days = secsToNext ~/ oneDayInSec;
      timeLabel = days > 0 ? '$days일 후 일정 있음' : (l10n?.viewScheduleList ?? '일정 목록 보기');
    } else {
      timeLabel = l10n?.viewScheduleList ?? '일정 목록 보기';
    }
    final String? title = hint.nearestTitle;

    return GestureDetector(
      onTap: () {
        debugPrint('📅 [HomeScreen] 힌트 칩 탭 → 일정 목록 토글 (현재: $_scheduleListVisible)');
        setState(() { _scheduleListVisible = !_scheduleListVisible; });
      },
      child: CustomPaint(
        painter: _ConcaveChipPainter(
          fillColor: Theme.of(context).primaryColor.withValues(alpha: 0.08),
          borderColor: Theme.of(context).primaryColor.withValues(alpha: 0.25),
          backgroundColor: Theme.of(context).cardColor,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (title != null) ...[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _scheduleListVisible ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                size: 22,
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 캘린더 SliverAppBar 빌드
  Widget _buildCalendarSliverAppBar(AppStateProvider appState, AppLocalizations? l10n) {
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomNavHeight = MediaQuery.of(context).padding.bottom;
    final bottomNavBarHeight = 80.0; // 하단 네비게이션 바 높이

    // 전체 화면 높이 (초기 상태)
    // 광고 표시 여부에 따라 캘린더 크기 조정
    // - 광고 ON: 95% + 광고 배너 50px 차지 → PageView 공간 감소
    // - 광고 OFF: 95% + 광고 영역 없음 → PageView 공간 50px 추가 확보
    const double adBannerHeight = 50.0;
    final availableHeight = screenHeight - statusBarHeight - bottomNavHeight - bottomNavBarHeight;
    final effectiveHeight = appState.adsEnabled ? availableHeight - adBannerHeight : availableHeight;
    final maxHeightRatio = 0.95;
    final maxHeight = effectiveHeight * maxHeightRatio;

    // 축소 후 높이 (화면의 45%)
    final minHeight = availableHeight * 0.45;

    return SliverPersistentHeader(
      pinned: true, // minHeight에서 고정
      delegate: _CalendarSliverDelegate(
        minHeight: minHeight,
        maxHeight: maxHeight,
        builder: (context, shrinkOffset) {
          // 매번 최신 appState를 가져옴 (스크롤 위치 유지)
          final currentAppState = Provider.of<AppStateProvider>(context, listen: false);

          // 스크롤 진행률 계산 (0.0 = 완전 펼침, 1.0 = 완전 축소)
          final shrinkProgress = (shrinkOffset / (maxHeight - minHeight)).clamp(0.0, 1.0);

          // bottom padding을 shrinkProgress에 따라 동적 조정
          // 펼쳐졌을 때: 100, 축소되었을 때: 4
          final dynamicBottomPadding = 100 - (96 * shrinkProgress);

          return Container(
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.paddingM.left,
                right: AppSpacing.paddingM.right,
                top: 8,
                bottom: dynamicBottomPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
              // 월 네비게이션 헤더
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      final previousMonth = DateTime(
                        _calendarFocusedDate.value.year,
                        _calendarFocusedDate.value.month - 1,
                      );
                      // 로컬 상태만 업데이트 (전역 상태 변경하지 않음 - 스크롤 위치 유지)
                      _calendarFocusedDate.value = previousMonth;
                    },
                    icon: const Icon(Icons.chevron_left),
                    tooltip: '이전 달',
                  ),
                  ValueListenableBuilder<DateTime>(
                    valueListenable: _calendarFocusedDate,
                    builder: (context, focusedDate, child) {
                      return Text(
                        DateFormat.yMMMM(currentAppState.locale.languageCode).format(focusedDate),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: (Theme.of(context).textTheme.headlineSmall?.fontSize ?? 24) - 2,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    onPressed: () {
                      final nextMonth = DateTime(
                        _calendarFocusedDate.value.year,
                        _calendarFocusedDate.value.month + 1,
                      );
                      // 로컬 상태만 업데이트 (전역 상태 변경하지 않음 - 스크롤 위치 유지)
                      _calendarFocusedDate.value = nextMonth;
                    },
                    icon: const Icon(Icons.chevron_right),
                    tooltip: '다음 달',
                  ),
                ],
              ),
              // 캘린더 (Expanded로 전체 공간 차지)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableHeight = constraints.maxHeight;
                    final daysOfWeekHeight = availableHeight * 0.12;
                    final rowHeight = (availableHeight - daysOfWeekHeight) / 6;

                    return ValueListenableBuilder<DateTime>(
                      valueListenable: _calendarFocusedDate,
                      builder: (context, focusedDate, child) {
                        return Stack(
                          children: [
                            TableCalendar<dynamic>(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: focusedDate,
                          daysOfWeekHeight: daysOfWeekHeight,
                          rowHeight: rowHeight,

                      selectedDayPredicate: (day) {
                        if (!currentAppState.isDateSelected) return false;
                        return isSameDay(currentAppState.selectedDate, day);
                      },
                      onDaySelected: (selectedDay, focusedDay) async {
                        // 현재 스크롤 위치 저장
                        final currentScrollPosition = _scrollController.hasClients ? _scrollController.offset : 0.0;
                        debugPrint('📅 날짜 선택 전 스크롤 위치: $currentScrollPosition');

                        _calendarFocusedDate.value = focusedDay;
                        currentAppState.selectDate(selectedDay);
                        // changeFocusedDate 호출하지 않음 - 스크롤 위치 유지
                        await _loadNotificationsForSelectedDate(selectedDay, currentAppState);

                        // 스크롤 위치 즉시 복원 (여러 번 시도)
                        if (_scrollController.hasClients && mounted) {
                          _scrollController.jumpTo(currentScrollPosition);
                          debugPrint('📅 스크롤 위치 즉시 복원 (1차): $currentScrollPosition');

                          // 프레임 완료 후 다시 복원
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollController.hasClients && mounted) {
                              _scrollController.jumpTo(currentScrollPosition);
                              debugPrint('📅 스크롤 위치 복원 (2차): $currentScrollPosition');
                            }
                          });

                          // 한 번 더 복원 (레이아웃이 완전히 완료된 후)
                          Future.delayed(const Duration(milliseconds: 50), () {
                            if (_scrollController.hasClients && mounted) {
                              _scrollController.jumpTo(currentScrollPosition);
                              debugPrint('📅 스크롤 위치 복원 (3차): $currentScrollPosition');
                            }
                          });
                        }
                      },
                      onPageChanged: (focusedDay) {
                        // 로컬 상태만 업데이트 (전역 상태 변경하지 않음 - 스크롤 위치 유지)
                        _calendarFocusedDate.value = focusedDay;
                      },
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Month',
                  },
                  headerVisible: false,
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(fontWeight: FontWeight.bold),
                    weekendStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    weekendTextStyle: const TextStyle(color: Colors.black),
                    holidayTextStyle: TextStyle(color: Colors.red[400]),
                    // selectedDecoration과 todayDecoration 제거 - builder 사용
                    selectedDecoration: const BoxDecoration(),
                    todayDecoration: const BoxDecoration(),
                    markerDecoration: const BoxDecoration(
                      color: Colors.transparent, // 전체 화면에서는 마커(점) 숨김
                    ),
                    markersMaxCount: 0,
                  ),
                  eventLoader: (day) {
                    // 전체 화면에서는 마커(점)를 표시하지 않음
                    return [];
                  },
                  locale: appState.locale.languageCode,
                  calendarBuilders: CalendarBuilders(
                    // 요일 헤더 빌더 - 토요일은 검은색, 일요일은 빨간색
                    dowBuilder: (context, day) {
                      final text = DateFormat.E(appState.locale.languageCode).format(day);
                      return Center(
                        child: Text(
                          text,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: day.weekday == DateTime.sunday ? Colors.red : Colors.black,
                          ),
                        ),
                      );
                    },
                    defaultBuilder: (context, day, focusedDay) {
                      // 해당 날짜의 알림이 있는 리튼 ID 가져오기
                      final dateKey = DateFormat('yyyy-MM-dd').format(day);
                      final littenIdsWithNotification = _notificationDateCache[dateKey] ?? {};

                      // 해당 리튼들의 제목 가져오기 (최대 2개만 표시)
                      final notificationTitles = littenIdsWithNotification
                          .take(2)
                          .map((littenId) {
                            final litten = appState.littens.firstWhere(
                              (l) => l.id == littenId,
                              orElse: () => Litten(
                                id: '',
                                title: '',
                                createdAt: DateTime.now(),
                              ),
                            );
                            return litten.title;
                          })
                          .where((title) => title.isNotEmpty)
                          .toList();

                      return DragTarget<String>(
                        onAcceptWithDetails: (details) async {
                          try {
                            await appState.moveLittenToDate(details.data, day);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString().replaceAll('Exception: ', '')),
                                  backgroundColor: Colors.orange,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        },
                        onWillAcceptWithDetails: (details) => true,
                        builder: (context, candidateData, rejectedData) {
                          final isHovered = candidateData.isNotEmpty;
                          return Container(
                            decoration: BoxDecoration(
                              color: isHovered
                                  ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                                  : null,
                              border: isHovered
                                  ? Border.all(
                                      color: Theme.of(context).primaryColor,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 날짜 숫자 영역 (상단)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    '${day.day}',
                                    style: const TextStyle().copyWith(
                                      color: isHovered
                                          ? Theme.of(context).primaryColor
                                          : (day.weekday == DateTime.sunday ? Colors.red : Colors.black),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // 알림 제목 영역 (날짜 바로 아래)
                                if (notificationTitles.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0, left: 2.0, right: 2.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: notificationTitles.map((title) => Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: Colors.grey[600],
                                          height: 1.1,
                                        ),
                                      )).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      // 해당 날짜의 알림이 있는 리튼 ID 가져오기
                      final dateKey = DateFormat('yyyy-MM-dd').format(day);
                      final littenIdsWithNotification = _notificationDateCache[dateKey] ?? {};

                      // 해당 리튼들의 제목 가져오기 (최대 2개만 표시)
                      final notificationTitles = littenIdsWithNotification
                          .take(2)
                          .map((littenId) {
                            final litten = appState.littens.firstWhere(
                              (l) => l.id == littenId,
                              orElse: () => Litten(
                                id: '',
                                title: '',
                                createdAt: DateTime.now(),
                              ),
                            );
                            return litten.title;
                          })
                          .where((title) => title.isNotEmpty)
                          .toList();

                      return Container(
                        margin: const EdgeInsets.all(4.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 원형 배경의 날짜
                            Container(
                              width: 21,
                              height: 21,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${day.day}',
                                  style: const TextStyle().copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            // 알림 제목
                            if (notificationTitles.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0, left: 2.0, right: 2.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: notificationTitles.map((title) => Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.grey[600],
                                      height: 1.1,
                                    ),
                                  )).toList(),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                    todayBuilder: (context, day, focusedDay) {
                      // 해당 날짜의 알림이 있는 리튼 ID 가져오기
                      final dateKey = DateFormat('yyyy-MM-dd').format(day);
                      final littenIdsWithNotification = _notificationDateCache[dateKey] ?? {};

                      // 해당 리튼들의 제목 가져오기 (최대 2개만 표시)
                      final notificationTitles = littenIdsWithNotification
                          .take(2)
                          .map((littenId) {
                            final litten = appState.littens.firstWhere(
                              (l) => l.id == littenId,
                              orElse: () => Litten(
                                id: '',
                                title: '',
                                createdAt: DateTime.now(),
                              ),
                            );
                            return litten.title;
                          })
                          .where((title) => title.isNotEmpty)
                          .toList();

                      return Container(
                        margin: const EdgeInsets.all(4.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 원형 배경의 날짜
                            Container(
                              width: 21,
                              height: 21,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${day.day}',
                                  style: const TextStyle().copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            // 알림 제목
                            if (notificationTitles.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0, left: 2.0, right: 2.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: notificationTitles.map((title) => Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.grey[600],
                                      height: 1.1,
                                    ),
                                  )).toList(),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                        ),
                            // 일정 바 오버레이
                            Positioned.fill(
                              child: _buildScheduleBars(currentAppState),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
          );
        },
      ),
    );
  }
}

/// 힌트 칩 배경 Painter — 상단 좌우 모서리를 오목(concave) 곡선으로 처리
/// 코너 영역을 backgroundColor(cardColor)로 덮어 오목 효과를 시각적으로 표현
class _ConcaveChipPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final Color backgroundColor;
  final double cornerRadius;

  const _ConcaveChipPainter({
    required this.fillColor,
    required this.borderColor,
    required this.backgroundColor,
    this.cornerRadius = 16.0,
  });

  /// 칩 본체 경로 (오목 코너 포함)
  Path _buildChipPath(Size size) {
    final r = cornerRadius;
    final path = Path();
    path.moveTo(r, 0);
    path.quadraticBezierTo(0, 0, 0, r);       // 좌상단 오목 곡선
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, r);
    path.quadraticBezierTo(size.width, 0, size.width - r, 0); // 우상단 오목 곡선
    path.lineTo(r, 0);
    path.close();
    return path;
  }

  /// 좌상단 코너 오목 영역 — 이 영역을 backgroundColor로 덮어 오목 효과를 표현
  Path _buildLeftCornerPath(Size size) {
    final r = cornerRadius;
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(r, 0);
    path.quadraticBezierTo(0, 0, 0, r);
    path.close();
    return path;
  }

  /// 우상단 코너 오목 영역
  Path _buildRightCornerPath(Size size) {
    final r = cornerRadius;
    final path = Path();
    path.moveTo(size.width, 0);
    path.lineTo(size.width - r, 0);
    path.quadraticBezierTo(size.width, 0, size.width, r);
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 칩 배경 채우기
    canvas.drawPath(_buildChipPath(size), Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill,
    );
    // 2. 오목 코너 영역을 캘린더 배경색으로 덮어써서 오목 효과 표현
    final bgPaint = Paint()..color = backgroundColor..style = PaintingStyle.fill;
    canvas.drawPath(_buildLeftCornerPath(size), bgPaint);
    canvas.drawPath(_buildRightCornerPath(size), bgPaint);
    // 3. 칩 테두리 (리마인더 칩과 동일하게 stroke 그림)
    canvas.drawPath(_buildChipPath(size), Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_ConcaveChipPainter old) =>
      old.fillColor != fillColor || old.borderColor != borderColor ||
      old.backgroundColor != backgroundColor || old.cornerRadius != cornerRadius;
}

/// 캘린더를 위한 Custom SliverPersistentHeaderDelegate
/// minHeight (50%)와 maxHeight (전체 화면)를 정확하게 제어
class _CalendarSliverDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget Function(BuildContext context, double shrinkOffset) builder;

  _CalendarSliverDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.builder,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // 현재 높이 계산: maxHeight에서 shrinkOffset만큼 축소
    final currentHeight = (maxHeight - shrinkOffset).clamp(minHeight, maxHeight);
    return SizedBox(
      height: currentHeight,
      width: double.infinity,
      child: builder(context, shrinkOffset),
    );
  }

  @override
  bool shouldRebuild(_CalendarSliverDelegate oldDelegate) {
    // delegate 재생성 조건
    // focusedDate는 delegate 파라미터가 아니므로 체크하지 않음 (스크롤 위치 유지)
    // 년/월 업데이트는 Consumer가 처리
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight;
  }
}
