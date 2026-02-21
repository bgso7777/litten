import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_state_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_storage_service.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/home/schedule_picker.dart';
import '../widgets/home/notification_settings.dart';
import '../config/themes.dart';
import '../utils/responsive_utils.dart';
import '../models/litten.dart';
import '../models/audio_file.dart';
import '../models/text_file.dart';
import '../models/handwriting_file.dart';
import '../widgets/dialogs/create_litten_dialog.dart';
import '../widgets/dialogs/edit_litten_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  int _currentTabIndex = 0; // 현재 활성화된 탭 인덱스 (0: 일정추가, 1: 알림설정)
  bool _userInteractedWithSchedule = false; // 사용자가 일정과 상호작용했는지 추적
  Map<String, Set<String>> _notificationDateCache = {}; // 날짜별 알림이 있는 리튼 ID Set (YYYY-MM-DD -> Set<littenId>)
  Set<String> _collapsedLittenIds = {}; // 숨겨진 리튼 ID Set

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // 화면 로드 후 최신 항목으로 스크롤 (최신이 맨 위에 있으므로 맨 위로)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTop();
      _callInstallApiIfNeeded();
      _loadNotificationDates();
      _loadCollapsedLittenIds();
    });
  }

  /// 숨겨진 리튼 ID 목록 로드
  Future<void> _loadCollapsedLittenIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final collapsedIds = prefs.getStringList('collapsed_litten_ids') ?? [];
      setState(() {
        _collapsedLittenIds = collapsedIds.toSet();
      });
      debugPrint('📂 숨겨진 리튼 ID 로드: ${_collapsedLittenIds.length}개');
    } catch (e) {
      debugPrint('❌ 숨겨진 리튼 ID 로드 실패: $e');
    }
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
  Future<void> _loadNotificationDates() async {
    try {
      final storage = NotificationStorageService();
      final allNotifications = await storage.loadNotifications();

      // 날짜별로 알림이 있는 리튼 ID Set 계산
      final dateMap = <String, Set<String>>{};
      for (final notification in allNotifications) {
        final dateKey = '${notification.triggerTime.year}-${notification.triggerTime.month.toString().padLeft(2, '0')}-${notification.triggerTime.day.toString().padLeft(2, '0')}';
        dateMap.putIfAbsent(dateKey, () => {}).add(notification.littenId);
      }

      setState(() {
        _notificationDateCache = dateMap;
      });

      debugPrint('📅 알림 날짜 캐시 로드 완료: ${_notificationDateCache.length}개 날짜');
    } catch (e) {
      debugPrint('❌ 알림 날짜 캐시 로드 실패: $e');
    }
  }

  /// 선택된 날짜의 알림 목록 로드
  Future<void> _loadNotificationsForSelectedDate(DateTime date, AppStateProvider appState) async {
    try {
      final storage = NotificationStorageService();
      final allNotifications = await storage.loadNotifications();

      // 선택된 날짜의 알림만 필터링 (acknowledged된 알림은 제외)
      final targetDate = DateTime(date.year, date.month, date.day);
      final notifications = allNotifications.where((notification) {
        final triggerDate = DateTime(
          notification.triggerTime.year,
          notification.triggerTime.month,
          notification.triggerTime.day,
        );
        return triggerDate.isAtSameMomentAs(targetDate) && !notification.isAcknowledged;
      }).toList();

      // 시간순으로 정렬
      notifications.sort((a, b) => a.triggerTime.compareTo(b.triggerTime));

      // 각 알림에 해당하는 리튼 정보 추가
      final notificationsWithLitten = notifications.map((notification) {
        final litten = appState.littens.firstWhere(
          (l) => l.id == notification.littenId,
          orElse: () => Litten(
            id: notification.littenId,
            title: '삭제된 리튼',
            createdAt: DateTime.now(),
          ),
        );
        return {
          'notification': notification,
          'litten': litten,
        };
      }).toList();

      // AppStateProvider에 알림 설정 (notifyListeners 자동 호출)
      appState.setSelectedDateNotifications(notificationsWithLitten);
      debugPrint('📋 선택된 날짜(${DateFormat('yyyy-MM-dd').format(date)})의 알림: ${notifications.length}개');
      debugPrint('🔍 AppState 업데이트 완료: selectedDateNotifications.length = ${appState.selectedDateNotifications.length}');
    } catch (e) {
      debugPrint('❌ 선택된 날짜 알림 로드 실패: $e');
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

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showCreateLittenDialog() {
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
    final l10n = AppLocalizations.of(context);

    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: null,
          body: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상단 - 캘린더 (고정 높이)
              _buildCalendarSection(appState, l10n),
              // 하단 - 통합 리스트 (일정 + 파일) - 나머지 공간 차지
              Expanded(
                child: _buildUnifiedListSection(appState, l10n),
              ),
            ],
          ),
              // 알림 배지
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showCreateLittenDialog,
            tooltip: l10n?.createLitten ?? '리튼 생성',
            child: const Icon(Icons.add),
          ),
        );
      },
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
                        Icon(Icons.schedule, size: 16),
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
                        Icon(Icons.schedule, size: 16),
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
        final scheduleText = newSchedule != null
            ? ' (${DateFormat('M월 d일').format(newSchedule.date)} ${newSchedule.startTime.format(context)})'
            : '';
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('${updatedLitten.title} 리튼이 수정되었습니다.$scheduleText')),
        );
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
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('리튼 이름이 \'$newTitle\'로 변경되었습니다.')),
      );
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
        mainAxisSize: MainAxisSize.min, // max에서 min으로 변경하여 공백 최소화
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
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: TextStyle(color: Colors.red[400]),
                  holidayTextStyle: TextStyle(color: Colors.red[400]),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 3,
                ),
                eventLoader: (day) {
                  // 1. 해당 날짜에 생성된 리튼 ID Set
                  final targetDate = DateTime(day.year, day.month, day.day);
                  final littenIds = appState.littens.where((litten) {
                    if (litten.title == 'undefined') return false;
                    final littenDate = DateTime(
                      litten.createdAt.year,
                      litten.createdAt.month,
                      litten.createdAt.day,
                    );
                    return littenDate.isAtSameMomentAs(targetDate);
                  }).map((l) => l.id).toSet();

                  // 2. 해당 날짜에 알림이 있는 리튼 ID Set
                  final dateKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                  final notificationLittenIds = _notificationDateCache[dateKey] ?? <String>{};

                  // 3. 두 Set을 합쳐서 중복 제거 (같은 리튼이 생성일과 알림 날짜가 같아도 1개로 카운트)
                  final allLittenIds = {...littenIds, ...notificationLittenIds};
                  final markerCount = allLittenIds.length > 3 ? 3 : allLittenIds.length;

                  return List.generate(markerCount, (index) => 'event');
                },
                locale: appState.locale.languageCode,
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    return DragTarget<String>(
                      onAcceptWithDetails: (details) async {
                        // 리튼을 해당 날짜로 이동
                        try {
                          await appState.moveLittenToDate(details.data, day);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('리튼이 ${DateFormat('M월 d일').format(day)}로 이동되었습니다.'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
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
                            shape: BoxShape.circle,
                            border: isHovered
                                ? Border.all(
                                    color: Theme.of(context).primaryColor,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: const TextStyle().copyWith(
                                color: isHovered
                                    ? Theme.of(context).primaryColor
                                    : null,
                                fontWeight: isHovered ? FontWeight.bold : null,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    return DragTarget<String>(
                      onAcceptWithDetails: (details) async {
                        try {
                          await appState.moveLittenToDate(details.data, day);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('리튼이 ${DateFormat('M월 d일').format(day)}로 이동되었습니다.'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
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
                                ? Theme.of(context).primaryColor.withValues(alpha: 0.8)
                                : Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                            border: isHovered
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: const TextStyle().copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  todayBuilder: (context, day, focusedDay) {
                    return DragTarget<String>(
                      onAcceptWithDetails: (details) async {
                        try {
                          await appState.moveLittenToDate(details.data, day);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('리튼이 ${DateFormat('M월 d일').format(day)}로 이동되었습니다.'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
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
                                ? Theme.of(context).primaryColor.withValues(alpha: 0.8)
                                : Theme.of(context).primaryColor.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            border: isHovered
                                ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: const TextStyle().copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 통합 리스트 섹션 빌드 (일정 + 파일 통합)
  Widget _buildUnifiedListSection(AppStateProvider appState, AppLocalizations? l10n) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.paddingM.left,
        right: AppSpacing.paddingM.right,
        top: 8, // 상단 여백 최소화
        bottom: AppSpacing.paddingM.left,
      ),
      child: _buildUnifiedList(appState, l10n, appState.selectedDateNotifications),
    );
  }

  // 일정과 파일을 통합한 리스트
  Widget _buildUnifiedList(AppStateProvider appState, AppLocalizations? l10n, List<dynamic> selectedDateNotifications) {
    // 날짜가 선택되었는지 확인
    final bool hasSelectedDate = appState.isDateSelected;

    // 날짜 선택 여부에 따라 리튼 필터링
    // ⭐ undefined 리튼도 표시 (홈에서 기본 리튼으로 사용)
    List<Litten> displayLittens;
    if (hasSelectedDate) {
      // 날짜가 선택된 경우: 해당 날짜에 생성된 리튼 + 알림이 있는 리튼
      final littensOnDate = appState.littensForSelectedDate.toList();

      // 알림이 있는 리튼 ID 추가
      debugPrint('🔍 displayLittens 계산: 선택된 날짜 알림=${selectedDateNotifications.length}개');
      final notificationLittenIds = selectedDateNotifications
          .map((item) => (item['litten'] as Litten).id)
          .toSet();
      debugPrint('🔍 알림이 있는 리튼 ID: $notificationLittenIds');

      final notificationLittens = appState.littens
          .where((litten) => notificationLittenIds.contains(litten.id))
          .toList();
      debugPrint('🔍 알림이 있는 리튼: ${notificationLittens.map((l) => l.title).toList()}');

      // 중복 제거하여 합치기
      final allLittenIds = <String>{};
      displayLittens = [];
      for (final litten in [...littensOnDate, ...notificationLittens]) {
        if (!allLittenIds.contains(litten.id)) {
          allLittenIds.add(litten.id);
          displayLittens.add(litten);
        }
      }
      debugPrint('🔍 최종 displayLittens: ${displayLittens.map((l) => l.title).toList()}');
    } else {
      displayLittens = appState.littens.toList();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(selectedDateNotifications.length), // 알림 개수가 변경되면 FutureBuilder 재시작
      future: appState.getAllFiles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allFiles = snapshot.data ?? [];

        // ⭐ 새로운 구조: 리튼 그룹별로 파일들을 정리
        final List<Map<String, dynamic>> littenGroups = [];

        // 1. 각 리튼별로 파일들 수집
        for (final litten in displayLittens) {
          final littenId = litten.id;

          // 이 리튼에 속한 파일들 필터링
          List<Map<String, dynamic>> littenFiles = [];
          for (final fileData in allFiles) {
            if (fileData['littenId'] == littenId) {
              final file = fileData['file'];
              final createdAt = fileData['createdAt'] as DateTime;
              DateTime updatedAt;

              if (file is AudioFile) {
                updatedAt = createdAt; // 녹음 파일은 수정이 없으므로 생성 시간 사용
              } else if (file is TextFile) {
                updatedAt = file.updatedAt;
              } else if (file is HandwritingFile) {
                updatedAt = file.updatedAt;
              } else {
                updatedAt = DateTime.now();
              }

              littenFiles.add({
                'fileData': fileData,
                'updatedAt': updatedAt,
                'createdAt': createdAt,
              });
            }
          }

          // 파일들을 시간순으로 정렬 (최신순)
          littenFiles.sort((a, b) {
            int updatedCompare = (b['updatedAt'] as DateTime).compareTo(a['updatedAt'] as DateTime);
            if (updatedCompare != 0) return updatedCompare;
            return (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime);
          });

          // 2. 리튼의 정렬 우선순위 및 기준 시간 계산
          int sortPriority = 3; // 기본: 일반 리튼
          DateTime sortTime = litten.createdAt;

          // 2-1. 알림이 있는 리튼인지 확인
          final littenNotifications = selectedDateNotifications
              .where((item) => (item['litten'] as Litten).id == littenId)
              .toList();

          if (littenNotifications.isNotEmpty) {
            // 가장 최근 알림 시간 찾기
            DateTime? latestNotificationTime;
            for (final notif in littenNotifications) {
              final triggerTime = notif['notification'].triggerTime as DateTime;
              if (latestNotificationTime == null || triggerTime.isAfter(latestNotificationTime)) {
                latestNotificationTime = triggerTime;
              }
            }
            sortPriority = 1; // 알림 발생 리튼
            sortTime = latestNotificationTime!;
            debugPrint('📌 리튼 "${litten.title}": 알림 발생 (우선순위=1, 시간=${sortTime})');
          }
          // 2-2. 파일이 수정된 리튼인지 확인
          else if (littenFiles.isNotEmpty) {
            final latestFileTime = littenFiles.first['updatedAt'] as DateTime;
            sortPriority = 2; // 파일 수정 리튼
            sortTime = latestFileTime;
            debugPrint('📌 리튼 "${litten.title}": 파일 수정 (우선순위=2, 시간=${sortTime})');
          } else {
            debugPrint('📌 리튼 "${litten.title}": 일반 (우선순위=3, 시간=${sortTime})');
          }

          // 3. 리튼 그룹 생성
          littenGroups.add({
            'type': 'litten-group',
            'litten': litten,
            'files': littenFiles,
            'sortPriority': sortPriority,
            'sortTime': sortTime,
          });
        }

        // 4. 리튼 그룹들을 우선순위 + 시간 순으로 정렬
        littenGroups.sort((a, b) {
          // 우선순위로 먼저 비교 (숫자가 작을수록 우선)
          int priorityCompare = (a['sortPriority'] as int).compareTo(b['sortPriority'] as int);
          if (priorityCompare != 0) return priorityCompare;

          // 우선순위가 같으면 시간으로 비교 (최신순)
          return (b['sortTime'] as DateTime).compareTo(a['sortTime'] as DateTime);
        });

        // littenGroups가 비어있어도 알림이 있으면 ListView 표시
        debugPrint('🔍 EmptyState 체크: littenGroups=${littenGroups.length}, 알림=${selectedDateNotifications.length}');
        if (littenGroups.isEmpty && selectedDateNotifications.isEmpty) {
          debugPrint('⚠️ EmptyState 표시');
          return const EmptyState(
            icon: Icons.event_note,
            title: '일정과 파일이 없습니다',
            description: '일정을 생성하거나 파일을 추가해보세요',
          );
        }
        debugPrint('✅ ListView 표시 준비 (littenGroups=${littenGroups.length}, 알림=${selectedDateNotifications.length})');

        return Scrollbar(
          child: RefreshIndicator(
            onRefresh: () async {
              await appState.refreshLittens();
              setState(() {});
            },
            child: ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              itemCount: (selectedDateNotifications.isNotEmpty && appState.isDateSelected ? 1 : 0) + littenGroups.length,
              itemBuilder: (context, index) {
                // 디버그: 알림 섹션 표시 여부 확인
                if (index == 0) {
                  debugPrint('🔍 ListView itemBuilder: index=0, 알림=${selectedDateNotifications.length}개, isDateSelected=${appState.isDateSelected}');
                }

                // 알림 섹션 표시 (날짜가 선택되고 알림이 있는 경우 맨 위에)
                if (selectedDateNotifications.isNotEmpty && appState.isDateSelected && index == 0) {
                  debugPrint('✅ 알림 섹션 표시');
                  return _buildNotificationSection(appState, selectedDateNotifications);
                }

                // 알림 섹션이 있으면 인덱스 조정
                final itemIndex = (selectedDateNotifications.isNotEmpty && appState.isDateSelected) ? index - 1 : index;

                // 인덱스 범위 체크
                if (itemIndex < 0 || itemIndex >= littenGroups.length) {
                  debugPrint('⚠️ 잘못된 인덱스: $itemIndex (littenGroups 길이: ${littenGroups.length})');
                  return const SizedBox.shrink();
                }

                final group = littenGroups[itemIndex];
                final litten = group['litten'] as Litten;
                final files = group['files'] as List<Map<String, dynamic>>;

                return _buildLittenGroup(context, appState, litten, files);
              },
            ),
          ),
        );
      },
    );
  }

  // 선택된 날짜의 알림 섹션 빌드
  Widget _buildNotificationSection(AppStateProvider appState, List<dynamic> selectedDateNotifications) {
    final selectedDate = appState.selectedDate;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('M월 d일 (E)', 'ko').format(selectedDate)} 알림',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedDateNotifications.length}개',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 알림 목록
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: selectedDateNotifications.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.blue.shade100,
            ),
            itemBuilder: (context, index) {
              final item = selectedDateNotifications[index];
              final notification = item['notification'];
              final litten = item['litten'] as Litten;
              final triggerTime = notification.triggerTime as DateTime;
              final now = DateTime.now();
              final isPast = triggerTime.isBefore(now);

              return ListTile(
                leading: Icon(
                  isPast ? Icons.check_circle : Icons.schedule,
                  color: isPast ? Colors.grey : Colors.blue.shade700,
                  size: 24,
                ),
                title: Text(
                  litten.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isPast ? Colors.grey.shade600 : Colors.black87,
                    decoration: isPast ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(
                  '${DateFormat('HH:mm').format(triggerTime)} - ${notification.rule.frequency.label}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isPast ? Colors.grey.shade500 : Colors.grey.shade700,
                  ),
                ),
                trailing: isPast
                    ? Text(
                        '완료',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      )
                    : Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.blue.shade300,
                      ),
                onTap: () async {
                  // 알림을 확인됨으로 표시
                  try {
                    final storage = NotificationStorageService();
                    final allNotifications = await storage.loadNotifications();

                    // 해당 알림을 찾아서 acknowledged로 표시
                    final updatedNotifications = allNotifications.map((n) {
                      if (n.id == notification.id) {
                        return n.markAsAcknowledged();
                      }
                      return n;
                    }).toList();

                    await storage.saveNotifications(updatedNotifications);
                    debugPrint('✅ 알림 확인 처리됨: ${notification.id}');

                    // NotificationService의 firedNotifications에서도 제거
                    final firedNotification = appState.notificationService.firedNotifications
                        .where((fired) =>
                            fired.littenId == notification.littenId &&
                            fired.triggerTime.isAtSameMomentAs(notification.triggerTime))
                        .firstOrNull;

                    if (firedNotification != null) {
                      await appState.notificationService.dismissNotification(firedNotification);
                      debugPrint('✅ firedNotifications에서 알림 제거: ${notification.id}');
                    }

                    // 알림 목록 새로고침
                    await _loadNotificationsForSelectedDate(appState.selectedDate, appState);
                  } catch (e) {
                    debugPrint('❌ 알림 확인 처리 실패: $e');
                  }

                  // 해당 리튼으로 이동
                  try {
                    await appState.selectLitten(litten);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // 리튼 그룹 빌드 (리튼 헤더 + 파일 목록)
  Widget _buildLittenGroup(BuildContext context, AppStateProvider appState, Litten litten, List<Map<String, dynamic>> files) {
    final themeColor = Theme.of(context).primaryColor;
    final isCollapsed = _collapsedLittenIds.contains(litten.id);

    // 파일 개수 계산
    final audioCount = files.where((f) => (f['fileData'] as Map)['type'] == 'audio').length;
    final textCount = files.where((f) => (f['fileData'] as Map)['type'] == 'text').length;
    final handwritingCount = files.where((f) => (f['fileData'] as Map)['type'] == 'handwriting').length;

    // 해당 리튼에 미확인 알림이 있는지 확인
    final hasUnacknowledgedNotification = appState.notificationService.firedNotifications
        .any((notification) => notification.littenId == litten.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 리튼 헤더
        InkWell(
          onTap: () async {
            // 해당 리튼의 미확인 알림을 모두 확인 처리
            try {
              final storage = NotificationStorageService();
              final allNotifications = await storage.loadNotifications();

              // 해당 리튼의 미확인 알림 찾기
              final littenNotifications = allNotifications
                  .where((n) => n.littenId == litten.id && !n.isAcknowledged)
                  .toList();

              if (littenNotifications.isNotEmpty) {
                // 모두 acknowledged로 표시
                final updatedNotifications = allNotifications.map((n) {
                  if (n.littenId == litten.id && !n.isAcknowledged) {
                    return n.markAsAcknowledged();
                  }
                  return n;
                }).toList();

                await storage.saveNotifications(updatedNotifications);

                // firedNotifications에서도 제거
                for (final notification in littenNotifications) {
                  final firedNotification = appState.notificationService.firedNotifications
                      .where((fired) =>
                          fired.littenId == notification.littenId &&
                          fired.triggerTime.isAtSameMomentAs(notification.triggerTime))
                      .firstOrNull;

                  if (firedNotification != null) {
                    await appState.notificationService.dismissNotification(firedNotification);
                  }
                }

                debugPrint('✅ 리튼 "${litten.title}"의 ${littenNotifications.length}개 알림 확인 처리');
              }
            } catch (e) {
              debugPrint('❌ 리튼 알림 확인 처리 실패: $e');
            }

            // 리튼 선택
            try {
              await appState.selectLitten(litten);
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e.toString().replaceAll('Exception: ', '')),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
          onLongPress: () => _showEditLittenDialog(litten.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: hasUnacknowledgedNotification
                  ? Colors.red.shade50  // 미확인 알림이 있으면 빨간색 배경
                  : (appState.selectedLitten?.id == litten.id
                      ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                      : Colors.grey.shade50),
              border: Border(
                left: hasUnacknowledgedNotification
                    ? BorderSide(color: Colors.red.shade400, width: 4)
                    : BorderSide.none,
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
            ),
            child: Row(
              children: [
                // 리튼 제목
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          litten.title == 'undefined' ? '-' : litten.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: litten.title == 'undefined'
                                ? Colors.grey.shade600
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // 파일 카운트 뱃지
                if (audioCount > 0) ...[
                  _buildFileCountBadge(Icons.mic, audioCount, themeColor),
                  const SizedBox(width: 4),
                ],
                if (textCount > 0) ...[
                  _buildFileCountBadge(Icons.keyboard, textCount, themeColor),
                  const SizedBox(width: 4),
                ],
                if (handwritingCount > 0) ...[
                  _buildFileCountBadge(Icons.draw, handwritingCount, themeColor),
                  const SizedBox(width: 4),
                ],
                // 메뉴 버튼
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditLittenDialog(litten.id);
                    } else if (value == 'delete') {
                      _showDeleteDialog(litten.id, litten.title);
                    } else if (value == 'toggle_collapse') {
                      _toggleLittenCollapse(litten.id);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle_collapse',
                      child: Row(
                        children: [
                          Icon(
                            isCollapsed ? Icons.visibility : Icons.visibility_off,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(isCollapsed ? '보이기' : '숨기기'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(value: 'edit', child: Text('수정')),
                    const PopupMenuItem(value: 'delete', child: Text('삭제')),
                  ],
                  child: Icon(Icons.more_vert, color: Colors.grey.shade600, size: 20),
                ),
              ],
            ),
          ),
        ),
        // 파일 목록 (숨김 상태가 아닐 때만 표시)
        if (!isCollapsed)
          ...files.map((fileInfo) {
            final fileData = fileInfo['fileData'] as Map<String, dynamic>;
            return _buildFileItem(context, appState, fileData);
          }),
        // 그룹 구분선
        const SizedBox(height: 8),
      ],
    );
  }

  // 파일 카운트 뱃지
  Widget _buildFileCountBadge(IconData icon, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // 파일 아이템 빌드
  Widget _buildFileItem(BuildContext context, AppStateProvider appState, Map<String, dynamic> fileData) {
    final fileType = fileData['type'] as String;
    final createdAt = fileData['createdAt'] as DateTime;
    final themeColor = Theme.of(context).primaryColor;

    IconData icon;
    String title;
    DateTime displayTime; // 표시할 시간 (수정 시간)

    if (fileType == 'audio') {
      final audioFile = fileData['file'] as AudioFile;
      icon = Icons.mic;
      title = audioFile.displayName;
      displayTime = createdAt; // 녹음 파일은 수정이 없으므로 생성 시간
    } else if (fileType == 'text') {
      final textFile = fileData['file'] as TextFile;
      icon = Icons.keyboard;
      title = textFile.displayTitle;
      displayTime = textFile.updatedAt; // 텍스트 파일은 수정 시간
    } else {
      final handwritingFile = fileData['file'] as HandwritingFile;
      icon = handwritingFile.type == HandwritingType.pdfConvert
          ? Icons.picture_as_pdf
          : Icons.draw;
      title = handwritingFile.displayTitle;
      displayTime = handwritingFile.updatedAt; // 필기 파일은 수정 시간
    }

    return InkWell(
      onTap: () async {
        debugPrint('📂 파일 터치: ${fileData['file']}');
        debugPrint('   - 파일 타입: $fileType');
        debugPrint('   - 리튼 ID: ${fileData['littenId']}');

        try {
          // 파일이 속한 리튼 선택
          final littenId = fileData['littenId'] as String;
          final litten = appState.littens.firstWhere((l) => l.id == littenId);
          debugPrint('   - 선택할 리튼: ${litten.title}');

          await appState.selectLitten(litten);
          debugPrint('✅ 리튼 선택 완료');

          // WritingScreen 내부 탭 설정
          String targetWritingTabId;
          if (fileType == 'audio') {
            targetWritingTabId = 'audio';
          } else if (fileType == 'text') {
            targetWritingTabId = 'text';
          } else {
            targetWritingTabId = 'handwriting';
          }
          debugPrint('   - 목표 WritingScreen 탭: $targetWritingTabId');

          // ⭐ 현재 탭과 목표 탭을 모두 설정하여 즉시 해당 탭으로 전환
          appState.setCurrentWritingTab(targetWritingTabId);
          appState.setTargetWritingTab(targetWritingTabId);

          // 노트 탭(WritingScreen)으로 이동 (인덱스 1)
          const targetTabIndex = 1;
          debugPrint('🔄 노트 탭으로 이동 (인덱스 $targetTabIndex)');

          await Future.delayed(const Duration(milliseconds: 100));
          appState.changeTab(targetTabIndex);
          debugPrint('✅ 탭 변경 완료');
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // 파일 타입 아이콘
            Icon(icon, color: themeColor, size: 18),
            const SizedBox(width: 12),
            // 파일명 (확장 가능)
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 12),
            // 수정 시간
            Text(
              DateFormat('HH:mm').format(displayTime),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(String littenId, String title) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text('\'$title\' 일정을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없으며, 관련된 모든 파일이 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.cancel ?? '취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final appState = Provider.of<AppStateProvider>(context, listen: false);
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              try {
                await appState.deleteLitten(littenId);

                if (mounted) {
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('$title 일정이 삭제되었습니다.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            child: Text(l10n?.delete ?? '삭제', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}