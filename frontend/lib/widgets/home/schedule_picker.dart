import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../models/litten.dart';
import 'notification_settings.dart';
import 'time_picker_scroll.dart';

class SchedulePicker extends StatefulWidget {
  final LittenSchedule? initialSchedule;
  final Function(LittenSchedule?) onScheduleChanged;
  final DateTime? defaultDate;
  final bool showNotificationSettings;
  final bool isCreatingNew; // 새로 생성하는 리튼인지 구분

  const SchedulePicker({
    super.key,
    this.initialSchedule,
    required this.onScheduleChanged,
    this.defaultDate,
    this.showNotificationSettings = true,
    this.isCreatingNew = false,
  });

  @override
  State<SchedulePicker> createState() => _SchedulePickerState();
}

class _SchedulePickerState extends State<SchedulePicker> {
  bool _hasSchedule = true;
  late DateTime _selectedDate;
  DateTime? _selectedEndDate; // 종료 날짜
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  final TextEditingController _notesController = TextEditingController();
  List<NotificationRule> _notificationRules = [];
  TimeOfDay? _notificationStartTime; // 알림 시작 시간 (from)
  TimeOfDay? _notificationEndTime;   // 알림 종료 시간 (to), null이면 제한 없음

  @override
  void initState() {
    super.initState();

    // 기본 날짜 설정: initialSchedule이 있으면 해당 날짜, 없으면 defaultDate 또는 오늘
    if (widget.initialSchedule != null) {
      _hasSchedule = true;
      _selectedDate = widget.initialSchedule!.date;
      _selectedEndDate = widget.initialSchedule!.endDate;
      _startTime = widget.initialSchedule!.startTime;
      _endTime = widget.initialSchedule!.endTime;
      _notesController.text = widget.initialSchedule!.notes ?? '';
      _notificationRules = List.from(widget.initialSchedule!.notificationRules);
      _notificationStartTime = widget.initialSchedule!.notificationStartTime;
      _notificationEndTime = widget.initialSchedule!.notificationEndTime;
    } else {
      _selectedDate = widget.defaultDate ?? DateTime.now();
    }

    // 새로 생성하는 경우가 아니라면 초기 일정 생성
    if (!widget.isCreatingNew) {
      _updateSchedule();
    }
  }

  @override
  void dispose() {
    try {
      _notesController.dispose();
      debugPrint('✅ SchedulePicker disposed');
    } catch (e) {
      debugPrint('❌ SchedulePicker dispose 에러: $e');
    }
    super.dispose();
  }

  void _updateSchedule() {
    if (!mounted) {
      debugPrint('⚠️ SchedulePicker: Widget not mounted, skipping schedule update');
      return;
    }

    try {
      // 시간 유효성 검사
      if (_startTime.hour == _endTime.hour && _startTime.minute >= _endTime.minute) {
        debugPrint('⚠️ 일정 시간 오류: 시작 시간이 종료 시간보다 늦습니다.');
        return;
      }

      debugPrint('📝 SchedulePicker._updateSchedule() - 스케줄 생성');
      debugPrint('   📅 date: $_selectedDate');
      debugPrint('   ⏰ startTime: ${_startTime.hour}:${_startTime.minute}');
      debugPrint('   ⏰ endTime: ${_endTime.hour}:${_endTime.minute}');

      final schedule = LittenSchedule(
        date: _selectedDate,
        endDate: _selectedEndDate,
        startTime: _startTime,
        endTime: _endTime,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        notificationRules: _notificationRules,
        notificationStartTime: _notificationStartTime,
        notificationEndTime: _notificationEndTime,
      );

      widget.onScheduleChanged(schedule);

      // mounted 체크 후 context 사용
      if (mounted) {
        debugPrint('✅ 일정 업데이트: ${schedule.date} ${schedule.startTime.format(context)} - ${schedule.endTime.format(context)}');
      }
    } catch (e) {
      debugPrint('❌ 일정 업데이트 실패: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: l10n?.selectDate ?? '시작 날짜 선택',
      cancelText: l10n?.cancel ?? '취소',
      confirmText: l10n?.confirm ?? '확인',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // 시작 날짜가 종료 날짜보다 늦으면 종료 날짜 초기화
        if (_selectedEndDate != null && picked.isAfter(_selectedEndDate!)) {
          _selectedEndDate = null;
        }
      });
      _updateSchedule();
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate ?? _selectedDate.add(const Duration(days: 1)),
      firstDate: _selectedDate, // 시작 날짜 이후만 선택 가능
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: l10n?.selectDate ?? '종료 날짜 선택',
      cancelText: l10n?.cancel ?? '취소',
      confirmText: l10n?.confirm ?? '확인',
    );
    if (picked != null) {
      setState(() {
        _selectedEndDate = picked;
      });
      _updateSchedule();
    }
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
          // 시작 날짜 선택
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(l10n?.date ?? '시작 날짜'),
              subtitle: Text(DateFormat('yyyy년 M월 d일 (E)', 'ko').format(_selectedDate)),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _selectDate(context),
            ),
          ),
          const SizedBox(height: 4),
          // 종료 날짜 선택
          Card(
            child: InkWell(
              onTap: () => _selectEndDate(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.event, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '종료 날짜',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedEndDate != null
                                ? DateFormat('yyyy년 M월 d일 (E)', 'ko').format(_selectedEndDate!)
                                : '선택 안 함',
                            style: TextStyle(
                              fontSize: 12,
                              color: _selectedEndDate != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedEndDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _selectedEndDate = null;
                          });
                          _updateSchedule();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    const Icon(Icons.arrow_forward_ios, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // 시간 선택 - 스크롤 박스
          Row(
            children: [
              Expanded(
                child: TimePickerScroll(
                  key: const ValueKey('start_time'),
                  initialTime: _startTime,
                  label: l10n?.startTime ?? '시작 시간',
                  onTimeChanged: (time) {
                    setState(() {
                      _startTime = time;
                      // 시작 시간이 종료 시간보다 늦으면 종료 시간을 1시간 후로 자동 조정
                      if (_startTime.hour > _endTime.hour ||
                          (_startTime.hour == _endTime.hour && _startTime.minute >= _endTime.minute)) {
                        _endTime = TimeOfDay(hour: (_startTime.hour + 1) % 24, minute: _startTime.minute);
                        debugPrint('🕐 시작 시간 변경으로 종료 시간 자동 조정: ${_startTime.format(context)} → ${_endTime.format(context)}');
                      }
                    });
                    _updateSchedule();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TimePickerScroll(
                  key: const ValueKey('end_time'),
                  initialTime: _endTime,
                  label: l10n?.endTime ?? '종료 시간',
                  onTimeChanged: (time) {
                    setState(() {
                      // 종료 시간이 시작 시간보다 빠르거나 같으면 최소 간격을 위해 조정
                      if (time.hour < _startTime.hour ||
                          (time.hour == _startTime.hour && time.minute <= _startTime.minute)) {
                        // 시작 시간에서 최소 15분 후로 설정
                        final minGapMinutes = 15;
                        var newEndMinute = _startTime.minute + minGapMinutes;
                        if (newEndMinute >= 60) {
                          _endTime = TimeOfDay(hour: (_startTime.hour + 1) % 24, minute: newEndMinute - 60);
                        } else {
                          _endTime = TimeOfDay(hour: _startTime.hour, minute: newEndMinute);
                        }
                        debugPrint('🕐 종료 시간 최소 간격 조정: ${_startTime.format(context)} → ${_endTime.format(context)}');
                      } else {
                        // 사용자가 선택한 종료 시간을 그대로 사용
                        _endTime = time;
                        debugPrint('🕐 사용자 종료 시간 선택: ${_endTime.format(context)}');
                      }
                    });
                    _updateSchedule();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 메모
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: l10n?.notes ?? '메모',
              hintText: l10n?.scheduleNotesHint ?? '일정에 대한 메모를 입력하세요 (선택사항)',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.note),
            ),
            maxLines: 2,
            onChanged: (_) => _updateSchedule(),
          ),
          const SizedBox(height: 8),
          // 일정 기간 표시
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _getDurationText(),
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (widget.showNotificationSettings) ...[
            const SizedBox(height: 16),
            // 알림 시간 범위 설정
            Text(
              '알림 발생 시간 범위',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TimePickerScroll(
                    key: const ValueKey('notification_start_time'),
                    initialTime: _notificationStartTime ?? const TimeOfDay(hour: 0, minute: 0),
                    label: '시작 (From)',
                    onTimeChanged: (time) {
                      setState(() {
                        _notificationStartTime = time;
                      });
                      _updateSchedule();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TimePickerScroll(
                    key: const ValueKey('notification_end_time'),
                    initialTime: _notificationEndTime ?? const TimeOfDay(hour: 23, minute: 55),
                    label: '종료 (To)',
                    onTimeChanged: (time) {
                      setState(() {
                        _notificationEndTime = time;
                      });
                      _updateSchedule();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _notificationStartTime = null;
                      });
                      _updateSchedule();
                    },
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('시작 제한 없음', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _notificationEndTime = null;
                      });
                      _updateSchedule();
                    },
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('종료 제한 없음', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _notificationStartTime == null && _notificationEndTime == null
                          ? '알림이 하루 종일 발생합니다'
                          : _notificationStartTime != null && _notificationEndTime == null
                              ? '${_notificationStartTime!.format(context)}부터 알림 발생'
                              : _notificationStartTime == null && _notificationEndTime != null
                                  ? '${_notificationEndTime!.format(context)}까지 알림 발생'
                                  : '${_notificationStartTime!.format(context)} ~ ${_notificationEndTime!.format(context)} 사이 알림 발생',
                      style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 알림 설정
            NotificationSettings(
              initialRules: _notificationRules,
              scheduleDate: _selectedDate, // 일정 시작일자 전달
              onRulesChanged: (rules) {
                setState(() {
                  _notificationRules = rules;
                });
                _updateSchedule();
              },
            ),
          ],
      ],
    );
  }

  String _getDurationText() {
    final start = DateTime(2000, 1, 1, _startTime.hour, _startTime.minute);
    final end = DateTime(2000, 1, 1, _endTime.hour, _endTime.minute);
    final duration = end.difference(start);

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours == 0) {
      return '총 $minutes분';
    } else if (minutes == 0) {
      return '총 $hours시간';
    } else {
      return '총 $hours시간 $minutes분';
    }
  }
}