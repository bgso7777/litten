import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../services/app_state_provider.dart';
import '../../models/litten.dart';
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

  @override
  void initState() {
    super.initState();
    // 1초 후 포커스 해제 (키보드 숨김)
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _titleFocusNode.unfocus();
        debugPrint('⌨️ 키보드 숨김 완료');
      }
    });
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
      title: const Center(
        child: Text(
          '일정 생성',
          style: TextStyle(
            fontSize: 16, // 텍스트 필드와 동일한 크기
          ),
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목 입력 필드
            TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '일정 제목',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),


            // 탭 구조로 일정 설정
            Expanded(
              child: _buildCreateScheduleTabView(),
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
                  SnackBar(content: Text('$dateStr에 이미 같은 이름의 리튼이 존재합니다: "$title"')),
                );
                return;
              }
            }

            final navigator = Navigator.of(context);
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            final currentContext = context;

            try {
              debugPrint('🔥 리튼 생성 시작: $title');
              final newLitten = await widget.appState.createLitten(title, schedule: _selectedSchedule);
              debugPrint('✅ 리튼 생성 완료: ${newLitten.id}');

              if (mounted) {
                // 생성된 리튼을 즉시 선택
                await widget.appState.selectLitten(newLitten);
                debugPrint('✅ 리튼 선택 완료: ${newLitten.id}');

                // 다이얼로그 닫기
                navigator.pop();

                final scheduleText = _selectedSchedule != null
                    ? ' (${DateFormat('M월 d일').format(_selectedSchedule!.date)} ${_selectedSchedule!.startTime.format(currentContext)})'
                    : '';
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('$title 리튼이 생성되었습니다.$scheduleText')),
                );
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

  Widget _buildCreateScheduleTabView() {
    return DefaultTabController(
      length: 2,
      initialIndex: _currentTabIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 탭바
          TabBar(
            labelColor: _userInteractedWithSchedule && _selectedSchedule != null
                ? Theme.of(context).primaryColor
                : Colors.grey,
            unselectedLabelColor: Colors.grey,
            indicator: _userInteractedWithSchedule && _selectedSchedule != null
                ? UnderlineTabIndicator(
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                  )
                : null,
            onTap: (index) {
              setState(() {
                _currentTabIndex = index;
              });
              widget.onScheduleIndexChanged(index);
            },
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _userInteractedWithSchedule && _selectedSchedule != null
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 16,
                      color: _userInteractedWithSchedule && _selectedSchedule != null
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade500,
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
                      (_userInteractedWithSchedule && _selectedSchedule?.notificationRules.isNotEmpty == true)
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                      size: 16,
                      color: (_userInteractedWithSchedule && _selectedSchedule?.notificationRules.isNotEmpty == true)
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.notifications,
                      size: 16,
                      color: _userInteractedWithSchedule && _selectedSchedule != null
                          ? null
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '알림설정',
                      style: TextStyle(
                        color: _userInteractedWithSchedule && _selectedSchedule != null
                            ? null
                            : Colors.grey.shade400,
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
                    showNotificationSettings: false,
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
                                startTime: _selectedSchedule!.startTime,
                                endTime: _selectedSchedule!.endTime,
                                notes: _selectedSchedule!.notes,
                                notificationRules: rules,
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
}