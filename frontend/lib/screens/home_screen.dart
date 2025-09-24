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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _titleController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  LittenSchedule? _selectedSchedule;

  @override
  void dispose() {
    _titleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
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
    
    _titleController.clear();
    _selectedSchedule = null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n?.createLitten ?? '리튼 생성'),
          content: SizedBox(
            width: double.maxFinite,
            height: 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목 섹션
                Container(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '리튼 이름',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                // 제목 입력 필드
                SizedBox(
                  height: 80, // 🔑 중요: 높이 고정 (이게 핵심!)
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(4), // 🔑 중요: 패딩 유지
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50, // 깔끔한 회색 배경
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade300, // 회색 테두리
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _titleController,
                      enabled: true,
                      decoration: InputDecoration(
                        hintText: '예: 회의록, 강의 메모, 일기 등',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        labelStyle: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      autofocus: true,
                      onChanged: (value) {
                        debugPrint('🔤 텍스트 입력: $value');
                      },
                      onTap: () {
                        debugPrint('🔍 텍스트 필드 탭됨');
                      },
                    ),
                  ),
                ),

                // 일정 설정 섹션
                Text(
                  '일정 설정',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 12),

                // 탭 구조로 일정 설정
                Expanded(
                  child: _buildCreateScheduleTabView(
                    appState: appState,
                    selectedSchedule: _selectedSchedule,
                    onScheduleChanged: (schedule) {
                      setState(() {
                        _selectedSchedule = schedule;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.cancel ?? '취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = _titleController.text.trim();
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n?.pleaseEnterTitle ?? '제목을 입력해주세요.')),
                );
                return;
              }
              
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              
              try {
                await appState.createLitten(title, schedule: _selectedSchedule);
                if (mounted) {
                  navigator.pop();
                  final scheduleText = _selectedSchedule != null
                      ? ' (${DateFormat('M월 d일').format(_selectedSchedule!.date)} ${_selectedSchedule!.startTime.format(context)})'
                      : '';
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('$title 리튼이 생성되었습니다.$scheduleText')),
                  );
                  // 새로 생성된 리튼(최신)으로 스크롤
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToTop();
                  });
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('${l10n?.error ?? '오류'}: $e')),
                  );
                }
              }
            },
            child: Text(l10n?.create ?? '생성'),
          ),
        ],
        ),
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
            children: [
              // 상단 50% - 캘린더
              Expanded(
                flex: 1,
                child: _buildCalendarSection(appState, l10n),
              ),
              // 하단 50% - 리튼 리스트
              Expanded(
                flex: 1,
                child: _buildLittenListSection(appState, l10n),
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
    final l10n = AppLocalizations.of(context);
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final currentLitten = appState.littens.firstWhere((litten) => litten.id == littenId);

    final TextEditingController titleController = TextEditingController(text: currentLitten.title);
    LittenSchedule? selectedSchedule = currentLitten.schedule;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('리튼 수정'),
          content: SizedBox(
            width: double.maxFinite,
            height: 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목 섹션
                Container(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '리튼 이름',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                // 제목 입력 필드
                SizedBox(
                  height: 80, // 🔑 중요: 높이 고정 (이게 핵심!)
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(4), // 🔑 중요: 패딩 유지
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50, // 깔끔한 회색 배경
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade300, // 회색 테두리
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: titleController,
                      enabled: true,
                      decoration: InputDecoration(
                        hintText: '예: 회의록, 강의 메모, 일기 등',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        labelStyle: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        hintStyle: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      autofocus: true,
                      onChanged: (value) {
                        debugPrint('🔤 수정 텍스트 입력: $value');
                      },
                      onTap: () {
                        debugPrint('🔍 수정 텍스트 필드 탭됨');
                      },
                    ),
                  ),
                ),

                // 일정 설정 섹션
                Text(
                  '일정 설정',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 12),

                // 탭 구조로 일정 설정
                Expanded(
                  child: _buildScheduleTabView(
                    currentLitten: currentLitten,
                    selectedSchedule: selectedSchedule,
                    onScheduleChanged: (schedule) {
                      setState(() {
                        selectedSchedule = schedule;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n?.cancel ?? '취소'),
            ),
            ElevatedButton(
              onPressed: () => _performEditLitten(
                littenId,
                titleController.text.trim(),
                selectedSchedule,
                context,
              ),
              child: Text('저장'),
            ),
          ],
        ),
      ),
    ).then((_) {
      titleController.dispose();
    });
  }

  Widget _buildScheduleTabView({
    required Litten currentLitten,
    required LittenSchedule? selectedSchedule,
    required Function(LittenSchedule?) onScheduleChanged,
  }) {
    return DefaultTabController(
      length: 2,
      child: StatefulBuilder(
        builder: (context, setState) {
          final bool hasSchedule = selectedSchedule != null;

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
      child: StatefulBuilder(
        builder: (context, setState) {
          final bool hasSchedule = selectedSchedule != null;

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

  void _performEditLitten(
    String littenId,
    String newTitle,
    LittenSchedule? newSchedule,
    BuildContext dialogContext,
  ) async {
    final l10n = AppLocalizations.of(context);

    if (newTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n?.pleaseEnterTitle ?? '제목을 입력해주세요.')),
      );
      return;
    }

    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final navigator = Navigator.of(dialogContext);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // 기존 리튼 찾기
      final currentLitten = appState.littens.firstWhere((litten) => litten.id == littenId);

      // 수정된 리튼 생성
      final updatedLitten = Litten(
        id: currentLitten.id,
        title: newTitle,
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

      navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('리튼이 수정되었습니다.')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('${l10n?.error ?? '오류'}: $e')),
      );
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
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
      ),
      child: Column(
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
        ],
      ),
    );
  }

  // 리튼 리스트 섹션 빌드
  Widget _buildLittenListSection(AppStateProvider appState, AppLocalizations? l10n) {
    final selectedDateLittens = appState.littensForSelectedDate;

    // 알림이 있는 리튼과 없는 리튼을 구분하여 정렬
    final littensWithNotifications = <Litten>[];
    final littensWithoutNotifications = <Litten>[];

    for (final litten in selectedDateLittens) {
      final hasNotifications = appState.notificationService.firedNotifications
          .any((notification) => notification.littenId == litten.id);

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

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.paddingM.left,
        right: AppSpacing.paddingM.left,
        bottom: AppSpacing.paddingM.left,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 리튼 리스트
          Expanded(
            child: selectedDateLittens.isEmpty
                ? EmptyState(
                    icon: Icons.calendar_today,
                    title: '선택한 날짜에 생성된 리튼이 없습니다',
                    description: '이 날짜에 첫 번째 리튼을 생성해보세요',
                    actionText: l10n?.createLitten ?? '리튼 생성',
                    onAction: _showCreateLittenDialog,
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
                  ),
          ),
        ],
      ),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n?.delete ?? '삭제', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}