import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../services/app_state_provider.dart';
import '../../models/litten.dart';
import '../home/schedule_picker.dart';
import '../home/notification_settings.dart';

class EditLittenDialog extends StatefulWidget {
  final Litten litten;
  final Function(int) onScheduleIndexChanged;

  const EditLittenDialog({
    super.key,
    required this.litten,
    required this.onScheduleIndexChanged,
  });

  @override
  State<EditLittenDialog> createState() => _EditLittenDialogState();
}

class _EditLittenDialogState extends State<EditLittenDialog> {
  late final TextEditingController _titleController;
  late LittenSchedule? _selectedSchedule;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.litten.title);
    _selectedSchedule = widget.litten.schedule;
  }

  @override
  void dispose() {
    debugPrint('🎯 EditLittenDialog dispose 시작');
    _titleController.dispose();
    debugPrint('🎯 EditLittenDialog dispose 완료');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text('리튼 수정'),
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
                    debugPrint('🔤 수정 텍스트 입력: $value');
                  },
                  onTap: () {
                    debugPrint('🔍 수정 텍스트 필드 탭됨');
                  },
                ),
              ),


            // 탭 구조로 일정 설정
            Expanded(
              child: _buildScheduleTabView(),
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
            final result = await _performEditLitten();
            if (result) {
              Navigator.of(context).pop();
            }
          },
          child: Text('저장'),
        ),
      ],
    );
  }

  Widget _buildScheduleTabView() {
    return DefaultTabController(
      length: 2,
      initialIndex: _currentTabIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 탭바
          TabBar(
            labelColor: _selectedSchedule != null && widget.litten.schedule != null
                ? Theme.of(context).primaryColor
                : Colors.grey,
            unselectedLabelColor: Colors.grey,
            indicator: _selectedSchedule != null && widget.litten.schedule != null
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
                      _selectedSchedule != null && widget.litten.schedule != null
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 16,
                      color: _selectedSchedule != null && widget.litten.schedule != null
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
                      (_selectedSchedule != null && _selectedSchedule?.notificationRules.isNotEmpty == true)
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                      size: 16,
                      color: (_selectedSchedule != null && _selectedSchedule?.notificationRules.isNotEmpty == true)
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.notifications,
                      size: 16,
                      color: _selectedSchedule != null ? null : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '알림설정',
                      style: TextStyle(
                        color: _selectedSchedule != null ? null : Colors.grey.shade400,
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
              physics: _selectedSchedule != null
                  ? null
                  : const NeverScrollableScrollPhysics(),
              children: [
                // 일정추가 탭
                SingleChildScrollView(
                  child: SchedulePicker(
                    defaultDate: widget.litten.createdAt,
                    initialSchedule: _selectedSchedule,
                    onScheduleChanged: (schedule) {
                      setState(() {
                        _selectedSchedule = schedule;
                      });
                    },
                    showNotificationSettings: false,
                  ),
                ),
                // 알림설정 탭
                _selectedSchedule != null
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

  Future<bool> _performEditLitten() async {
    final l10n = AppLocalizations.of(context);
    final newTitle = _titleController.text.trim();

    // 입력 유효성 검사
    if (newTitle.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.pleaseEnterTitle ?? '제목을 입력해주세요.')),
        );
      }
      return false;
    }

    // 스케줄 유효성 검사
    if (_selectedSchedule != null) {
      final startTime = _selectedSchedule!.startTime;
      final endTime = _selectedSchedule!.endTime;
      if (startTime.hour == endTime.hour && startTime.minute >= endTime.minute) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('시작 시간이 종료 시간보다 늦을 수 없습니다.')),
          );
        }
        return false;
      }
    }

    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      debugPrint('🔄 리튼 수정 시작: ${widget.litten.id} - $newTitle');

      // 수정된 리튼 생성
      final updatedLitten = Litten(
        id: widget.litten.id,
        title: newTitle,
        description: widget.litten.description,
        createdAt: widget.litten.createdAt,
        updatedAt: DateTime.now(),
        audioFileIds: widget.litten.audioFileIds,
        textFileIds: widget.litten.textFileIds,
        handwritingFileIds: widget.litten.handwritingFileIds,
        schedule: _selectedSchedule,
      );

      // 리튼 업데이트
      await appState.updateLitten(updatedLitten);

      if (mounted) {
        final scheduleText = _selectedSchedule != null
            ? ' (${DateFormat('M월 d일').format(_selectedSchedule!.date)} ${_selectedSchedule!.startTime.format(context)})'
            : '';
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('${updatedLitten.title} 리튼이 수정되었습니다.$scheduleText')),
        );
        debugPrint('✅ 리튼 수정 완료: ${updatedLitten.id}');
      }
      return true;
    } catch (e) {
      debugPrint('❌ 리튼 수정 에러: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('${l10n?.error ?? '오류'}: $e')),
        );
      }
      return false;
    }
  }
}