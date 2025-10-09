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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late TabController _bottomTabController; // 하단 탭 컨트롤러 (리튼/파일)
  int _currentTabIndex = 0; // 현재 활성화된 탭 인덱스 (0: 일정추가, 1: 알림설정)
  bool _userInteractedWithSchedule = false; // 사용자가 일정과 상호작용했는지 추적

  @override
  void dispose() {
    _scrollController.dispose();
    _bottomTabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _bottomTabController = TabController(length: 2, vsync: this, initialIndex: 0); // 일정 탭이 기본

    // 탭 변경 시 FAB 표시/숨김 및 appState 동기화를 위해 리스너 추가
    _bottomTabController.addListener(() {
      if (mounted) {
        setState(() {});
        // 사용자가 탭을 수동으로 변경한 경우 appState에도 반영
        final appState = Provider.of<AppStateProvider>(context, listen: false);
        if (_bottomTabController.index != appState.homeBottomTabIndex) {
          appState.setHomeBottomTabIndex(_bottomTabController.index);
        }
      }
    });

    // 화면 로드 후 최신 리튼으로 스크롤 (최신이 맨 위에 있으므로 맨 위로)
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
        // appState의 homeBottomTabIndex와 TabController 동기화
        if (_bottomTabController.index != appState.homeBottomTabIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _bottomTabController.index != appState.homeBottomTabIndex) {
              _bottomTabController.animateTo(appState.homeBottomTabIndex);
            }
          });
        }

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
              // 하단 55% - 탭 영역 (리튼/파일)
              Expanded(
                flex: 11,
                child: _buildBottomTabSection(appState, l10n),
              ),
            ],
          ),
              // 알림 배지
            ],
          ),
          floatingActionButton: _bottomTabController.index == 0 // 일정 탭(인덱스 0)일 때만 표시
              ? FloatingActionButton(
                  onPressed: _showCreateLittenDialog,
                  tooltip: l10n?.createLitten ?? '리튼 생성',
                  child: const Icon(Icons.add),
                )
              : null,
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

  // 하단 탭 섹션 빌드 (리튼/파일 탭)
  Widget _buildBottomTabSection(AppStateProvider appState, AppLocalizations? l10n) {
    // 파일 개수 계산
    final isUndefinedSelected = appState.selectedLitten?.title == 'undefined';

    // 일정 개수 계산 (undefined 제외)
    final selectedDateLittens = appState.littensForSelectedDate
        .where((litten) => litten.title != 'undefined')
        .toList();
    final littenCount = selectedDateLittens.length;

    return Transform.translate(
      offset: const Offset(0, -8), // 탭을 8px 위로 이동하여 캘린더와 가깝게
      child: Container(
        padding: EdgeInsets.only(
          left: AppSpacing.paddingM.left,
          right: AppSpacing.paddingM.right,
          top: 0,
          bottom: AppSpacing.paddingM.left,
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 탭 바
          FutureBuilder<int>(
            future: _getFileCount(appState, isUndefinedSelected),
            builder: (context, snapshot) {
              final fileCount = snapshot.data ?? 0;
              return TabBar(
                controller: _bottomTabController,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).primaryColor,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
                tabs: [
                  Tab(text: '일정($littenCount)'),
                  Tab(text: '파일($fileCount)'),
                ],
              );
            },
          ),
          // 탭 뷰
          Expanded(
            child: TabBarView(
              controller: _bottomTabController,
              children: [
                _buildLittenListTab(appState, l10n),
                _buildAllFilesTab(appState, l10n),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  // 파일 개수 가져오기
  Future<int> _getFileCount(AppStateProvider appState, bool isUndefinedSelected) async {
    try {
      final files = isUndefinedSelected
          ? await appState.getAllFiles()
          : await appState.getFilesForSelectedLitten();
      return files.length;
    } catch (e) {
      return 0;
    }
  }

  // 리튼 리스트 탭
  Widget _buildLittenListTab(AppStateProvider appState, AppLocalizations? l10n) {
    // undefined 리튼을 제외한 리튼들만 표시
    final selectedDateLittens = appState.littensForSelectedDate
        .where((litten) => litten.title != 'undefined')
        .toList();

    // 알림이 있는 리튼과 없는 리튼을 구분하여 정렬
    final littensWithNotifications = <Litten>[];
    final littensWithoutNotifications = <Litten>[];

    for (final litten in selectedDateLittens) {
      final hasNotifications = appState.hasNotificationForLitten(litten.id);

      if (hasNotifications) {
        littensWithNotifications.add(litten);
      } else {
        littensWithoutNotifications.add(litten);
      }
    }

    // 알림이 있는 리튼들은 알림 시간 순으로 정렬
    littensWithNotifications.sort((a, b) {
      final aNotifications = appState.notificationService.firedNotifications
          .where((n) => n.littenId == a.id);
      final bNotifications = appState.notificationService.firedNotifications
          .where((n) => n.littenId == b.id);

      if (aNotifications.isEmpty && bNotifications.isEmpty) return 0;
      if (aNotifications.isEmpty) return 1;
      if (bNotifications.isEmpty) return -1;

      return aNotifications.first.triggerTime.compareTo(bNotifications.first.triggerTime);
    });

    // 알림이 없는 리튼들은 생성 순으로 정렬 (최신순)
    littensWithoutNotifications.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return selectedDateLittens.isEmpty
        ? const EmptyState(
            icon: Icons.calendar_today,
            title: '선택한 날짜에 생성된 일정이 없습니다',
            description: '이 날짜에 첫 번째 일정을 생성해보세요',
          )
        : Scrollbar(
            child: RefreshIndicator(
              onRefresh: () async {
                await appState.refreshLittens();
              },
              child: ListView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                children: [
                          // 알림이 있는 리튼들
                          if (littensWithNotifications.isNotEmpty) ...[
                            ...littensWithNotifications.map((litten) => LittenItem(
                              litten: litten,
                              isSelected: appState.selectedLitten?.id == litten.id,
                              onTap: () => appState.selectLitten(litten),
                              onDelete: () => _showDeleteDialog(litten.id, litten.title),
                              onLongPress: () => _showRenameLittenDialog(litten.id, litten.title),
                            )),
                            // 구분선
                            if (littensWithoutNotifications.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                child: Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.grey.shade300)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(
                                        '알림 없음',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Colors.grey.shade300)),
                                  ],
                                ),
                              ),
                          ],
                  // 알림이 없는 리튼들
                  ...littensWithoutNotifications.map((litten) => LittenItem(
                    litten: litten,
                    isSelected: appState.selectedLitten?.id == litten.id,
                    onTap: () => appState.selectLitten(litten),
                    onDelete: () => _showDeleteDialog(litten.id, litten.title),
                    onLongPress: () => _showRenameLittenDialog(litten.id, litten.title),
                  )),
                ],
              ),
            ),
          );
  }

  // 모든 파일 탭
  Widget _buildAllFilesTab(AppStateProvider appState, AppLocalizations? l10n) {
    // undefined 리튼이 선택된 경우 모든 파일 표시, 아니면 선택된 리튼의 파일만 표시
    final isUndefinedSelected = appState.selectedLitten?.title == 'undefined';

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: isUndefinedSelected
          ? appState.getAllFiles()  // undefined: 모든 리튼의 모든 파일 (시간순)
          : appState.getFilesForSelectedLitten(),  // 다른 리튼: 선택된 리튼의 파일만
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('오류: ${snapshot.error}'),
          );
        }

        final allFiles = snapshot.data ?? [];

        if (allFiles.isEmpty) {
          return const EmptyState(
            icon: Icons.folder_open,
            title: '선택한 날짜에 파일이 없습니다',
            description: '리튼에 녹음, 텍스트, 필기를 추가해보세요',
          );
        }

        return Scrollbar(
          child: RefreshIndicator(
            onRefresh: () async {
              await appState.refreshLittens();
              setState(() {}); // FutureBuilder 재실행
            },
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: allFiles.length,
              itemBuilder: (context, index) {
                final fileData = allFiles[index];
                final fileType = fileData['type'] as String;
                final littenTitleRaw = fileData['littenTitle'] as String;
                final littenTitle = littenTitleRaw == 'undefined' ? '-' : littenTitleRaw;
                final createdAt = fileData['createdAt'] as DateTime;

                IconData icon;
                String title;
                String subtitle;

                if (fileType == 'audio') {
                  final audioFile = fileData['file'] as AudioFile;
                  icon = Icons.mic;
                  title = audioFile.displayName;
                  subtitle = '${audioFile.durationString} • $littenTitle';
                } else if (fileType == 'text') {
                  final textFile = fileData['file'] as TextFile;
                  icon = Icons.keyboard;
                  title = textFile.displayTitle;
                  subtitle = '${textFile.shortPreview} • $littenTitle';
                } else {
                  final handwritingFile = fileData['file'] as HandwritingFile;
                  // PDF에서 변환된 필기는 picture_as_pdf, 빈 캔버스는 draw
                  icon = handwritingFile.type == HandwritingType.pdfConvert
                      ? Icons.picture_as_pdf
                      : Icons.draw;
                  title = handwritingFile.displayTitle;
                  subtitle = '${handwritingFile.pageInfo.isNotEmpty ? handwritingFile.pageInfo + " • " : ""}$littenTitle';
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
                      targetWritingTabId = 'audio'; // 녹음 탭
                    } else if (fileType == 'text') {
                      targetWritingTabId = 'text'; // 텍스트 탭
                    } else {
                      targetWritingTabId = 'handwriting'; // 필기 탭
                    }
                    debugPrint('   - 목표 WritingScreen 탭: $targetWritingTabId');
                    appState.setTargetWritingTab(targetWritingTabId);

                    // 노트 탭(WritingScreen)으로 이동 (인덱스 1)
                    const targetTabIndex = 1;
                    debugPrint('🔄 노트 탭으로 이동 (인덱스 $targetTabIndex)');

                    // 탭 변경 전에 약간의 딜레이를 주어 리튼 선택이 완료되도록 함
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
              },
            ),
          ),
        );
      },
    );
  }

  void _showDeleteDialog(String littenId, String title) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.deleteLitten ?? '리튼 삭제'),
        content: Text(l10n?.confirmDeleteLitten != null 
            ? l10n!.confirmDeleteLitten(title)
            : '\'$title\' 리튼을 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없으며, 관련된 모든 파일이 함께 삭제됩니다.'),
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
                  SnackBar(content: Text('$title 리튼이 삭제되었습니다.')),
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