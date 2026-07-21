import 'package:flutter/material.dart';

/// 일정 입력 창의 탭 한 칸 — "일정추가 / 알림설정" 2탭에 쓰인다.
///
/// 캘린더 생성 창(CreateLittenDialog)과 셀 일정 창(_RoomScheduleDialog)이 각자
/// 갖고 있던 동일한 `_buildTab`을 하나로 합친 것.
/// 체크박스로 해당 탭의 입력이 채워졌는지 알려주고, 활성 탭은 배경 박스로 표시한다.
///
/// "checked를 어떻게 계산하는가"는 창마다 다르므로(예: 상호작용 게이트 유무)
/// 계산은 호출부에 맡기고, 이 위젯은 결과 bool만 받는다.
///
/// TabBar의 tabs 는 Widget 리스트를 받으므로 이 위젯을 그대로 넣으면 된다.
class ScheduleFormTab extends StatelessWidget {
  const ScheduleFormTab({
    super.key,
    required this.isActive,
    required this.checked,
    required this.icon,
    required this.label,
  });

  /// 이 탭이 현재 선택돼 있는지(배경 박스 표시용).
  final bool isActive;

  /// 이 탭의 입력이 채워졌는지(체크박스 표시용).
  final bool checked;

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Tab(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? primaryColor.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: isActive ? primaryColor.withValues(alpha: 0.3) : Colors.transparent,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(checked ? Icons.check_box : Icons.check_box_outline_blank,
                size: 16,
                color: checked ? primaryColor : Colors.grey.shade500),
            const SizedBox(width: 4),
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
