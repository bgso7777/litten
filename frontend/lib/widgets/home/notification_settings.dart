import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/litten.dart';

class NotificationSettings extends StatefulWidget {
  final List<NotificationRule> initialRules;
  final Function(List<NotificationRule>) onRulesChanged;

  const NotificationSettings({
    super.key,
    required this.initialRules,
    required this.onRulesChanged,
  });

  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings> {
  late List<NotificationRule> _rules;
  bool _showNotifications = false;

  @override
  void initState() {
    super.initState();
    _rules = List.from(widget.initialRules);
    _showNotifications = _rules.any((rule) => rule.isEnabled);

    // 초기 규칙이 없다면 기본 규칙 생성
    if (_rules.isEmpty) {
      _initializeDefaultRules();
    }
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

  void _updateRule(NotificationFrequency frequency, NotificationTiming timing, bool enabled) {
    setState(() {
      final index = _rules.indexWhere(
        (rule) => rule.frequency == frequency && rule.timing == timing,
      );

      if (index != -1) {
        _rules[index] = _rules[index].copyWith(isEnabled: enabled);
      } else {
        _rules.add(NotificationRule(
          frequency: frequency,
          timing: timing,
          isEnabled: enabled,
        ));
      }
    });

    _notifyChanges();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Checkbox(
              value: _showNotifications,
              onChanged: (value) {
                setState(() {
                  _showNotifications = value ?? false;
                  if (!_showNotifications) {
                    // 알림 비활성화 시 모든 규칙 비활성화
                    _rules = _rules.map((rule) => rule.copyWith(isEnabled: false)).toList();
                    _notifyChanges();
                  }
                });
              },
            ),
            Text(
              l10n?.enableNotifications ?? '알림 설정',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        if (_showNotifications) ...[
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
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
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
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            frequency.label,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        ...NotificationTiming.values.map((timing) =>
                          Expanded(
                            child: Checkbox(
                              value: _isRuleEnabled(frequency, timing),
                              onChanged: (value) {
                                _updateRule(frequency, timing, value ?? false);
                              },
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
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
      ],
    );
  }
}