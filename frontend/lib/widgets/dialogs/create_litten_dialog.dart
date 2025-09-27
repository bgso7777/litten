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
  LittenSchedule? _selectedSchedule;
  bool _userInteractedWithSchedule = false;
  int _currentTabIndex = 0;

  @override
  void dispose() {
    debugPrint('🎯 CreateLittenDialog dispose 시작');
    _titleController.dispose();
    debugPrint('🎯 CreateLittenDialog dispose 완료');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(
        l10n?.createLitten ?? '리튼 생성',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목 입력 필드
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
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

            // 같은 이름의 리튼이 이미 존재하는지 확인
            final existingLittens = widget.appState.littens.where(
              (litten) => litten.title.trim().toLowerCase() == title.toLowerCase(),
            ).toList();

            if (existingLittens.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('이미 같은 이름의 리튼이 존재합니다: "$title"')),
              );
              return;
            }

            final navigator = Navigator.of(context);
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            final currentContext = context;

            try {
              final newLitten = await widget.appState.createLitten(title, schedule: _selectedSchedule);
              if (mounted) {
                // 리튼 생성 후 항상 다이얼로그 닫기
                navigator.pop();
                final scheduleText = _selectedSchedule != null
                    ? ' (${DateFormat('M월 d일').format(_selectedSchedule!.date)} ${_selectedSchedule!.startTime.format(currentContext)})'
                    : '';
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('$title 리튼이 생성되었습니다.$scheduleText')),
                );
                // 새로 생성된 리튼을 선택
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.appState.selectLitten(newLitten);
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