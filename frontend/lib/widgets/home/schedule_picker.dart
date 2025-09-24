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

  const SchedulePicker({
    super.key,
    this.initialSchedule,
    required this.onScheduleChanged,
    this.defaultDate,
    this.showNotificationSettings = true,
  });

  @override
  State<SchedulePicker> createState() => _SchedulePickerState();
}

class _SchedulePickerState extends State<SchedulePicker> {
  bool _hasSchedule = true;
  late DateTime _selectedDate;
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
      _startTime = widget.initialSchedule!.startTime;
      _endTime = widget.initialSchedule!.endTime;
      _notesController.text = widget.initialSchedule!.notes ?? '';
      _notificationRules = List.from(widget.initialSchedule!.notificationRules);
    } else {
      _selectedDate = widget.defaultDate ?? DateTime.now();
    }

    _updateSchedule();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _updateSchedule() {
    final schedule = LittenSchedule(
      date: _selectedDate,
      startTime: _startTime,
      endTime: _endTime,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      notificationRules: _notificationRules,
    );
    widget.onScheduleChanged(schedule);
  }

  Future<void> _selectDate(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: l10n?.selectDate ?? '날짜 선택',
      cancelText: l10n?.cancel ?? '취소',
      confirmText: l10n?.confirm ?? '확인',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
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
        const SizedBox(height: 16),
          // 날짜 선택
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(l10n?.date ?? '날짜'),
              subtitle: Text(DateFormat('yyyy년 M월 d일 (E)', 'ko').format(_selectedDate)),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _selectDate(context),
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
                      // 시작 시간이 종료 시간보다 늦으면 종료 시간을 조정
                      if (_startTime.hour > _endTime.hour ||
                          (_startTime.hour == _endTime.hour && _startTime.minute >= _endTime.minute)) {
                        final newEndMinute = _startTime.minute + 30;
                        if (newEndMinute >= 60) {
                          _endTime = TimeOfDay(hour: (_startTime.hour + 1) % 24, minute: newEndMinute - 60);
                        } else {
                          _endTime = TimeOfDay(hour: _startTime.hour, minute: newEndMinute);
                        }
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
                      // 종료 시간이 시작 시간보다 빠르면 시작 시간을 조정
                      if (time.hour < _startTime.hour ||
                          (time.hour == _startTime.hour && time.minute <= _startTime.minute)) {
                        final newStartMinute = time.minute - 30;
                        if (newStartMinute < 0) {
                          _startTime = TimeOfDay(hour: (time.hour - 1 + 24) % 24, minute: newStartMinute + 60);
                        } else {
                          _startTime = TimeOfDay(hour: time.hour, minute: newStartMinute);
                        }
                      }
                      _endTime = time;
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
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
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
            // 알림 설정
            NotificationSettings(
              initialRules: _notificationRules,
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
      return '총 ${minutes}분';
    } else if (minutes == 0) {
      return '총 ${hours}시간';
    } else {
      return '총 ${hours}시간 ${minutes}분';
    }
  }
}