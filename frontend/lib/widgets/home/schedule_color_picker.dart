import 'package:flutter/cupertino.dart';
import '../../config/themes.dart';

/// 일정 색 선택기 — 세로 롤링(번호 고르듯). 가운데(선택 밴드)에 온 색이 선택된다.
///
/// 캘린더 일정 창(CreateLittenDialog·EditLittenDialog)과 셀 일정 창
/// (_RoomScheduleDialog)이 각자 갖고 있던 동일한 위젯을 하나로 합친 것.
/// 견본은 캘린더의 일정 바와 같은 직사각형이며, 선택기 크기(40×78)는 고정.
class ScheduleColorPicker extends StatelessWidget {
  const ScheduleColorPicker({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  /// 현재 선택된 색 인덱스(AppColors.scheduleColors 기준).
  final int selectedIndex;

  /// 선택이 바뀌면 정규화된 인덱스를 돌려준다.
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 78, // itemExtent 26 × 3칸
      child: CupertinoPicker(
        itemExtent: 26,
        looping: true, // 완전 롤링(끝에서 처음으로 무한 순환)
        scrollController: FixedExtentScrollController(initialItem: selectedIndex),
        onSelectedItemChanged: (i) {
          final n = AppColors.scheduleColors.length;
          onChanged(((i % n) + n) % n);
        },
        children: [
          for (final c in AppColors.scheduleColors)
            Center(
              // 캘린더의 일정 바와 같은 직사각형 견본.
              child: Container(
                width: 34,
                height: 18,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
