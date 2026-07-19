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
  final bool isCreatingNew; // 새로 생성하는 리튼인지 구분

  const SchedulePicker({
    super.key,
    this.initialSchedule,
    required this.onScheduleChanged,
    this.defaultDate,
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
        // '알림 발생 시간 범위' 기능은 제거됨. 저장할 때마다 비워
        // 예전에 설정해 둔 값이 남아 알림을 막는 일이 없게 한다.
        notificationStartTime: null,
        notificationEndTime: null,
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
        const SizedBox(height: 4),
          // 시작 날짜 선택
          Card(
            child: InkWell(
              onTap: () => _selectDate(context),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      l10n?.startDate ?? '시작일자',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        DateFormat('yyyy년 M월 d일 (E)', 'ko').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios, size: 18),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          // 종료 날짜 선택
          Card(
            child: InkWell(
              onTap: () => _selectEndDate(context),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    const Icon(Icons.event, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      l10n?.endDate ?? '종료일자',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedEndDate != null
                            ? DateFormat('yyyy년 M월 d일 (E)', 'ko').format(_selectedEndDate!)
                            : (l10n?.notSelected ?? '선택 안 함'),
                        style: TextStyle(
                          fontSize: 12,
                          color: _selectedEndDate != null ? Colors.black : Colors.grey,
                          fontWeight: _selectedEndDate != null ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
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
          const SizedBox(height: 8),
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
          const SizedBox(height: 12),
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
                  _getDurationText(l10n),
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 메모
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: l10n?.notes ?? '메모',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.note),
            ),
            maxLines: 1,
            onChanged: (_) => _updateSchedule(),
          ),
      ],
    );
  }

  String _getDurationText(AppLocalizations? l10n) {
    final start = DateTime(2000, 1, 1, _startTime.hour, _startTime.minute);
    final end = DateTime(2000, 1, 1, _endTime.hour, _endTime.minute);
    final duration = end.difference(start);

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours == 0) {
      return l10n?.durationMinutes(minutes) ?? '총 ${minutes}분';
    } else if (minutes == 0) {
      return l10n?.durationHours(hours) ?? '총 ${hours}시간';
    } else {
      return l10n?.durationHoursMinutes(hours, minutes) ?? '총 ${hours}시간 ${minutes}분';
    }
  }
}