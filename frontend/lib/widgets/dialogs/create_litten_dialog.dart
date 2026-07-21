import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../services/app_state_provider.dart';
import '../../models/litten.dart';
import '../../config/themes.dart';
import '../home/schedule_color_picker.dart';
import '../home/schedule_form_tab.dart';
import '../home/schedule_picker.dart';
import '../home/notification_settings.dart';

class CreateLittenDialog extends StatefulWidget {
  final AppStateProvider appState;
  final Function(int) onScheduleIndexChanged;

  const CreateLittenDialog({
    super.key,
    required this.appState,
    required this.onScheduleIndexChanged,
  });

  @override
  State<CreateLittenDialog> createState() => _CreateLittenDialogState();
}

class _CreateLittenDialogState extends State<CreateLittenDialog> {
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  LittenSchedule? _selectedSchedule;
  bool _userInteractedWithSchedule = false;
  int _currentTabIndex = 0;
  int _selectedColorIndex = AppColors.defaultScheduleColorIndex; // 일정 색(기본 파랑)

  @override
  void initState() {
    super.initState();
    // 일정 생성 시 제목 입력에 커서를 유지한다 (autofocus 유지, 자동 포커스 해제 제거)
  }

  @override
  void dispose() {
    debugPrint('🎯 CreateLittenDialog dispose 시작');
    _titleController.dispose();
    _titleFocusNode.dispose();
    debugPrint('🎯 CreateLittenDialog dispose 완료');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목 입력 필드 + 우측 5색 선택기(제목 폭이 약간 줄어듦)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n?.scheduleTitle ?? '일정 제목',
                      // 라벨은 항상 검은색 — 포커스 시 테마색으로 바뀌지 않게
                      // labelStyle(기본)과 floatingLabelStyle(포커스/입력 중)을 모두 지정한다.
                      labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      floatingLabelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.title),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ScheduleColorPicker(
                  selectedIndex: _selectedColorIndex,
                  onChanged: (i) => setState(() => _selectedColorIndex = i),
                ),
              ],
            ),
            const SizedBox(height: 16),


            // 탭 구조로 일정 설정
            Expanded(
              child: _buildCreateScheduleTabView(l10n),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            debugPrint('🎯 취소 버튼 클릭');
            Navigator.of(context).pop();
          },
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

            // 같은 이름이면서 같은 날짜의 리튼이 이미 존재하는지 확인 (일정이 있는 경우만)
            if (_selectedSchedule != null) {
              final selectedDate = _selectedSchedule!.date;
              final existingLittens = widget.appState.littens.where(
                (litten) => litten.title.trim().toLowerCase() == title.toLowerCase() &&
                           litten.schedule != null &&
                           litten.schedule!.date.year == selectedDate.year &&
                           litten.schedule!.date.month == selectedDate.month &&
                           litten.schedule!.date.day == selectedDate.day,
              ).toList();

              if (existingLittens.isNotEmpty) {
                final dateStr = DateFormat('M월 d일').format(_selectedSchedule!.date);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n?.littenAlreadyExists(dateStr, title) ?? '$dateStr에 이미 같은 이름의 리튼이 존재합니다: "$title"')),
                );
                return;
              }

              // 무료 플랜: 일정(날짜·알림) 개수 제한 — 초과 시 안내 후 중단
              final scheduleBlock = widget.appState.scheduleBlockReason();
              if (scheduleBlock != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(scheduleBlock)),
                );
                return;
              }
            }

            final navigator = Navigator.of(context);
            final scaffoldMessenger = ScaffoldMessenger.of(context);

            try {
              debugPrint('🔥 리튼 생성 시작: $title');
              final newLitten = await widget.appState.createLitten(title,
                  schedule: _selectedSchedule, colorIndex: _selectedColorIndex);
              debugPrint('✅ 리튼 생성 완료: ${newLitten.id}');

              if (mounted) {
                // 다이얼로그 닫기 (자동 선택 제거)
                navigator.pop();
              }
            } catch (e) {
              debugPrint('❌ 리튼 생성 에러: $e');
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
    );
  }

  Widget _buildCreateScheduleTabView(AppLocalizations? l10n) {
    return DefaultTabController(
      length: 2,
      initialIndex: _currentTabIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 탭바
          TabBar(
            indicator: const BoxDecoration(),
            labelPadding: EdgeInsets.zero,
            onTap: (index) {
              setState(() {
                _currentTabIndex = index;
              });
              widget.onScheduleIndexChanged(index);
            },
            tabs: [
              ScheduleFormTab(
                isActive: _currentTabIndex == 0,
                checked: _userInteractedWithSchedule && _selectedSchedule != null,
                icon: Icons.schedule,
                label: l10n?.addScheduleTab ?? '일정추가',
              ),
              ScheduleFormTab(
                isActive: _currentTabIndex == 1,
                checked: _userInteractedWithSchedule &&
                    _selectedSchedule?.notificationRules.isNotEmpty == true,
                icon: Icons.notifications,
                label: l10n?.notificationSettingTab ?? '알림설정',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 탭 내용
          Expanded(
            child: TabBarView(
              physics: _userInteractedWithSchedule && _selectedSchedule != null
                  ? null
                  : const NeverScrollableScrollPhysics(),
              children: [
                // 일정추가 탭
                SingleChildScrollView(
                  child: SchedulePicker(
                    defaultDate: widget.appState.selectedDate,
                    initialSchedule: _selectedSchedule,
                    onScheduleChanged: (schedule) {
                      setState(() {
                        _selectedSchedule = schedule;
                        _userInteractedWithSchedule = schedule != null;
                      });
                    },
                    isCreatingNew: true,
                  ),
                ),
                // 알림설정 탭
                (_userInteractedWithSchedule && _selectedSchedule != null)
                    ? SingleChildScrollView(
                        child: NotificationSettings(
                          initialRules: _selectedSchedule!.notificationRules,
                          scheduleDate: _selectedSchedule!.date, // 일정 시작일자 전달
                          onRulesChanged: (rules) {
                            setState(() {
                              _selectedSchedule = LittenSchedule(
                                date: _selectedSchedule!.date,
                                // endDate·알림 시간대도 보존한다(누락 시 다중일 일정이
                                // 알림 규칙만 바꿔도 종료일을 잃는 버그가 있었음).
                                endDate: _selectedSchedule!.endDate,
                                startTime: _selectedSchedule!.startTime,
                                endTime: _selectedSchedule!.endTime,
                                notes: _selectedSchedule!.notes,
                                notificationRules: rules,
                                notificationStartTime:
                                    _selectedSchedule!.notificationStartTime,
                                notificationEndTime:
                                    _selectedSchedule!.notificationEndTime,
                              );
                            });
                          },
                        ),
                      )
                    : _buildDisabledNotificationTab(),
              ],
            ),
          ),
        ],
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
            AppLocalizations.of(context)?.setScheduleFirst ?? '일정을 먼저 설정해주세요',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)?.setScheduleToEnableNotification ?? '일정추가 탭에서 일정을 설정하면\n알림 설정을 할 수 있습니다',
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
}