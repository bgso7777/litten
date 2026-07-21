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
  late TextEditingController _titleController;  // Controller 사용
  late LittenSchedule? _selectedSchedule;
  int _currentTabIndex = 0;
  int _selectedColorIndex = AppColors.defaultScheduleColorIndex; // 일정 색
  final FocusNode _titleFocusNode = FocusNode();  // FocusNode 추가

  @override
  void initState() {
    super.initState();
    // Controller에 즉시 텍스트 설정 - PostFrameCallback 사용하지 않음
    _titleController = TextEditingController(text: widget.litten.title);
    _selectedSchedule = widget.litten.schedule;
    _selectedColorIndex = widget.litten.colorIndex; // 기존 일정 색 로드
    debugPrint('📝 EditLittenDialog initState - 제목: "${widget.litten.title}"');
    debugPrint('📝 Controller text: "${_titleController.text}"');

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
    debugPrint('🎯 EditLittenDialog dispose 시작');
    _titleController.dispose();
    _titleFocusNode.dispose();
    debugPrint('🎯 EditLittenDialog dispose 완료');
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
                  // 캘린더 생성 창·셀 일정 창과 동일한 제목란(T 아이콘 + 검정 라벨).
                  child: TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n?.scheduleTitle ?? '일정 제목',
                      labelStyle: const TextStyle(color: Colors.black),
                      floatingLabelStyle: const TextStyle(color: Colors.black),
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
              child: _buildScheduleTabView(l10n),
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
          child: Text(l10n?.save ?? '저장'),
        ),
      ],
    );
  }

  Widget _buildScheduleTabView(AppLocalizations? l10n) {
    return DefaultTabController(
      length: 2,
      initialIndex: _currentTabIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 탭바 — 캘린더 생성 창·셀 일정 창과 동일한 배경박스 방식(ScheduleFormTab).
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
                checked: _selectedSchedule != null && widget.litten.schedule != null,
                icon: Icons.schedule,
                label: l10n?.addScheduleTab ?? '일정추가',
              ),
              ScheduleFormTab(
                isActive: _currentTabIndex == 1,
                checked: _selectedSchedule != null &&
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
                  ),
                ),
                // 알림설정 탭
                _selectedSchedule != null
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
            SnackBar(content: Text(l10n?.startTimeCannotBeAfterEndTime ?? '시작 시간이 종료 시간보다 늦을 수 없습니다.')),
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
        colorIndex: _selectedColorIndex,
      );

      // 리튼 업데이트
      await appState.updateLitten(updatedLitten);

      if (mounted) {
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