import 'package:flutter/material.dart';

class TimePickerScroll extends StatefulWidget {
  final TimeOfDay initialTime;
  final Function(TimeOfDay) onTimeChanged;
  final String label;

  const TimePickerScroll({
    super.key,
    required this.initialTime,
    required this.onTimeChanged,
    required this.label,
  });

  @override
  State<TimePickerScroll> createState() => _TimePickerScrollState();
}

class _TimePickerScrollState extends State<TimePickerScroll> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late int _selectedHour;
  late int _selectedMinute;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;

    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinute ~/ 5);
  }

  @override
  void didUpdateWidget(TimePickerScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTime != widget.initialTime) {
      _selectedHour = widget.initialTime.hour;
      _selectedMinute = widget.initialTime.minute;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_hourController.hasClients) {
          _hourController.animateToItem(
            _selectedHour,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        if (_minuteController.hasClients) {
          _minuteController.animateToItem(
            _selectedMinute ~/ 5,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _updateTime() {
    final newTime = TimeOfDay(hour: _selectedHour, minute: _selectedMinute);
    widget.onTimeChanged(newTime);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 라벨
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          // 시간 선택 영역
          Container(
            height: 140,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                // 시간 선택
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '시간',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: ListWheelScrollView.useDelegate(
                          controller: _hourController,
                          itemExtent: 40,
                          perspective: 0.01,
                          diameterRatio: 1.8,
                          physics: const BouncingScrollPhysics(),
                          onSelectedItemChanged: (index) {
                            setState(() {
                              _selectedHour = index;
                            });
                            _updateTime();
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            builder: (context, index) {
                              if (index < 0 || index > 23) return null;
                              final isSelected = index == _selectedHour;
                              return Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                                      : null,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  index.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: isSelected ? 16 : 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              );
                            },
                            childCount: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 구분선
                Container(
                  width: 1,
                  height: 100,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),

                // 분 선택 (5분 단위)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '분',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: ListWheelScrollView.useDelegate(
                          controller: _minuteController,
                          itemExtent: 40,
                          perspective: 0.01,
                          diameterRatio: 1.8,
                          physics: const BouncingScrollPhysics(),
                          onSelectedItemChanged: (index) {
                            setState(() {
                              _selectedMinute = index * 5;
                            });
                            _updateTime();
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            builder: (context, index) {
                              if (index < 0 || index > 11) return null;
                              final minute = index * 5;
                              final isSelected = minute == _selectedMinute;
                              return Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                                      : null,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  minute.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: isSelected ? 16 : 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              );
                            },
                            childCount: 12, // 0, 5, 10, ..., 55 (12개)
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 선택된 시간 표시
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Text(
              '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}