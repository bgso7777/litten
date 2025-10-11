import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';

import '../services/app_state_provider.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/home/litten_item.dart';
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
    });
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
    );
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
              // 상단 45% - 캘린더
              Expanded(
                flex: 9,
                child: _buildCalendarSection(appState, l10n),
              ),
              // 하단 55% - 통합 리스트 (일정 + 파일)
              Expanded(
                flex: 11,
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
    );
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
        bottom: 0,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, 8), // 캘린더를 8px 아래로 이동하여 탭과 가깝게
              child: Transform.scale(
                scale: 0.9, // 캘린더를 90% 크기로 축소
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
              onDaySelected: (selectedDay, focusedDay) {
                appState.selectDate(selectedDay);
                appState.changeFocusedDate(focusedDay);
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
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
              ),
              eventLoader: (day) {
                // 해당 날짜에 생성된 리튼이 있으면 마커 표시
                final count = appState.getLittenCountForDate(day);
                return List.generate(count > 3 ? 3 : count, (index) => 'litten');
              },
              locale: appState.locale.languageCode,
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  return DragTarget<String>(
                    onAcceptWithDetails: (details) async {
                      // 리튼을 해당 날짜로 이동
                      await appState.moveLittenToDate(details.data, day);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('리튼이 ${DateFormat('M월 d일').format(day)}로 이동되었습니다.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
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
                      await appState.moveLittenToDate(details.data, day);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('리튼이 ${DateFormat('M월 d일').format(day)}로 이동되었습니다.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
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
                      await appState.moveLittenToDate(details.data, day);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('리튼이 ${DateFormat('M월 d일').format(day)}로 이동되었습니다.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
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
            ),
          ),
        ],
      ),
    );
  }

  // 통합 리스트 섹션 빌드 (일정 + 파일 통합)
  Widget _buildUnifiedListSection(AppStateProvider appState, AppLocalizations? l10n) {
    return Transform.translate(
      offset: const Offset(0, -8), // 리스트를 8px 위로 이동하여 캘린더와 가깝게
      child: Container(
        padding: EdgeInsets.only(
          left: AppSpacing.paddingM.left,
          right: AppSpacing.paddingM.right,
          top: 0,
          bottom: AppSpacing.paddingM.left,
        ),
        child: _buildUnifiedList(appState, l10n),
      ),
    );
  }

  // 일정과 파일을 통합한 리스트
  Widget _buildUnifiedList(AppStateProvider appState, AppLocalizations? l10n) {
    // 날짜가 선택되었는지 확인
    final bool hasSelectedDate = appState.isDateSelected;

    // 날짜 선택 여부에 따라 리튼 필터링
    final displayLittens = hasSelectedDate
        ? appState.littensForSelectedDate
            .where((litten) => litten.title != 'undefined')
            .toList()
        : appState.littens
            .where((litten) => litten.title != 'undefined')
            .toList();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: appState.getAllFiles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allFiles = snapshot.data ?? [];

        // 일정과 파일을 하나의 리스트로 통합
        final List<Map<String, dynamic>> unifiedItems = [];

        // 일정 추가
        for (final litten in displayLittens) {
          unifiedItems.add({
            'type': 'litten',
            'data': litten,
            'updatedAt': litten.updatedAt,
            'createdAt': litten.createdAt,
          });
        }

        // 파일 추가 (날짜 선택 시 필터링)
        for (final fileData in allFiles) {
          final file = fileData['file'];
          final createdAt = fileData['createdAt'] as DateTime;
          DateTime updatedAt;

          if (file is AudioFile) {
            // 녹음 파일은 수정이 없으므로 생성 시간을 사용
            updatedAt = createdAt;
          } else if (file is TextFile) {
            updatedAt = file.updatedAt;
          } else if (file is HandwritingFile) {
            updatedAt = file.updatedAt;
          } else {
            updatedAt = DateTime.now();
          }

          // 날짜가 선택되었을 때는 해당 날짜에 생성된 파일만 표시
          if (hasSelectedDate) {
            if (isSameDay(createdAt, appState.selectedDate)) {
              unifiedItems.add({
                'type': 'file',
                'data': fileData,
                'updatedAt': updatedAt,
                'createdAt': createdAt,
              });
            }
          } else {
            // 날짜가 선택되지 않았을 때는 전체 파일 표시
            unifiedItems.add({
              'type': 'file',
              'data': fileData,
              'updatedAt': updatedAt,
              'createdAt': createdAt,
            });
          }
        }

        // 수정 시간 순으로 정렬 (최신순), 같으면 생성 시간 순으로 정렬 (최신순)
        unifiedItems.sort((a, b) {
          // 1. 수정 시간으로 먼저 비교 (최신순)
          int updatedCompare = (b['updatedAt'] as DateTime).compareTo(a['updatedAt'] as DateTime);
          if (updatedCompare != 0) {
            return updatedCompare;
          }
          // 2. 수정 시간이 같으면 생성 시간으로 비교 (최신순)
          return (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime);
        });

        if (unifiedItems.isEmpty) {
          return const EmptyState(
            icon: Icons.event_note,
            title: '일정과 파일이 없습니다',
            description: '일정을 생성하거나 파일을 추가해보세요',
          );
        }

        return Scrollbar(
          child: RefreshIndicator(
            onRefresh: () async {
              await appState.refreshLittens();
              setState(() {});
            },
            child: ListView.builder(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              itemCount: unifiedItems.length,
              itemBuilder: (context, index) {
                final item = unifiedItems[index];
                final itemType = item['type'] as String;

                if (itemType == 'litten') {
                  final litten = item['data'] as Litten;
                  return LittenItem(
                    litten: litten,
                    isSelected: appState.selectedLitten?.id == litten.id,
                    onTap: () async {
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
                    onDelete: () => _showDeleteDialog(litten.id, litten.title),
                    onLongPress: () => _showRenameLittenDialog(litten.id, litten.title),
                  );
                } else {
                  // 파일 아이템
                  final fileData = item['data'] as Map<String, dynamic>;
                  return _buildFileItem(context, appState, fileData);
                }
              },
            ),
          ),
        );
      },
    );
  }

  // 파일 아이템 빌드
  Widget _buildFileItem(BuildContext context, AppStateProvider appState, Map<String, dynamic> fileData) {
    final fileType = fileData['type'] as String;
    final littenTitleRaw = fileData['littenTitle'] as String;
    final littenTitle = littenTitleRaw == 'undefined' ? '-' : littenTitleRaw;
    final createdAt = fileData['createdAt'] as DateTime;

    IconData icon;
    String title;

    if (fileType == 'audio') {
      final audioFile = fileData['file'] as AudioFile;
      icon = Icons.mic;
      title = audioFile.displayName;
    } else if (fileType == 'text') {
      final textFile = fileData['file'] as TextFile;
      icon = Icons.keyboard;
      title = textFile.displayTitle;
    } else {
      final handwritingFile = fileData['file'] as HandwritingFile;
      icon = handwritingFile.type == HandwritingType.pdfConvert
          ? Icons.picture_as_pdf
          : Icons.draw;
      title = handwritingFile.displayTitle;
    }

    return InkWell(
      onTap: () async {
        debugPrint('📂 파일 터치: ${fileData['file']}');
        debugPrint('   - 파일 타입: $fileType');
        debugPrint('   - 리튼 ID: ${fileData['littenId']}');

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
        appState.setTargetWritingTab(targetWritingTabId);

        // 노트 탭(WritingScreen)으로 이동 (인덱스 1)
        const targetTabIndex = 1;
        debugPrint('🔄 노트 탭으로 이동 (인덱스 $targetTabIndex)');

        await Future.delayed(const Duration(milliseconds: 100));
        appState.changeTab(targetTabIndex);
        debugPrint('✅ 탭 변경 완료');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            // 아이콘
            Icon(icon, color: Theme.of(context).primaryColor, size: 16),
            const SizedBox(width: 12),
            // 리튼명 (고정 너비)
            SizedBox(
              width: 80,
              child: Text(
                littenTitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 12),
            // 파일명 (확장 가능, ellipsis)
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
            // 시간 (고정 너비)
            SizedBox(
              width: 50,
              child: Text(
                DateFormat('HH:mm').format(createdAt),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.right,
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

              await appState.deleteLitten(littenId);

              if (mounted) {
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('$title 일정이 삭제되었습니다.')),
                );
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