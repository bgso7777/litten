import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/litten.dart';

class NotificationSettings extends StatefulWidget {
  final List<NotificationRule> initialRules;
  final Function(List<NotificationRule>) onRulesChanged;
  final DateTime? scheduleDate; // 일정 시작일자

  const NotificationSettings({
    super.key,
    required this.initialRules,
    required this.onRulesChanged,
    this.scheduleDate, // 선택적 파라미터
  });

  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings> {
  late List<NotificationRule> _rules;

  @override
  void initState() {
    super.initState();
    _rules = List.from(widget.initialRules);

    // 초기 규칙이 없다면 기본 규칙 생성
    if (_rules.isEmpty) {
      _initializeDefaultRules();
    }

    // 허용되지 않는 규칙들 정리
    _cleanupInvalidRules();
  }

  void _initializeDefaultRules() {
    _rules = [];
    for (final frequency in NotificationFrequency.values) {
      for (final timing in NotificationTiming.values) {
        _rules.add(NotificationRule(
          frequency: frequency,
          timing: timing,
          isEnabled: false,
        ));
      }
    }
  }

  void _cleanupInvalidRules() {
    final cleanedRules = <NotificationRule>[];

    for (final rule in _rules) {
      if (!_isTimingAllowed(rule.frequency, rule.timing) && rule.isEnabled) {
        debugPrint('🧹 허용되지 않는 규칙 비활성화: ${rule.frequency.label} - ${rule.timing.label}');
        cleanedRules.add(rule.copyWith(isEnabled: false));
      } else {
        cleanedRules.add(rule);
      }
    }

    _rules = cleanedRules;
  }

  void _updateRule(NotificationFrequency frequency, NotificationTiming timing, bool enabled, {List<int>? weekdays}) {
    if (!_isTimingAllowed(frequency, timing) && enabled) {
      debugPrint('🚫 허용되지 않는 알림 조합: ${frequency.label} - ${timing.label}');
      return;
    }

    setState(() {
      final index = _rules.indexWhere(
        (rule) => rule.frequency == frequency && rule.timing == timing,
      );

      if (index != -1) {
        _rules[index] = _rules[index].copyWith(
          isEnabled: enabled,
          weekdays: frequency == NotificationFrequency.weekly ? weekdays : null,
        );
      } else {
        _rules.add(NotificationRule(
          frequency: frequency,
          timing: timing,
          isEnabled: enabled,
          weekdays: frequency == NotificationFrequency.weekly ? weekdays : null,
        ));
      }
    });

    _notifyChanges();
  }

  void _showWeekdayPicker(NotificationFrequency frequency, NotificationTiming timing) async {
    final currentRule = _rules.firstWhere(
      (rule) => rule.frequency == frequency && rule.timing == timing,
      orElse: () => NotificationRule(
        frequency: frequency,
        timing: timing,
        isEnabled: false,
      ),
    );

    // 일정 시작일자의 요일을 기본값으로 설정
    int defaultWeekday = 1; // 기본값: 월요일
    if (widget.scheduleDate != null) {
      // DateTime.weekday는 월요일=1, 일요일=7
      // 우리 시스템은 일요일=7, 월요일=1로 동일하게 사용
      defaultWeekday = widget.scheduleDate!.weekday == 7 ? 7 : widget.scheduleDate!.weekday;
      debugPrint('📅 일정 시작일자 요일: $defaultWeekday');
    }

    // 기존 설정이 있으면 사용하고, 없으면 일정 시작일자 요일을 기본값으로 사용
    final selectedWeekdays = Set<int>.from(
      (currentRule.weekdays != null && currentRule.weekdays!.isNotEmpty)
        ? currentRule.weekdays!
        : [defaultWeekday]
    );

    debugPrint('📅 매주 알림 요일 선택 다이얼로그 - 기본 선택 요일: $selectedWeekdays');

    final l10n = AppLocalizations.of(context);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n?.selectWeekdays ?? '요일 선택'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildWeekdayChip(l10n?.daySun ?? '일', 7, selectedWeekdays, setDialogState),
                  _buildWeekdayChip(l10n?.dayMon ?? '월', 1, selectedWeekdays, setDialogState),
                  _buildWeekdayChip(l10n?.dayTue ?? '화', 2, selectedWeekdays, setDialogState),
                  _buildWeekdayChip(l10n?.dayWed ?? '수', 3, selectedWeekdays, setDialogState),
                  _buildWeekdayChip(l10n?.dayThu ?? '목', 4, selectedWeekdays, setDialogState),
                  _buildWeekdayChip(l10n?.dayFri ?? '금', 5, selectedWeekdays, setDialogState),
                  _buildWeekdayChip(l10n?.daySat ?? '토', 6, selectedWeekdays, setDialogState),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n?.cancel ?? '취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _updateRule(
                      frequency,
                      timing,
                      selectedWeekdays.isNotEmpty,
                      weekdays: selectedWeekdays.toList()..sort(),
                    );
                    Navigator.pop(context);
                  },
                  child: Text(l10n?.confirm ?? '확인'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildWeekdayChip(String label, int weekday, Set<int> selectedWeekdays, StateSetter setDialogState) {
    final isSelected = selectedWeekdays.contains(weekday);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          setDialogState(() {
            if (isSelected) {
              selectedWeekdays.remove(weekday);
            } else {
              selectedWeekdays.add(weekday);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade800,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _notifyChanges() {
    final enabledRules = _rules.where((rule) => rule.isEnabled).toList();
    widget.onRulesChanged(enabledRules);
  }

  bool _isRuleEnabled(NotificationFrequency frequency, NotificationTiming timing) {
    return _rules.any(
      (rule) => rule.frequency == frequency &&
                rule.timing == timing &&
                rule.isEnabled,
    );
  }

  bool _isTimingAllowed(NotificationFrequency frequency, NotificationTiming timing) {
    // 모든 알림 빈도에 대해 모든 시간 옵션 허용
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // 헤더
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          l10n?.frequency ?? '빈도',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...NotificationTiming.values.map((timing) =>
                        Expanded(
                          child: Text(
                            timing.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 내용
                ...NotificationFrequency.values.map((frequency) =>
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                frequency.label,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            ...NotificationTiming.values.map((timing) {
                              final isAllowed = _isTimingAllowed(frequency, timing);
                              final isEnabled = _isRuleEnabled(frequency, timing);

                              return Expanded(
                                child: Checkbox(
                                  value: isEnabled,
                                  onChanged: isAllowed ? (value) {
                                    debugPrint('🔔 알림 규칙 변경: ${frequency.label} - ${timing.label} = ${value ?? false}');
                                    if (value == true && frequency == NotificationFrequency.weekly) {
                                      // 주별 알림이면 요일 선택 다이얼로그 표시
                                      _showWeekdayPicker(frequency, timing);
                                    } else {
                                      _updateRule(frequency, timing, value ?? false);
                                    }
                                  } : null,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              );
                            }),
                          ],
                        ),
                        // 주별 알림인 경우 선택된 요일 표시
                        if (frequency == NotificationFrequency.weekly) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: NotificationTiming.values.expand((timing) {
                              final rule = _rules.firstWhere(
                                (r) => r.frequency == frequency && r.timing == timing && r.isEnabled,
                                orElse: () => NotificationRule(frequency: frequency, timing: timing, isEnabled: false),
                              );

                              if (!rule.isEnabled || rule.weekdays == null || rule.weekdays!.isEmpty) {
                                return <Widget>[];
                              }

                              final weekdayLabels = {'일': 7, '월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6};
                              final selectedDays = weekdayLabels.entries
                                  .where((e) => rule.weekdays!.contains(e.value))
                                  .map((e) => e.key)
                                  .join(', ');

                              return [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${timing.label}: $selectedDays',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                              ];
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 알림 요약
          if (_rules.any((rule) => rule.isEnabled)) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n?.enabledNotifications ?? '활성화된 알림',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_rules.where((rule) => rule.isEnabled).length}개의 알림이 설정되었습니다',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
      ],
    );
  }
}